import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'item.dart';
import 'normal_item.dart';
import 'rare_item.dart';
import '../mod.dart';
import '../properties.dart';
import '../fossil.dart';
import '../currency_type.dart';
import '../../widgets/crafting_widget.dart';
import '../../widgets/utils.dart';
import 'spending_report.dart';

class MagicItem extends Item {
  MagicItem(String name,
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
      Item imprint,
      bool corrupted,
      )
      : super(
      name,
      prefixes,
      suffixes,
      implicits,
      tags,
      weaponProperties,
      armourProperties,
      itemClass,
      itemLevel,
      domain,
      spendingReport,
      imprint,
      corrupted);

  factory MagicItem.fromJson(Map<String, dynamic> data) {
    var prefixesJson = data['prefixes'] as List;
    List<Mod> prefixes = prefixesJson.map((prefix) => Mod.fromSavedJson(prefix)).toList();
    var suffixesJson = data['suffixes'] as List;
    List<Mod> suffixes = suffixesJson.map((suffix) => Mod.fromSavedJson(suffix)).toList();
    var implicitsJson = data['implicits'] as List;
    List<Mod> implicits = implicitsJson.map((implicit) => Mod.fromSavedJson(implicit)).toList();
    List<String> tags = new List<String>.from(json.decode(data['tags']));

    WeaponProperties weaponProperties;
    ArmourProperties armourProperties;
    if (tags.contains("weapon")) {
      weaponProperties = WeaponProperties.fromJson(data['properties']);
    } else if (tags.contains("armour")) {
      armourProperties = ArmourProperties.fromJson(data['properties']);
    }
    dynamic spendingReportData = data['spending_report'];

    return MagicItem(
        data['name'],
        prefixes,
        suffixes,
        implicits,
        tags,
        weaponProperties,
        armourProperties,
        data['item_class'],
        data['item_level'],
        // Shitty fix for loading old items
        data['domain'] != null ? data['domain'] : 'item',
        spendingReportData != null ? SpendingReport.fromJson(spendingReportData) : null,
        data['imprint'] != null ? Item.fromJson(data['imprint']) : null,
        data['corrupted'] != null ? data['corrupted'] : false,
    );
  }

  factory MagicItem.fromItem(Item item, List<Mod> prefixes, List<Mod> suffixes) {
    return MagicItem(
        item.name,
        prefixes,
        suffixes,
        item.implicits,
        item.tags,
        item.weaponProperties,
        item.armourProperties,
        item.itemClass,
        item.itemLevel,
        item.domain,
        item.spendingReport,
        item != null ? Item.copy(item.imprint) : null,
        item.corrupted);
  }

  @override
  Color getBorderColor() {
    return Color(0xFF393E5C);
  }

  @override
  Color getBoxColor() {
    return Color(0xFF19192B);
  }

  @override
  Color getTextColor() {
    return Color(0xFF959AF6);
  }

  @override
  void reroll({List<Fossil> fossils: const[]}) {
    clearMods();
    // 1 or 2 mods, 50/50
    final int nMods = rng.nextInt(2) + 1;
    if (nMods == 2) {
      addPrefix();
      addSuffix();
    } else {
      rng.nextBool() ? addSuffix() : addPrefix();
    }
  }

  RareItem regal() {
    spendingReport.addSpending(CurrencyType.regal, 1);
    RareItem item = RareItem.fromItem(this, prefixes, suffixes);
    item.addRandomMod();
    return item;
  }

  MagicItem augment() {
    if (prefixes.length + suffixes.length == maxNumberOfAffixes()) {
      return this;
    }
    spendingReport.addSpending(CurrencyType.augmentation, 1);
    addRandomMod();
    return this;
  }

  MagicItem alteration() {
    spendingReport.addSpending(CurrencyType.alteration, 1);
    reroll();
    return this;
  }

