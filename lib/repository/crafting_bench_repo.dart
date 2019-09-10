import 'dart:async' show Future;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../crafting/mod.dart';
import '../crafting/item/item.dart';
import 'mod_repo.dart';

class CraftingBenchRepository {

  CraftingBenchRepository._privateConstructor();
  static final CraftingBenchRepository instance = CraftingBenchRepository._privateConstructor();

  List<CraftingBenchOption> craftingBenchOptions;
  List<CraftingBenchOption> craftingBenchOptionsWithCost;

  Future<bool> initialize() async {
    craftingBenchOptions = List();
    craftingBenchOptionsWithCost = List();
    var data = await rootBundle.loadString('data_repo/crafting_bench_options.json');
    var dataWithCost = await rootBundle.loadString('data_repo/crafting_bench_options_with_cost.json');

    // Legacy stuff with costs
    json.decode(dataWithCost).forEach((data) {
      CraftingBenchOption craftingBenchOption = CraftingBenchOption.fromJsonWithCost(data);
      craftingBenchOptionsWithCost.add(craftingBenchOption);
    });

    // 3.8 stuff
    json.decode(data).forEach((data) {
      String modId = data['mod_id'];
      List<CraftingBenchOptionCost> costs = List();
      if (craftingBenchOptionsWithCost.any((CraftingBenchOption element) => element.mod.id == modId)) {
        costs = craftingBenchOptionsWithCost.firstWhere((CraftingBenchOption element) => element.mod.id == modId).costs;
      } else {
        print("ModId: $modId does not have cost");
      }

      CraftingBenchOption craftingBenchOption = CraftingBenchOption.fromJsonWithoutCost(data, costs: costs);
      craftingBenchOptions.add(craftingBenchOption);
    });
    return true;
  }

  Map<String, List<CraftingBenchOption>> getCraftingOptionsForItem(Item item) {
    Map<String, List<CraftingBenchOption>> optionsMap = Map();
    for (CraftingBenchOption option in craftingBenchOptions) {
      if (itemCanHaveMod(item, option)) {
        if (optionsMap[option.benchGroup] == null) {
          optionsMap[option.benchGroup] = List();
        }
        optionsMap[option.benchGroup].add(option);
      }
    }
    optionsMap.values.forEach((list) => list.sort((a, b) => a.compareTo(b)));
    return optionsMap;
  }
}

bool itemCanHaveMod(Item item, CraftingBenchOption option) {
  if (!option.itemClasses.contains(item.itemClass)
      || item.getMods().map((mod) => mod.group).contains(option.mod.group)) {
    return false;  
  }

  if (!item.hasMultiMod() && item.hasMasterMod()) {
    return false;
  }

  if (option.mod.generationType == "prefix") {
    return !item.hasMaxPrefixes();
  }
  return !item.hasMaxSuffixes();
}

class CraftingBenchOptionCost {
  final String itemId;
  final int count;

  CraftingBenchOptionCost(this.itemId, this.count);
}

class CraftingBenchOption implements Comparable<CraftingBenchOption> {
  String benchDisplayName;
  String benchGroup;
  int benchTier;
  List<String> itemClasses;
  Mod mod;
  List<CraftingBenchOptionCost> costs;

  CraftingBenchOption({
    this.benchDisplayName,
    this.benchGroup,
    this.benchTier,
    this.itemClasses,
    this.mod,
    this.costs
  });

  factory CraftingBenchOption.fromJsonWithCost(Map<String, dynamic> json) {
    String modId = json['mod_id'];
    Mod mod = ModRepository.instance.getModById(modId);
    String displayName = mod.getStatStringWithValueRanges().join("\n");
    List<String> costItemTypes = List<String>.from(json['cost_types']);
    List<int> costCounts = List<int>.from(json['cost_counts']);
    final costs = List<CraftingBenchOptionCost>.generate(costItemTypes.length, 
                                          (index) => CraftingBenchOptionCost(costItemTypes[index], 
                                                                            costCounts[index]));
    return CraftingBenchOption(
      benchDisplayName: displayName,
      benchGroup: json['bench_group'],
      benchTier: json['bench_tier'],
      itemClasses: List<String>.from(json['item_classes']),
      mod: mod,
      costs: costs
    );
  }

  factory CraftingBenchOption.fromJsonWithoutCost(Map<String, dynamic> json, {List<CraftingBenchOptionCost> costs = const []}) {
    String modId = json['mod_id'];
    Mod mod = ModRepository.instance.getModById(modId);
    String displayName = mod.getStatStringWithValueRanges().join("\n");
    return CraftingBenchOption(
        benchDisplayName: displayName,
        benchGroup: json['bench_group'],
        benchTier: json['bench_tier'],
        itemClasses: List<String>.from(json['item_classes']),
        mod: mod,
        costs: costs
    );
  }

  @override
  int compareTo(CraftingBenchOption other) {
    return other.benchTier - this.benchTier;
  }
}