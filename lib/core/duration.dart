const maxSessionSeconds = 24 * 60 * 60;

int durationPartsToSeconds({
  required int hours,
  required int minutes,
  required int seconds,
}) {
  final safeHours = hours.clamp(0, 24).toInt();
  final safeMinutes = minutes.clamp(0, 59).toInt();
  final safeSeconds = seconds.clamp(0, 59).toInt();
  return (safeHours * 3600 + safeMinutes * 60 + safeSeconds)
      .clamp(0, maxSessionSeconds)
      .toInt();
}

bool isValidSessionDuration(int seconds) =>
    seconds >= 1 && seconds <= maxSessionSeconds;

String formatDuration(int seconds) {
  final normalized = seconds.clamp(0, maxSessionSeconds).toInt();
  final hours = normalized ~/ 3600;
  final minutes = (normalized % 3600) ~/ 60;
  final remainingSeconds = normalized % 60;
  final twoMinutes = minutes.toString().padLeft(2, '0');
  final twoSeconds = remainingSeconds.toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$twoMinutes:$twoSeconds'
      : '$twoMinutes:$twoSeconds';
}
