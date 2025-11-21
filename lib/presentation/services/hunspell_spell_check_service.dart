import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

/// A [SpellCheckService] implementation backed by Hunspell-derived word lists
/// and the `spell_check_on_client` package.
class HunspellSpellCheckService implements SpellCheckService {
  const HunspellSpellCheckService();

  static const Map<String, _DictionaryConfig> _dictionaryConfigs =
      <String, _DictionaryConfig>{
    'en': _DictionaryConfig(
      wordListAsset: 'assets/dictionaries/en_words.txt',
      affixAsset: 'assets/dictionaries/hunspell/en_US.aff',
      dictionaryAsset: 'assets/dictionaries/hunspell/en_US.dic',
    ),
    'es': _DictionaryConfig(
      wordListAsset: 'assets/dictionaries/es_words.txt',
      affixAsset: 'assets/dictionaries/hunspell/es_ES.aff',
      dictionaryAsset: 'assets/dictionaries/hunspell/es_ES.dic',
    ),
  };

  static final Map<String, SpellCheck> _spellChecks = <String, SpellCheck>{};
  static final Map<String, Future<SpellCheck?>> _pendingLoads =
      <String, Future<SpellCheck?>>{};

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return const <SuggestionSpan>[];
    }

    final List<String> preferredLanguages = _preferredLanguages(locale);
    final Map<String, SpellCheck> activeSpellChecks =
        await _loadPreferredSpellChecks(preferredLanguages);
    if (activeSpellChecks.isEmpty) {
      return const <SuggestionSpan>[];
    }

    final SpellCheck primarySpellCheck =
        activeSpellChecks[preferredLanguages.firstWhere(
      activeSpellChecks.containsKey,
      orElse: () => activeSpellChecks.keys.first,
    )]!;

    final RegExp wordMatcher = RegExp(r"[A-Za-zÀ-ÿ']+", multiLine: true);
    final List<SuggestionSpan> misspellings = <SuggestionSpan>[];

    for (final RegExpMatch match in wordMatcher.allMatches(text)) {
      final String word = match.group(0)!;
      final String normalizedWord = word.toLowerCase();

      final bool spelledCorrectly = activeSpellChecks.values.any(
        (SpellCheck checker) => checker.isCorrect(normalizedWord),
      );
      if (spelledCorrectly) {
        continue;
      }

      List<String> suggestions =
          primarySpellCheck.didYouMeanAny(normalizedWord, maxWords: 5);
      if (suggestions.isEmpty) {
        for (final SpellCheck checker in activeSpellChecks.values) {
          suggestions = checker.didYouMeanAny(normalizedWord, maxWords: 5);
          if (suggestions.isNotEmpty) {
            break;
          }
        }
      }

      final List<String> formattedSuggestions =
          _applyOriginalCasing(word, suggestions);

      misspellings.add(
        SuggestionSpan(
          TextRange(start: match.start, end: match.end),
          formattedSuggestions,
        ),
      );
    }

    return misspellings;
  }

  Future<Map<String, SpellCheck>> _loadPreferredSpellChecks(
    List<String> languages,
  ) async {
    final Map<String, SpellCheck> checks = <String, SpellCheck>{};

    for (final String language in languages) {
      final SpellCheck? checker = await _spellCheckForLanguage(language);
      if (checker != null) {
        checks[language] = checker;
      }
    }

    return checks;
  }

  List<String> _preferredLanguages(Locale locale) {
    final List<String> preferred = <String>[];
    final String primary = _dictionaryConfigs.containsKey(locale.languageCode)
        ? locale.languageCode
        : 'en';
    if (_dictionaryConfigs.containsKey(primary)) {
      preferred.add(primary);
    }
    for (final String language in _dictionaryConfigs.keys) {
      if (!preferred.contains(language)) {
        preferred.add(language);
      }
    }
    return preferred;
  }

  Future<SpellCheck?> _spellCheckForLanguage(String languageCode) async {
    if (_spellChecks.containsKey(languageCode)) {
      return _spellChecks[languageCode];
    }

    final SpellCheck? loaded = await _pendingLoads.putIfAbsent(
      languageCode,
      () => _loadDictionary(languageCode),
    );

    if (loaded != null) {
      _spellChecks[languageCode] = loaded;
    }

    return loaded;
  }

  Future<SpellCheck?> _loadDictionary(String languageCode) async {
    final _DictionaryConfig? config = _dictionaryConfigs[languageCode];
    if (config == null) {
      return null;
    }

    try {
      final Set<String> words = <String>{};

      if (config.wordListAsset != null) {
        final String rawWordList =
            await rootBundle.loadString(config.wordListAsset!);
        words.addAll(_parseSimpleWordList(rawWordList));
      }

      words.addAll(
        await _expandHunspellDictionary(
          config.affixAsset,
          config.dictionaryAsset,
        ),
      );

      return SpellCheck.fromWordsList(
        words.toList(growable: false),
        letters: LanguageLetters.getLanguageForLanguage(languageCode),
        iterations: 2,
      );
    } on FlutterError {
      // Asset missing – fail gracefully without crashing text input.
      return null;
    }
  }

  Set<String> _parseSimpleWordList(String rawContent) {
    final List<String> lines = const LineSplitter().convert(rawContent);
    final Set<String> words = <String>{};

    for (final String line in lines) {
      final String cleaned = line.trim().toLowerCase();
      if (cleaned.isNotEmpty) {
        words.add(cleaned);
      }
    }

    return words;
  }

  Future<Set<String>> _expandHunspellDictionary(
    String affixAsset,
    String dictionaryAsset,
  ) async {
    final String affixContent = await rootBundle.loadString(affixAsset);
    final String dictionaryContent =
        await rootBundle.loadString(dictionaryAsset);
    final Map<String, _AffixGroup> affixGroups = _parseAffixFile(affixContent);

    final Set<String> expandedWords = <String>{};
    final List<String> lines = const LineSplitter().convert(dictionaryContent);

    bool firstLine = true;
    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      if (firstLine && int.tryParse(line) != null) {
        firstLine = false;
        continue;
      }
      firstLine = false;

      final List<String> parts = line.split('/');
      final String baseWord = parts.first;
      final String flags = parts.length > 1 ? parts[1] : '';

      expandedWords.add(baseWord.toLowerCase());

      for (final String flag in flags.split('')) {
        final _AffixGroup? suffixGroup = affixGroups['SFX_$flag'];
        if (suffixGroup != null) {
          for (final _AffixRule rule in suffixGroup.rules) {
            final String? inflected = rule.apply(baseWord);
            if (inflected != null && inflected.isNotEmpty) {
              expandedWords.add(inflected.toLowerCase());
            }
          }
        }

        final _AffixGroup? prefixGroup = affixGroups['PFX_$flag'];
        if (prefixGroup != null) {
          for (final _AffixRule rule in prefixGroup.rules) {
            final String? inflected = rule.apply(baseWord);
            if (inflected != null && inflected.isNotEmpty) {
              expandedWords.add(inflected.toLowerCase());
            }
          }
        }
      }
    }

    return expandedWords;
  }

  Map<String, _AffixGroup> _parseAffixFile(String content) {
    final Map<String, _AffixGroup> groups = <String, _AffixGroup>{};
    final List<String> lines = const LineSplitter().convert(content);

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final List<String> parts = line.split(RegExp(r'\s+'));
      if (parts.length < 4) {
        continue;
      }

      final String type = parts[0];
      final String flag = parts[1];

      if ((type == 'PFX' || type == 'SFX') && parts.length == 4) {
        groups['${type}_$flag'] = _AffixGroup(
          isPrefix: type == 'PFX',
        );
        continue;
      }

      if ((type == 'PFX' || type == 'SFX') && parts.length >= 5) {
        final _AffixGroup? group = groups['${type}_$flag'];
        if (group == null) {
          continue;
        }
        final String strip = parts[2] == '0' ? '' : parts[2];
        final String add = parts[3] == '0' ? '' : parts[3];
        final String conditionPattern =
            parts.length > 4 ? parts.sublist(4).join(' ') : '.';
        group.rules.add(
          _AffixRule(
            isPrefix: group.isPrefix,
            strip: strip,
            add: add,
            condition: _buildAffixCondition(conditionPattern, group.isPrefix),
          ),
        );
      }
    }

    return groups;
  }

  RegExp _buildAffixCondition(String pattern, bool isPrefix) {
    final String finalPattern =
        (pattern.isEmpty || pattern == '.') ? r'.*' : pattern;
    return isPrefix ? RegExp('^$finalPattern') : RegExp('$finalPattern\$');
  }
}

