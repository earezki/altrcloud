bool isNumeric(String? str) {
  if (str == null) {
    return false;
  }
  return double.tryParse(str) != null;
}

bool isInt(String? str) {
  if (str == null) {
    return false;
  }
  return int.tryParse(str) != null;
}

DateTime getDateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String formatDateOnly(DateTime date) {
  return '${date.year}/${date.month}/${date.day}';
}

String formatTime(int totalSeconds) {
  int hours = totalSeconds ~/ 3600;
  int minutes = (totalSeconds % 3600) ~/ 60;
  int seconds = totalSeconds % 60;

  final time = [hours, minutes, seconds]
      .where((t) => t != 0)
      .map((t) => t.toString().padLeft(2, '0'))
      .join(':');
  return time.isEmpty ? '00' : time;

  String hoursStr = hours.toString().padLeft(2, '0');
  String minutesStr = minutes.toString().padLeft(2, '0');
  String secondsStr = seconds.toString().padLeft(2, '0');

  return '$hoursStr:$minutesStr:$secondsStr';
}
