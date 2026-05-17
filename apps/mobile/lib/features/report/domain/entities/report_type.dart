enum ReportType { spam, harassment, inappropriateContent, other }

extension ReportTypeX on ReportType {
  String get wireValue {
    switch (this) {
      case ReportType.spam:
        return 'spam';
      case ReportType.harassment:
        return 'harassment';
      case ReportType.inappropriateContent:
        return 'inappropriate_content';
      case ReportType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case ReportType.spam:
        return 'Spam';
      case ReportType.harassment:
        return 'Harassment';
      case ReportType.inappropriateContent:
        return 'Inappropriate Content';
      case ReportType.other:
        return 'Other';
    }
  }
}
