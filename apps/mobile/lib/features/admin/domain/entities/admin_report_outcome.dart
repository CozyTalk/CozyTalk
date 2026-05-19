class AdminReportOutcome {
  final String kind; // "banned" | "reviewed" | "dismissed"
  final String byName;
  final DateTime at;
  final String? note;

  const AdminReportOutcome({
    required this.kind,
    required this.byName,
    required this.at,
    this.note,
  });
}
