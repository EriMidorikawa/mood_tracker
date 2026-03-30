String formatShortDate(DateTime dateTime) {
  return '${_shortMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
}

String formatDateTimeLabel(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 == 0
      ? 12
      : hour24 > 12
          ? hour24 - 12
          : hour24;

  return '${formatShortDate(dateTime)} $hour12:$minute $period';
}

String _shortMonthName(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}
