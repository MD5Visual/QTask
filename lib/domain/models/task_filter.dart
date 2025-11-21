class TaskFilter {
  final List<String> tags;
  final bool? isCompleted;
  final List<String> listIds;
  final String? searchQuery;
  final int fuzzyTolerance;

  TaskFilter({
    this.tags = const [],
    this.isCompleted,
    this.listIds = const [],
    this.searchQuery,
    this.fuzzyTolerance = 2,
  });

  TaskFilter copyWith({
    List<String>? tags,
    bool? isCompleted,
    List<String>? listIds,
    String? searchQuery,
    bool clearIsCompleted = false,
    bool clearSearchQuery = false,
    int? fuzzyTolerance,
  }) {
    return TaskFilter(
      tags: tags ?? this.tags,
      isCompleted: clearIsCompleted ? null : (isCompleted ?? this.isCompleted),
      listIds: listIds ?? this.listIds,
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      fuzzyTolerance: fuzzyTolerance ?? this.fuzzyTolerance,
    );
  }

  bool isEmpty() {
    return tags.isEmpty &&
        isCompleted == null &&
        listIds.isEmpty &&
        (searchQuery == null || searchQuery!.isEmpty);
  }
}
