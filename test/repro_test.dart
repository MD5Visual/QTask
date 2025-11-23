import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  const markdown = '';
  final delta =
      MarkdownToDelta(markdownDocument: md.Document()).convert(markdown);
  print('Delta for empty string: $delta');
  print('Delta length: ${delta.length}');

  try {
    final doc = Document.fromDelta(delta);
    print('Document created successfully: ${doc.toDelta()}');
  } catch (e) {
    print('Error creating document: $e');
  }
}
