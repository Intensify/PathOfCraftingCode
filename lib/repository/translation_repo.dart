import 'dart:async' show Future;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../crafting/stat_translation.dart';
import '../crafting/mod.dart' show Stat;

class TranslationRepository {
  TranslationRepository._privateConstructor();

  static final TranslationRepository instance = TranslationRepository._privateConstructor();

  Map<String, StatTranslation> _translations;

  Future<bool> initialize() async {
    _translations = Map();
    bool success = await loadStatTranslationJSONFromLocalStorage();
    print("Number of translations: ${_translations.length}");
    print("Translations: $_translations");
    return success;
  }

  Future<bool> loadStatTranslationJSONFromLocalStorage() async {
    var data = await rootBundle.loadString('data_repo/stat_translations.json');
    var jsonList = json.decode(data);
    jsonList.forEach((data) {
      List<String> ids = new List<String>.from(data['ids']);
      for (int i = 0; i < ids.length; i++) {
        StatTranslation statTranslation = StatTranslation.fromJson(i, ids, data["English"]);
        _translations[ids[i]] = statTranslation;
      }
    });
    return true;
  }

  List<String> getTranslationFromStats(List<Stat> stats) {
    //TODO: filter out stats "dummy_stat_display_nothing"
    List<StatTranslation> statTranslations = List();
    for (Stat stat in stats) {
      StatTranslation statTranslation = _translations[stat.id];
      if (statTranslation != null && !statTranslations.contains(statTranslation)) {
        statTranslations.add(statTranslation);
      }
    }

    return statTranslations.map((translation) => translation.getTranslationFromStats(stats)).toSet().toList();
  }

  List<String> getTranslationFromStatsWithValueRanges(List<Stat> stats) {
    List<StatTranslation> statTranslations = List();
    for (Stat stat in stats) {
      StatTranslation statTranslation = _translations[stat.id];
      if (statTranslation != null && !statTranslations.contains(statTranslation)) {
        statTranslations.add(statTranslation);
      }
    }

    return statTranslations.map((translation) => translation.getTranslationFromStatsWithValueRanges(stats)).toSet().toList();
  }
}