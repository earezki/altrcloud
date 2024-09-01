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