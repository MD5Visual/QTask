import 'package:q_task/domain/models/task.dart';
import 'package:q_task/domain/models/task_filter.dart';
import 'package:q_task/domain/repositories/i_repository.dart';

class TaskService implements ITaskService {
  @override
  List<Task> filterTasks(List<Task> tasks, TaskFilter filter) {
    return tasks.where((task) {
      // Filter by search query with fuzzy matching
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        final title = task.title.toLowerCase();
        final description = task.description.toLowerCase();

        // Check if search matches (exact or fuzzy)
        bool searchMatches = false;

        // First try exact substring match for better UX
        if (title.contains(query) || description.contains(query)) {
          searchMatches = true;
        } else {
          // Then try fuzzy matching
          if (_fuzzyMatch(query, title, filter.fuzzyTolerance) ||
              _fuzzyMatch(query, description, filter.fuzzyTolerance)) {
            searchMatches = true;
          }
        }

        // If search doesn't match, exclude this task
        if (!searchMatches) {
          return false;
        }
      }

      // Filter by completion status
      if (filter.isCompleted != null &&
          task.isCompleted != filter.isCompleted) {
        return false;
      }

      // Filter by tags
      if (filter.tags.isNotEmpty) {
        final hasAnyTag = filter.tags.any((tag) => task.tags.contains(tag));
        if (!hasAnyTag) {
          return false;
        }
      }

      // Filter by lists
      if (filter.listIds.isNotEmpty) {
        final inAnyList =
            filter.listIds.any((listId) => task.listIds.contains(listId));
        if (!inAnyList) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Fuzzy match a query against text with a maximum Levenshtein distance tolerance
  bool _fuzzyMatch(String query, String text, int tolerance) {
    // Split query into terms
    final queryTerms = query.split(RegExp(r'\s+'));

    // Split text into words
    final textWords = text.split(RegExp(r'\s+'));

    // Check if all query terms match at least one word in the text
    for (final term in queryTerms) {
      bool termMatched = false;

      for (final word in textWords) {
        final distance = _levenshtein(term, word);
        if (distance <= tolerance) {
          termMatched = true;
          break;
        }
      }

      if (!termMatched) {
        return false;
      }
    }

    return true;
  }

  /// Calculate Levenshtein distance between two strings
  int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    // Create a matrix to store distances
    List<List<int>> matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    // Fill matrix
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  @override
  List<Task> sortTasksByPosition(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }

  @override
  Task updateTaskPosition(Task task, int newPosition) {
    return task.copyWith(position: newPosition);
  }
}
