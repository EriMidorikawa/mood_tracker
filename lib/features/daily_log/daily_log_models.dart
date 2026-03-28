class DailyLogQuestion {
  const DailyLogQuestion({
    required this.id,
    required this.label,
    required this.lowLabel,
    required this.highLabel,
  });

  final String id;
  final String label;
  final String lowLabel;
  final String highLabel;
}

class DailyLogEntry {
  const DailyLogEntry({
    required this.loggedAt,
    required this.responses,
    required this.note,
  });

  final DateTime loggedAt;
  final Map<String, int> responses;
  final String note;
}

const dailyLogQuestions = <DailyLogQuestion>[
  DailyLogQuestion(
    id: 'mood',
    label: 'Mood',
    lowLabel: 'Very low',
    highLabel: 'Very good',
  ),
  DailyLogQuestion(
    id: 'motivation',
    label: 'Motivation',
    lowLabel: 'Very low',
    highLabel: 'Very high',
  ),
  DailyLogQuestion(
    id: 'fatigue',
    label: 'Fatigue',
    lowLabel: 'Not tired',
    highLabel: 'Exhausted',
  ),
  DailyLogQuestion(
    id: 'hunger',
    label: 'Hunger',
    lowLabel: 'Not hungry',
    highLabel: 'Very hungry',
  ),
  DailyLogQuestion(
    id: 'craving',
    label: 'Craving',
    lowLabel: 'None',
    highLabel: 'Very strong',
  ),
  DailyLogQuestion(
    id: 'post_meal_satisfaction',
    label: 'Post-meal satisfaction',
    lowLabel: 'Not satisfied',
    highLabel: 'Very satisfied',
  ),
  DailyLogQuestion(
    id: 'sweet_craving',
    label: 'Sweet craving',
    lowLabel: 'None',
    highLabel: 'Very strong',
  ),
  DailyLogQuestion(
    id: 'overeating_feeling',
    label: 'Overeating feeling',
    lowLabel: 'None',
    highLabel: 'Very strong',
  ),
];
