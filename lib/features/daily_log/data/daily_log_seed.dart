import 'package:mood_tracker/features/daily_log/models/daily_log_question.dart';

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
    id: 'sweet_craving',
    label: 'Sweet Craving',
    lowLabel: 'None',
    highLabel: 'Very strong',
  ),
];
