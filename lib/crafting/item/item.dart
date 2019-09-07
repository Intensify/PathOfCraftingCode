import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:poe_clicker/repository/crafting_bench_repo.dart';
import '../mod.dart';
import '../../repository/mod_repo.dart';
import '../../widgets/crafting_widget.dart';
import '../properties.dart';
import '../fossil.dart';
import '../currency_type.dart';
import 'rare_item.dart';
import 'magic_item.dart';
import 'normal_item.dart';
import 'spending_report.dart';
import '../essence.dart';
import '../stat_translation.dart';

abstract class Item {
  String name;
  List<Mod> prefixes;
  List<Mod> suffixes;
  List<Mod> implicits;
  List<String> tags;
  WeaponProperties weaponProperties;
  ArmourProperties armourProperties;
  String itemClass;
  int itemLevel;
  String domain;

  SpendingReport spendingReport;
  Item imprint;

  Random rng = new Random();
  Color statTextColor = Color(0xFF677F7F);
  Color modColor = Color(0xFF959AF6);
  Color coldDamage = Color(0xFF3F648E);
  Color fireDamage = Color(0xFF8A1910);
  Color lightningDamage = Color(0xFFFAD749);
  Color chaosDamage = Color(0xFFC0388D);
  double modFontSize = 16;
  double advancedModFontSize =  12;
  double titleFontSize = 20;
  double shaperElderDecorationSize = 27;

  Item(String name,
      List<Mod> prefixes,
      List<Mod> suffixes,
      List<Mod> implicits,
      List<String> tags,
      WeaponProperties weaponProperties,
      ArmourProperties armourProperties,
      String itemClass,
      int itemLevel,
      String domain,
      SpendingReport spendingReport,
      Item imprint) {
    this.name = name;
    this.prefixes = prefixes;
    this.suffixes = suffixes;
    this.tags = tags;
    this.weaponProperties = weaponProperties;
    this.armourProperties = armourProperties;
    this.itemClass = itemClass;
    this.implicits = implicits;
    this.itemLevel = itemLevel;
    this.domain = domain;
    this.spendingReport = spendingReport;
    this.imprint = imprint;

    this.implicits.forEach((implicit) {
      implicit.stats.forEach((stat) {
        stat.value = stat.max;
      });
    });
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    String rarity = json['rarity'];
    switch (rarity) {
      case "rare":
        return RareItem.fromJson(json);
        break;
      case "magic":
        return MagicItem.fromJson(json);
        break;
      case "normal":
        return NormalItem.fromJson(json);
        break;
    }
    return null;
  }

