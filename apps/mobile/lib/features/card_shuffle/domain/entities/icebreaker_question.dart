class IcebreakerQuestion {
  final String id;
  final String text;
  final String category;
  final String depth;
  final List<String> tags;

  const IcebreakerQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.depth,
    required this.tags,
  });
}