  NormalItem scour() {
    spendingReport.addSpending(CurrencyType.scour, 1);
    return NormalItem.fromItem(this, List(), List());
  }

  MagicItem annulment() {
    if (prefixes.isEmpty && suffixes.isEmpty) {
      return this;
    }
    this.spendingReport.addSpending(CurrencyType.annulment, 1);
    Mod modToRemove;
    if (suffixes.any((mod) => mod.group == "ItemGenerationCannotChangePrefixes")) {
      modToRemove = suffixes[rng.nextInt(suffixes.length)];
    } else if (prefixes.any((mod) => mod.group == "ItemGenerationCannotChangeSuffixes")) {
      modToRemove = prefixes[rng.nextInt(prefixes.length)];
    } else {
      List<Mod> mods = getMods();
      modToRemove = mods[rng.nextInt(mods.length)];
    }
    if (modToRemove.generationType == "prefix") {
      prefixes.remove(modToRemove);
    } else {
      suffixes.remove(modToRemove);
    }
    return this;
  }

  @override
  RareItem useFossils(List<Fossil> fossils) {
    RareItem item = RareItem.fromItem(this, List(), List());
    return item.useFossils(fossils);
  }

  @override
  Item scourPrefixes() {
    return this;
  }

  @override
  Item scourSuffixes() {
    return this;
  }

  int maxNumberOfAffixes() {
    return 2;
  }

  int maxNumberOfPrefixes() {
    return 1;
  }

  int maxNumberOfSuffixes() {
    return 1;
  }

  @override
  void addRandomMod() {
    List<Mod> mods = getMods();
    // Max mods
    if (mods.length == maxNumberOfAffixes()) {
      return;
    }
    else if (mods.length == 0) {
      if (rng.nextBool()) {
        addPrefix();
      } else {
        addSuffix();
      }
    } else if (hasMaxPrefixes()) {
      addSuffix();
    } else {
      addPrefix();
    }
  }

  @override
  Widget getNormalActionsWidget(CraftingWidgetState state) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          imageButton(
              'assets/images/scour.png', 'Orb of Scouring', () =>
              state.itemChanged(this.scour())),
          imageButton('assets/images/alteration.png', 'Orb of Alteration', () =>
              state.itemChanged(this.alteration())),
          imageButton(
              'assets/images/augmentation.png', 'Orb of Augmentation', () =>
              state.itemChanged(this.augment())),
          imageButton(
              'assets/images/regal.png', 'Regal orb', () =>
              state.itemChanged(this.regal())),
          imageButton('assets/images/annulment.png', 'Orb of Annulment', () =>
              state.itemChanged(this.annulment())),
          imageButton('assets/images/divine.png', 'Divine orb', () =>
              state.itemChanged(this.divine())),
        ]);
  }

  @override
  Widget getDisabledActionsWidget(CraftingWidgetState state) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          imageButton(
              'assets/images/scour.png', 'Orb of Scouring', null),
          imageButton('assets/images/alteration.png', 'Orb of Alteration', null),
          imageButton(
              'assets/images/augmentation.png', 'Orb of Augmentation', null),
          imageButton(
              'assets/images/regal.png', 'Regal orb', null),
          imageButton('assets/images/annulment.png', 'Orb of Annulment', null),
          imageButton('assets/images/divine.png', 'Divine orb', null),
        ]);
  }

  @override
  String getRarity() {
    return "magic";
  }

  @override
  String getHeaderLeftImagePath() {
    return 'assets/images/header-magic-left.png';
  }

  @override
  String getHeaderMiddleImagePath() {
    return 'assets/images/header-magic-middle.png';

  }

  @override
  String getHeaderRightImagePath() {
    return 'assets/images/header-magic-right.png';
  }

  @override
  String getDividerImagePath() {
    return 'assets/images/seperator-magic.png';
  }

  @override
  double getHeaderDecorationWidth() {
    return 29;
  }

  @override
  double getHeaderHeight() {
    return 34;
  }
}