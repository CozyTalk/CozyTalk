class AdminBanRecord {
  final String reason;
  final String duration; // "1 Day" | "7 Days" | "30 Days" | "Permanent"
  final DateTime bannedAt;
  final DateTime? expiresAt;
  final String bannedByName;
  final String? note;
  final DateTime? unbannedAt;
  final String? unbannedBy;

  const AdminBanRecord({
    required this.reason,
    required this.duration,
    required this.bannedAt,
    this.expiresAt,
    required this.bannedByName,
    this.note,
    this.unbannedAt,
    this.unbannedBy,
  });
}
