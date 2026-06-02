class ShuffleEvent {
  final String shufflerUid;
  final String shufflerName;
  final String questionId;
  final String questionText;
  final String questionCategory;
  final String questionDepth;

  const ShuffleEvent({
    required this.shufflerUid,
    required this.shufflerName,
    required this.questionId,
    required this.questionText,
    required this.questionCategory,
    required this.questionDepth,
  });
}
