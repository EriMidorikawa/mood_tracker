import 'dart:convert';

class DailyLogEntry {
  const DailyLogEntry({
    required this.loggedAt,
    required this.responses,
    required this.note,
  });

  final DateTime loggedAt;
  final Map<String, int> responses;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      'loggedAt': loggedAt.toIso8601String(),
      'responses': responses,
      'note': note,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static DailyLogEntry fromJson(Map<String, dynamic> json) {
    final rawResponses = json['responses'] as Map<String, dynamic>;

    return DailyLogEntry(
      loggedAt: DateTime.parse(json['loggedAt'] as String),
      responses: {
        for (final entry in rawResponses.entries) entry.key: entry.value as int,
      },
      note: json['note'] as String? ?? '',
    );
  }

  static DailyLogEntry fromJsonString(String value) {
    return fromJson(jsonDecode(value) as Map<String, dynamic>);
  }
}
