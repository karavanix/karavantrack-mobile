// Date/time and validation helpers.

String formatDateTime(DateTime? dt) {
  if (dt == null) return '-';
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String formatRelativeTime(DateTime nowUtc, DateTime thenUtc) {
  final d = nowUtc.difference(thenUtc);
  if (d.inSeconds < 60) return '${d.inSeconds}s ago';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

bool isValidPhone(String value) =>
    RegExp(r'^\+?[0-9]{9,15}$').hasMatch(value.trim());

bool isValidEmail(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