/// Shared spell-check configuration wired up to the custom Hunspell service.
final SpellCheckConfiguration hunspellSpellCheckConfiguration =
    SpellCheckConfiguration(
  spellCheckService: const HunspellSpellCheckService(),
  misspelledTextStyle: const TextStyle(
    decoration: TextDecoration.underline,
    decorationColor: Colors.redAccent,
    decorationStyle: TextDecorationStyle.wavy,
  ),
  spellCheckSuggestionsToolbarBuilder:
      (BuildContext context, EditableTextState state) {
    return SpellCheckSuggestionsToolbar.editableText(editableTextState: state);
  },
);

/// Builds a context menu that prepends spell check suggestions so desktop
/// right-click actions can quickly replace misspelled words.
Widget spellCheckContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  final List<ContextMenuButtonItem> defaultItems = editableTextState
      .contextMenuButtonItems
      .where((ContextMenuButtonItem item) =>
          item.type != ContextMenuButtonType.delete)
      .toList();

  final SuggestionSpan? suggestionSpan =
      _suggestionSpanForContextMenu(editableTextState);

  if (suggestionSpan == null || suggestionSpan.suggestions.isEmpty) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: defaultItems,
    );
  }

  final TextRange replacementRange = suggestionSpan.range;
  void replaceText(String replacement) {
    final TextEditingValue replaced =
        editableTextState.textEditingValue.replaced(
      replacementRange,
      replacement,
    );
    editableTextState.userUpdateTextEditingValue(
      replaced,
      SelectionChangedCause.toolbar,
    );
    editableTextState.hideToolbar();
  }

  final List<ContextMenuButtonItem> suggestionItems = suggestionSpan.suggestions
      .take(3)
      .map(
        (String suggestion) => ContextMenuButtonItem(
          label: suggestion,
          onPressed: () {
            if (!editableTextState.mounted) {
              return;
            }
            replaceText(suggestion);
          },
        ),
      )
      .toList();

  final List<Widget> suggestionButtons =
      AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, suggestionItems)
          .toList();
  final List<Widget> defaultButtons =
      AdaptiveTextSelectionToolbar.getAdaptiveButtons(context, defaultItems)
          .toList();

  final List<Widget> children = <Widget>[...suggestionButtons];
  if (defaultButtons.isNotEmpty) {
    children.add(const Divider(height: 1));
    children.addAll(defaultButtons);
  }

  return AdaptiveTextSelectionToolbar(
    anchors: editableTextState.contextMenuAnchors,
    children: children,
  );
}

