import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/shared_preferences_provider.dart';

final localTagStoreProvider = Provider<LocalTagStore>((ref) {
  return LocalTagStore(ref.watch(sharedPreferencesProvider));
});

class LocalTagStore {
  LocalTagStore(this._preferences);

  static const _tagsKey = 'nice_view.user_tags';
  static const _selectedTagKey = 'nice_view.selected_tag';
  static const _defaultTagsMigratedKey = 'nice_view.default_tags_migrated';
  static const defaultTags = ['原神', '樱岛麻衣'];

  final SharedPreferences _preferences;

  List<String> loadTags() {
    final tags = _preferences.getStringList(_tagsKey) ?? <String>[];
    if (_preferences.getBool(_defaultTagsMigratedKey) == true) {
      return tags;
    }

    final nextTags = [...tags];
    for (final tag in defaultTags) {
      if (!nextTags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
        nextTags.add(tag);
      }
    }
    _preferences.setStringList(_tagsKey, nextTags);
    _preferences.setBool(_defaultTagsMigratedKey, true);
    return nextTags;
  }

  Future<void> saveTags(List<String> tags) {
    return _preferences.setStringList(_tagsKey, tags);
  }

  String? loadSelectedTag() {
    final value = _preferences.getString(_selectedTagKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> saveSelectedTag(String? tag) async {
    if (tag == null || tag.trim().isEmpty) {
      await _preferences.remove(_selectedTagKey);
      return;
    }
    await _preferences.setString(_selectedTagKey, tag);
  }
}
