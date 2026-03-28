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
