import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'date': date,
    'changes': changes,
  };

  factory ChangelogEntry.fromJson(Map<String, dynamic> json) => ChangelogEntry(
    version: json['version'],
    date: json['date'],
    changes: List<String>.from(json['changes']),
  );
}

class ChangelogManager {
  static const String _storageKey = 'changelog_entries';

  static Future<List<ChangelogEntry>> getChangelogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList.map((json) => ChangelogEntry.fromJson(json)).toList();
  }

  static Future<void> saveChangelog(List<ChangelogEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = json.encode(
      entries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_storageKey, jsonStr);
  }

  static Future<void> addEntry(ChangelogEntry entry) async {
    final entries = await getChangelogs();
    entries.insert(0, entry); // Add new entry at the beginning
    await saveChangelog(entries);
  }
} 