  factory Item.copy(Item item) {
    if (item is RareItem) {
      List<Mod> prefixes = List.generate(item.prefixes.length, (index) => Mod.copy(item.prefixes[index]));
      List<Mod> suffixes = List.generate(item.suffixes.length, (index) => Mod.copy(item.suffixes[index]));
      return RareItem.fromItem(item, prefixes, suffixes);
    } else if (item is MagicItem) {
      List<Mod> prefixes = List.generate(item.prefixes.length, (index) => Mod.copy(item.prefixes[index]));
      List<Mod> suffixes = List.generate(item.suffixes.length, (index) => Mod.copy(item.suffixes[index]));
      return MagicItem.fromItem(item, prefixes, suffixes);
    } else if (item is NormalItem) {
      return NormalItem.fromItem(item, List(), List());
    } else {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    String rarity;
    if (this is RareItem) {
      rarity = "rare";
    } else if (this is MagicItem) {
      rarity = "magic";
    } else if (this is NormalItem){
      rarity = "normal";
    }

    var properties;
    if (weaponProperties != null) {
      properties = weaponProperties.toJson();
    } else if (armourProperties != null) {
      properties = armourProperties.toJson();
    }
    return {
      "name": name,
      "prefixes": Mod.encodeToJson(prefixes),
      "suffixes": Mod.encodeToJson(suffixes),
      "implicits": Mod.encodeToJson(implicits),
      "tags": json.encode(tags),
      "properties": properties,
      "item_class": itemClass,
      "rarity": rarity,
      "item_level": itemLevel,
      "domain": domain,
      "spending_report": spendingReport.toJson(),
      "imprint": imprint != null ? imprint.toJson() : null
    };
  }

  static List encodeToJson(List<Item> items) {
    List jsonList = List();
    items.forEach((item) {
      if (item != null) {
        jsonList.add(item.toJson());
      }
    });
    return jsonList;
  }

  List<Mod> getMods() {
    List<Mod> mods = List();
    mods.addAll(prefixes);
    mods.addAll(suffixes);
    return mods;
  }

  void clearMods() {
    prefixes.clear();
    suffixes.clear();
  }

  Item divine() {
    spendingReport.addSpending(CurrencyType.divine, 1);
    if (!hasCannotChangePrefixes()) {
      for (Mod mod in prefixes) {
        mod.rerollStatValues();
      }
    }
    if (!hasCannotChangeSuffixes()) {
      for (Mod mod in suffixes) {
        mod.rerollStatValues();
      }
    }
    return this;
  }

  void addPrefix({List<Fossil> fossils: const []}) {
    Mod prefix = ModRepository.instance.getPrefix(this, fossils);
    if (prefix == null) {
      return;
    }
    prefix.rerollStatValues();
    prefixes.add(prefix);
  }

  void addSuffix({List<Fossil> fossils: const []}) {
    Mod suffix = ModRepository.instance.getSuffix(this, fossils);
    if (suffix == null) {
      return;
    }
    suffix.rerollStatValues();
    suffixes.add(suffix);
  }

  bool canAddMod(Mod mod){
    if(this.alreadyHasModGroup(mod)){
      return false;
    }
    if(mod.generationType == "prefix"){
      if(this.hasMaxPrefixes() || this.hasCannotChangePrefixes()){
        return false;
      }
    }
    else if(mod.generationType == "suffix"){
      if(this.hasMaxSuffixes() || this.hasCannotChangeSuffixes()){
        return false;
      }
    }
    return true;
  }

  void addMod(Mod mod){
    if(mod.generationType == "prefix"){
      this.prefixes.add(mod);
    }
    else if(mod.generationType == "suffix"){
      this.suffixes.add(mod);
    }
  }

  Item tryAddMasterMod(CraftingBenchOption option) {
    final mod = option.mod;
    mod.rerollStatValues();
    var added = false;

    if (getMods().contains(mod)) {
      getMods().firstWhere((m) => m == mod).rerollStatValues();
      prefixes.removeWhere((m) => m.domain == "crafted");
      suffixes.removeWhere((m) => m.domain == "crafted");
      spendingReport.addSpending(CurrencyType.scour, 1);
    }
    switch (mod.generationType) {
      case "prefix":
        if (!hasMaxPrefixes()) {
          prefixes.add(mod);
          added = true;
        }
        break;
      case "suffix":
        if (!hasMaxSuffixes()) {
          suffixes.add(mod);
          added = true;
        }
        break;
      default:
        break;
    }

    if(added) {
      for(final cost in option.costs){
        spendingReport.addSpending(CurrencyType.idToCurrency[cost.itemId], cost.count);
      }
    }

    return this;
  }

  RareItem applyEssence(Essence essence) {
    String essenceModId = essence.getModIdForItem(this);
    assert(essenceModId != null);
    Mod mod = ModRepository.instance.getModById(essenceModId);
    assert(mod != null);
    mod.rerollStatValues();
    RareItem item = RareItem.fromItem(this, List(), List());
    if (mod.generationType == "prefix") {
      item.prefixes.add(mod);
    } else {
      item.suffixes.add(mod);
    }
    item.fillMods();
    spendingReport.spendEssence(essence);
    return item;
  }

  Item removeMasterMods() {
    spendingReport.addSpending(CurrencyType.scour, 1);
    prefixes.removeWhere((mod) => mod.domain == "crafted");
    suffixes.removeWhere((mod) => mod.domain == "crafted");
    return this;
  }

  bool hasMasterMod() {
    return getMods().any((mod) => mod.domain == "crafted");
  }

  bool hasMultiMod() {
    return getMods().any((mod) => mod.group == "ItemGenerationCanHaveMultipleCraftedMods");
  }

  bool hasCannotChangePrefixes() {
    return suffixes.any((mod) => mod.group == "ItemGenerationCannotChangePrefixes");
  }

  bool hasCannotChangeSuffixes() {
    return prefixes.any((mod) => mod.group == "ItemGenerationCannotChangeSuffixes");
  }

  bool hasCannotRollAttackMods() {
    return suffixes.any((mod) => mod.group == "ItemGenerationCannotRollAttackAffixes");
  }

  bool hasCannotRollCasterMods() {
    return suffixes.any((mod) => mod.group == "ItemGenerationCannotRollCasterAffixes");
  }

  void reroll({List<Fossil> fossils: const[]});

  void addRandomMod();

  bool hasMaxPrefixes() {
    return prefixes.length >= maxNumberOfPrefixes();
  }

  bool hasMaxSuffixes() {
    return suffixes.length >= maxNumberOfSuffixes();
  }

  bool hasMaxMods() {
    return prefixes.length + suffixes.length >= maxNumberOfAffixes();
  }

  int maxNumberOfAffixes();
  int maxNumberOfPrefixes();
  int maxNumberOfSuffixes();

  RareItem useFossils(List<Fossil> fossils);

  Item scourSuffixes();
  Item scourPrefixes();
  String getRarity();

  @override
  String toString() {
    return name;
  }

  List<String> getStatStrings() {
    return getMods()
        .map((mod) => mod.getStatStrings())
        .expand((string) => string)
        .toList();
  }

  List<String> getImplicitStrings() {
    return implicits
        .where((mod) => mod != null)
        .map((mod) => mod.getStatStrings())
        .expand((string) => string)
        .toList();
  }

  bool alreadyHasModGroup(Mod mod) {
    for (Mod ownMod in getMods()) {
      if (ownMod.group == mod.group) {
        return true;
      }
    }
    return false;
  }

  Widget getItemWidget(bool advancedMods, Function onTap) {
    return SingleChildScrollView(
      child: Column(children: <Widget>[
        getTitleWidget(),
        getStatWidget(),
        getImplicitWidget(),
        divider(),
        advancedMods ? getAdvancedModWidget(onTap) : getModWidget(onTap),
      ]),
    );
  }

  Widget divider() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2, child: Container(height: 8, color: Colors.black),
        ),
        Expanded(
          flex: 6,
          child: Container(
              height: 8,
              decoration: new BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(getDividerImagePath()),
                    fit: BoxFit.fill
                ),
              ),
          ),
        ),
        Expanded(
          flex: 2, child: Container(height: 8, color: Colors.black),
        )
      ],
    );
  }

  Widget getActionsWidget(CraftingWidgetState state);

  Widget getAdvancedModWidget(Function onTap) {
    List<Widget> widgets = List();
    widgets.addAll(getAdvancedModListWidgets(getMods().where((mod) => mod.domain != "crafted").toList(), modColor));
    widgets.addAll(getAdvancedModListWidgets(getMods().where((mod) => mod.domain == "crafted").toList(), Colors.white));
    return GestureDetector(onTap: onTap, child: Column(children: widgets));
  }
  
  Widget getModWidget(Function onTap) {
    List<Widget> widgets = List();
    widgets.addAll(getCombinedModListWidgets(getMods().where((mod) => mod.domain != "crafted").toList(), modColor));
    widgets.addAll(getCombinedModListWidgets(getMods().where((mod) => mod.domain == "crafted").toList(), Colors.white));
    return GestureDetector(onTap: onTap, child: Column(children: widgets));
  }

  List<Widget> getModListWidgets(List<Mod> mods, Color color) {
    List<Widget> widgets = List();
    List<TranslationWithSorting> translations = mods.map((mod) => mod.getStatStringsWithSorting())
        .expand((list) => list)
        .toList();
    translations.sort((a, b) => a.sorting - b.sorting);
    translations.forEach((translation) {
      Widget row = statRow(translation.translation, color);
      widgets.add(row);
    });
    return widgets;
  }

  List<Widget> getAdvancedModListWidgets(List<Mod> mods, Color color) {
    List<Widget> widgets = List();
    mods.sort((a, b) => a.compareTo(b));
    for (Mod mod in mods) {
      String affix = mod.generationType == "prefix" ? "P" : "S";
      int tier = ModRepository.instance.getModTier(mod);
      widgets.add(statDescriptionRow("$affix$tier mod \"${mod.name}\""));
      mod.getAdvancedStatStrings().forEach((statString) {
        Widget row = statRow(statString, color);
        widgets.add(row);
      });
    }
    return widgets;
  }

  List<Widget> getCombinedModListWidgets(List<Mod> mods, Color color) {
    Map<String, Stat> combinedStatsMap = Map();
    mods.map((mod) => mod.stats)
        .expand((stats) => stats)
        .forEach((stat) {
      if (combinedStatsMap[stat.id] == null) {
        combinedStatsMap[stat.id] = Stat.copy(stat);
      } else {
        combinedStatsMap[stat.id].value += stat.value;
        combinedStatsMap[stat.id].max += stat.max;
        combinedStatsMap[stat.id].min += stat.min;
      }
    });

    List<Mod> combinedMods = mods.map((mod) => Mod.copy(mod)).toList();
    combinedMods.forEach((mod) {
      List<Stat> newStats = List();
      for (Stat stat in mod.stats) {
        Stat combinedStat =  combinedStatsMap[stat.id];
        if (combinedStat != null) {
          stat.value = combinedStat.value;
          stat.max = combinedStat.max;
          stat.min = combinedStat.min;
          combinedStatsMap[stat.id] = null;
          newStats.add(stat);
        }

      }
      mod.stats = newStats;
    });
    return getModListWidgets(combinedMods, color);
  }

  Widget statRow(String text, Color color) {
    return itemRow(Text(
      text,
      style: TextStyle(color: color, fontSize: modFontSize),
      textAlign: TextAlign.center,
    ));
  }

  Widget itemModRow(String text) {
    return itemRow(Text(
      text,
      style: TextStyle(color: statTextColor, fontSize: modFontSize),
      textAlign: TextAlign.center,
    ));
  }

  Widget statDescriptionRow(String text) {
    return zeroPaddingItemRow(Text(
      text,
      style: TextStyle(color: statTextColor, fontSize: advancedModFontSize, fontStyle: FontStyle.italic),
      textAlign: TextAlign.center,
    ));
  }

  Widget itemRow(Widget child) {
    return Container(
      color: Colors.black,
      child: Center(
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: child,
          )),
    );
  }

  Widget zeroPaddingItemRow(Widget child) {
    return Container(
      color: Colors.black,
      child: Center(
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: child,
          )),
    );
  }

  Widget getTitleWidget() {
    List<Widget> leftStackWidgets = List();
    List<Widget> rightStackWidgets = List();

    leftStackWidgets.add(
        Container(
            height: getHeaderHeight(),
            width: getHeaderDecorationWidth(),
            decoration: new BoxDecoration(
              image: DecorationImage(
                  image: AssetImage(getHeaderLeftImagePath()),
                  fit: BoxFit.fill
              ),
            )
        )
    );

    rightStackWidgets.add(
        Container(
            height: getHeaderHeight(),
            width: getHeaderDecorationWidth(),
            decoration: new BoxDecoration(
              image: DecorationImage(
                  image: AssetImage(getHeaderRightImagePath()),
                  fit: BoxFit.fill
              ),
            )
        )
    );

    if (tags.any((tag) => tag.contains("elder"))) {
      leftStackWidgets.add(
          Positioned(
            top: (getHeaderHeight() - shaperElderDecorationSize) / 2,
            child: Container(
                height: shaperElderDecorationSize,
                width: shaperElderDecorationSize,
                decoration: new BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(getElderImagePath()),
                      fit: BoxFit.fill
                  ),
                )
            ),
          )
      );

      rightStackWidgets.add(
          Positioned(
            top: (getHeaderHeight() - shaperElderDecorationSize) / 2,
            left: getHeaderDecorationWidth() - shaperElderDecorationSize,
            child: Container(
                height: 27,
                width: 27,
                decoration: new BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(getElderImagePath()),
                      fit: BoxFit.fill
                  ),
                )
            ),
          )
      );
    } else if (tags.any((tag) => tag.contains("shaper"))) {
      leftStackWidgets.add(
          Positioned(
            top: (getHeaderHeight() - shaperElderDecorationSize) / 2,
            child: Container(
                height: shaperElderDecorationSize,
                width: shaperElderDecorationSize,
                decoration: new BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(getShaperImagePath()),
                      fit: BoxFit.fill
                  ),
                )
            ),
          )
      );

      rightStackWidgets.add(
          Positioned(
            top: (getHeaderHeight() - shaperElderDecorationSize) / 2,
            left: getHeaderDecorationWidth() - 27,
            child: Container(
                height: shaperElderDecorationSize,
                width: shaperElderDecorationSize,
                decoration: new BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage(getShaperImagePath()),
                      fit: BoxFit.fill
                  ),
                )
            ),
          )
      );
    }

    return Row(
      children: <Widget>[
        Stack(
          children: leftStackWidgets,
        ),
        Expanded(
          child: Container(
              height: getHeaderHeight(),
              decoration: new BoxDecoration(
                image: DecorationImage(
                    image: AssetImage(getHeaderMiddleImagePath()),
                    fit: BoxFit.fill
                ),
              ),
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(color: getTextColor(), fontSize: titleFontSize),
                ),
              )
          ),
        ),
        Stack(children: rightStackWidgets),
      ],
    );
  }

  Widget getStatWidget() {
    if (weaponProperties != null) {
      return weaponStatWidget();
    } else if (armourProperties != null) {
      return armourStatWidget();
    } else {
      return Column();
    }
  }

  TextSpan commaSpan() {
    return TextSpan(text: ", ", style: TextStyle(color: statTextColor, fontSize: modFontSize));
  }

  TextSpan coloredText(String text, Color color) {
    return TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: modFontSize, fontFamily: 'Fontin'));
  }

  RichText statWithColoredChildren(String text, List<TextSpan> children) {
    return RichText(
        text: TextSpan(text: text,
            style: TextStyle(color: statTextColor, fontSize: modFontSize, fontFamily: 'Fontin'),
            children: children));
  }

  Widget getImplicitWidget() {
    if (implicits == null || implicits.isEmpty) {
      return Column();
    }
    List<Widget> children = List();
    children.add(divider());
    children.addAll(getImplicitStrings()
        .map((implicitString) => statRow(implicitString, modColor))
        .toList());
    return Column(children: children);
  }

  Widget weaponStatWidget() {
    List<Widget> statWidgets = List();
    int addedMinimumPhysicalDamage = weaponProperties.physicalDamageMin;
    int addedMaximumPhysicalDamage = weaponProperties.physicalDamageMax;
    int addedMinimumColdDamage = 0;
    int addedMaximumColdDamage = 0;
    int addedMinimumFireDamage = 0;
    int addedMaximumFireDamage = 0;
    int addedMinimumLightningDamage = 0;
    int addedMaximumLightningDamage = 0;
    int addedMinimumChaosDamage = 0;
    int addedMaximumChaosDamage = 0;
    int increasedPhysicalDamage = 100;
    int increasedAttackSpeed = 100;
    int increasedCriticalStrikeChange = 100;
    int quality = 30;

    List<Mod> allMods = List();
    allMods.addAll(getMods());
    allMods.addAll(implicits);
    for (Stat stat in allMods.map((mod) => mod.stats).expand((stat) => stat)) {
      switch (stat.id) {
        case "local_minimum_added_physical_damage":
          addedMinimumPhysicalDamage += stat.value;
          break;
        case "local_maximum_added_physical_damage":
          addedMaximumPhysicalDamage += stat.value;
          break;
        case "local_minimum_added_fire_damage":
          addedMinimumFireDamage += stat.value;
          break;
        case "local_maximum_added_fire_damage":
          addedMaximumFireDamage += stat.value;
          break;
        case "local_minimum_added_cold_damage":
          addedMinimumColdDamage += stat.value;
          break;
        case "local_maximum_added_cold_damage":
          addedMaximumColdDamage += stat.value;
          break;
        case "local_minimum_added_lightning_damage":
          addedMinimumLightningDamage += stat.value;
          break;
        case "local_maximum_added_lightning_damage":
          addedMaximumLightningDamage += stat.value;
          break;
        case "local_minimum_added_chaos_damage":
          addedMinimumChaosDamage += stat.value;
          break;
        case "local_maximum_added_chaos_damage":
          addedMaximumChaosDamage += stat.value;
          break;
        case "local_attack_speed_+%":
          increasedAttackSpeed += stat.value;
          break;
        case "local_physical_damage_+%":
          increasedPhysicalDamage += stat.value;
          break;
        case "local_critical_strike_chance_+%":
          increasedCriticalStrikeChange += stat.value;
          break;
        case "local_item_quality_+":
          quality += stat.value;
          break;
        default:
          break;
      }
    }
    increasedPhysicalDamage += quality;
    addedMinimumPhysicalDamage =  (addedMinimumPhysicalDamage * increasedPhysicalDamage / 100).floor();
    addedMaximumPhysicalDamage = (addedMaximumPhysicalDamage * increasedPhysicalDamage / 100).floor();
    double attacksPerSecond = (increasedAttackSpeed/100) * (1000/weaponProperties.attackTime);
    var pDPS = (addedMinimumPhysicalDamage + addedMaximumPhysicalDamage) / 2 * attacksPerSecond;
    var eDPS = (
        addedMinimumFireDamage + addedMaximumFireDamage +
        addedMinimumColdDamage + addedMaximumColdDamage +
        addedMinimumLightningDamage + addedMaximumLightningDamage)
        / 2 * attacksPerSecond;
    var cDPS = (addedMinimumChaosDamage + addedMaximumChaosDamage) / 2 * attacksPerSecond;
    var DPS = pDPS + eDPS + cDPS;
    String addedMinimumPhysString = "${addedMinimumPhysicalDamage.toStringAsFixed(0)}";
    String addedMaximumPhysString = "${addedMaximumPhysicalDamage.toStringAsFixed(0)}";
    String attacksPerSecondString = "${attacksPerSecond.toStringAsFixed(2)}";
    String criticalStrikeChanceString = "${((weaponProperties.criticalStrikeChance/100) * (increasedCriticalStrikeChange / 100)).toStringAsFixed(2)}";
    statWidgets.add(itemModRow(itemClass));
    statWidgets.add(itemRow(statWithColoredChildren("Quality: ", [coloredText("+$quality%", modColor)])));
    statWidgets.add(itemRow(statWithColoredChildren("Physical Damage: ", [coloredText("$addedMinimumPhysString-$addedMaximumPhysString", modColor)])));
    List<TextSpan> elementalDamageSpans = List();
    if (addedMinimumFireDamage > 0) {
      elementalDamageSpans.add(coloredText("$addedMinimumFireDamage-$addedMaximumFireDamage", fireDamage));
    }
    if (addedMinimumColdDamage > 0) {
      if (elementalDamageSpans.isNotEmpty) {
        elementalDamageSpans.add(commaSpan());
      }
      elementalDamageSpans.add(coloredText("$addedMinimumColdDamage-$addedMaximumColdDamage", coldDamage));
    }
    if (addedMinimumLightningDamage > 0) {
      if (elementalDamageSpans.isNotEmpty) {
        elementalDamageSpans.add(commaSpan());
      }
      elementalDamageSpans.add(coloredText("$addedMinimumLightningDamage-$addedMaximumLightningDamage", lightningDamage));
    }
    if (elementalDamageSpans.isNotEmpty) {
      statWidgets.add(itemRow(statWithColoredChildren("Elemental Damage: ", elementalDamageSpans)));
    }
    if (addedMinimumChaosDamage > 0) {
      statWidgets.add(itemRow(statWithColoredChildren("Chaos Damage: ", [
        coloredText("$addedMinimumChaosDamage-$addedMaximumChaosDamage",
            chaosDamage)
      ])));
    }

    statWidgets.add(itemRow(statWithColoredChildren("Critical Strike Chance: ", [coloredText("$criticalStrikeChanceString%", increasedCriticalStrikeChange > 100 ? modColor : statTextColor)])));
    statWidgets.add(itemRow(statWithColoredChildren("Attacks per Second: ", [coloredText("$attacksPerSecondString", increasedAttackSpeed > 100 ? modColor : statTextColor)])));

    statWidgets.add(dpsWidget(pDPS, eDPS, DPS));
    return Column(children: statWidgets);
  }

  Widget dpsWidget(double pDps, double eDps, double dps) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Text("DPS: ${dps.toStringAsFixed(1)}", style: TextStyle(color: statTextColor, fontSize: 16)),
        Text("pDPS: ${pDps.toStringAsFixed(1)}", style: TextStyle(color: statTextColor, fontSize: 16)),
        Text("eDPS: ${eDps.toStringAsFixed(1)}", style: TextStyle(color: statTextColor, fontSize: 16)),
      ],
    );
  }

  Widget armourStatWidget() {
    List<Widget> statWidgets = List();
    int baseArmour = armourProperties.armour != null ? armourProperties.armour : 0;
    int baseEvasion = armourProperties.evasion != null ? armourProperties.evasion : 0;
    int baseEnergyShield = armourProperties.energyShield != null ? armourProperties.energyShield : 0;
    int baseBlockChance = armourProperties.block;
    int armourMultiplier = 100;
    int evasionMultiplier = 100;
    int energyShieldMultiplier = 100;
    int quality = 30;
    int addedBlockChance = 0;

    List<Mod> allMods = List();
    allMods.addAll(getMods());
    allMods.addAll(implicits);
    for (Stat stat in allMods.map((mod) => mod.stats).expand((stat) => stat)) {
      switch (stat.id) {
        case "local_base_evasion_rating":
          baseEvasion += stat.value;
          break;
        case "local_evasion_rating_+%":
          evasionMultiplier += stat.value;
          break;
        case "local_energy_shield":
          baseEnergyShield += stat.value;
          break;
        case "local_energy_shield_+%":
          energyShieldMultiplier += stat.value;
          break;
        case "local_base_physical_damage_reduction_rating":
          baseArmour += stat.value;
          break;
        case "local_physical_damage_reduction_rating_+%":
          armourMultiplier += stat.value;
          break;
        case "local_armour_and_energy_shield_+%":
          energyShieldMultiplier += stat.value;
          armourMultiplier += stat.value;
          break;
        case "local_evasion_and_energy_shield_+%":
          evasionMultiplier += stat.value;
          energyShieldMultiplier += stat.value;
          break;
        case "local_armour_and_evasion_+%":
          evasionMultiplier += stat.value;
          armourMultiplier += stat.value;
          break;
        case "local_armour_and_evasion_and_energy_shield_+%":
          evasionMultiplier += stat.value;
          armourMultiplier += stat.value;
          energyShieldMultiplier += stat.value;
          break;
        case "local_item_quality_+":
          quality += stat.value;
          break;
        case "local_additional_block_chance_%":
          addedBlockChance += stat.value;
          break;
        default:
          break;
      }
    }

    statWidgets.add(itemModRow(itemClass));
    statWidgets.add(itemRow(statWithColoredChildren("Quality: ", [coloredText("+$quality%", modColor)])));

    if (baseBlockChance != null) {
      int totalBlockChance = baseBlockChance + addedBlockChance;
      statWidgets.add(
          itemRow(
              statWithColoredChildren(
                  "Block Chance: ",
                  [coloredText("$totalBlockChance%", addedBlockChance > 0 ? modColor : statTextColor)])));
    }
    if (baseArmour != 0) {
      var totalArmour = baseArmour * (armourMultiplier + quality) / 100;
      if (totalArmour > 0) {
        statWidgets.add(itemRow(statWithColoredChildren("Armour: ", [coloredText("${totalArmour.toStringAsFixed(0)}", modColor)])));
      }
    }

    if (baseEvasion != 0) {
      var totalEvasion = baseEvasion * (evasionMultiplier + quality) / 100;
      if (totalEvasion > 0) {
        statWidgets.add(itemRow(statWithColoredChildren("Evasion: ", [coloredText("${totalEvasion.toStringAsFixed(0)}", modColor)])));
      }
    }

    if (baseEnergyShield != 0) {
      var totalEnergyShield = baseEnergyShield * (energyShieldMultiplier + quality) / 100;
      if (totalEnergyShield > 0) {
        statWidgets.add(itemRow(statWithColoredChildren("Energy Shield: ", [coloredText("${totalEnergyShield.toStringAsFixed(0)}", modColor)])));
      }
    }

    return Column(children: statWidgets);
  }

  String getElderImagePath() {
    return 'assets/images/elder-symbol.png';
  }

  String getShaperImagePath() {
    return 'assets/images/shaper-symbol.png';
  }

  List<String> getAllTags() {
    List<String> allTags = List();
    allTags.addAll(tags);
    getMods().forEach((mod) {
      if (mod.addsTags != null && mod.addsTags.isNotEmpty) {
        allTags.addAll(mod.addsTags);
      }
    });
    implicits.forEach((mod) {
      if (mod.addsTags != null && mod.addsTags.isNotEmpty) {
        allTags.addAll(mod.addsTags);
      }
    });
    return allTags;
  }

  Color getTextColor();
  Color getBorderColor();
  Color getBoxColor();
  String getHeaderRightImagePath();
  String getHeaderLeftImagePath();
  String getHeaderMiddleImagePath();
  String getDividerImagePath();
  double getHeaderHeight();
  double getHeaderDecorationWidth();
}