int? _contextMenuWordIndex(EditableTextState editableTextState) {
  final Offset? tapPosition =
      editableTextState.renderEditable.lastSecondaryTapDownPosition;
  if (tapPosition == null) {
    return null;
  }
  return editableTextState.renderEditable
      .getPositionForPoint(tapPosition)
      .offset;
}

SuggestionSpan? _suggestionSpanForContextMenu(
    EditableTextState editableTextState) {
  final int? tapIndex = _contextMenuWordIndex(editableTextState);
  final int cursorIndex = tapIndex ??
      editableTextState.currentTextEditingValue.selection.extentOffset;
  return editableTextState.findSuggestionSpanAtCursorIndex(cursorIndex);
}

List<String> _applyOriginalCasing(String original, List<String> suggestions) {
  final Set<String> seen = <String>{};
  for (final String suggestion in suggestions) {
    final String adjusted = _matchCase(original, suggestion);
    if (adjusted.isNotEmpty) {
      seen.add(adjusted);
    }
  }
  return seen.toList(growable: false);
}

String _matchCase(String original, String suggestion) {
  if (original.isEmpty || suggestion.isEmpty) {
    return suggestion;
  }
  if (_isAllCaps(original)) {
    return suggestion.toUpperCase();
  }
  if (_isTitleCase(original)) {
    return suggestion[0].toUpperCase() + suggestion.substring(1).toLowerCase();
  }
  if (_isAllLower(original)) {
    return suggestion.toLowerCase();
  }
  return suggestion;
}

bool _isAllCaps(String value) => value == value.toUpperCase();

bool _isAllLower(String value) => value == value.toLowerCase();

bool _isTitleCase(String value) {
  if (value.length < 2) {
    return false;
  }
  final String first = value[0];
  final String rest = value.substring(1);
  return first == first.toUpperCase() && rest == rest.toLowerCase();
}

class _DictionaryConfig {
  const _DictionaryConfig({
    this.wordListAsset,
    required this.affixAsset,
    required this.dictionaryAsset,
  });

  final String? wordListAsset;
  final String affixAsset;
  final String dictionaryAsset;
}

class _AffixGroup {
  _AffixGroup({required this.isPrefix});

  final bool isPrefix;
  final List<_AffixRule> rules = <_AffixRule>[];
}

class _AffixRule {
  _AffixRule({
    required this.isPrefix,
    required this.strip,
    required this.add,
    required this.condition,
  });

  final bool isPrefix;
  final String strip;
  final String add;
  final RegExp condition;

  String? apply(String word) {
    if (word.isEmpty) {
      return null;
    }

    if (isPrefix) {
      if (strip.isNotEmpty) {
        if (!word.startsWith(strip) || word.length < strip.length) {
          return null;
        }
      }
      final String base = strip.isEmpty ? word : word.substring(strip.length);
      if (!condition.hasMatch(base)) {
        return null;
      }
      return '$add$base';
    } else {
      if (strip.isNotEmpty) {
        if (!word.endsWith(strip) || word.length < strip.length) {
          return null;
        }
      }
      final String base =
          strip.isEmpty ? word : word.substring(0, word.length - strip.length);
      if (!condition.hasMatch(base)) {
        return null;
      }
      return '$base$add';
    }
  }
}
