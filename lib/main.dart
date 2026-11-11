
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

import 'package:highlight/languages/dart.dart' as dart_lang;
import 'package:highlight/languages/python.dart' as python_lang;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/typescript.dart' as ts_lang;
import 'package:highlight/languages/java.dart' as java_lang;
import 'package:highlight/languages/kotlin.dart' as kotlin_lang;
import 'package:highlight/languages/swift.dart' as swift_lang;
import 'package:highlight/languages/cpp.dart' as cpp_lang;
import 'package:highlight/languages/css.dart' as css_lang;
import 'package:highlight/languages/xml.dart' as xml_lang;
import 'package:highlight/languages/json.dart' as json_lang;
import 'package:highlight/languages/sql.dart' as sql_lang;
import 'package:highlight/languages/bash.dart' as bash_lang;
import 'package:highlight/languages/go.dart' as go_lang;
import 'package:highlight/languages/rust.dart' as rust_lang;
import 'package:highlight/languages/php.dart' as php_lang;
import 'package:highlight/languages/yaml.dart' as yaml_lang;
import 'package:highlight/languages/markdown.dart' as markdown_lang;

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saf/saf.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import 'core/services/saf_file_service.dart';
import 'features/projects/new_project_wizard.dart';
import 'flutter_preview_screen.dart';
import 'html_preview_screen.dart';
import 'web_code_runner_screen.dart';
import 'core/services/language_engine_manager.dart';
import 'core/services/editor_editing_assist.dart';
import 'core/services/editor_line_actions.dart';
import 'core/services/editor_syntax_diagnostics.dart';
import 'core/services/editor_bracket_matcher.dart';
import 'core/services/editor_completion_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BishoIDE());
}

class BishoIDE extends StatelessWidget {
  const BishoIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bisho IDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
      ),
      home: const EditorScreen(),
    );
  }
}

class EditorTab {
  final String id;
  final CodeController controller;

  String fileName;
  String language;

  String? fileUri;
  String? parentUri;

  bool isSaved;
  int selectionBaseOffset;
  int selectionExtentOffset;

  EditorTab({
    required this.id,
    required this.controller,
    required this.fileName,
    required this.language,
    this.fileUri,
    this.parentUri,
    this.isSaved = true,
    this.selectionBaseOffset = 0,
    this.selectionExtentOffset = 0,
  });
}

/// يمثل عنصرًا داخل شجرة SAF.
class _SafTreeEntry {
  final String uri;
  final String name;
  final String relativePath;
  final String? parentUri;
  final bool isDir;

  const _SafTreeEntry({
    required this.uri,
    required this.name,
    required this.relativePath,
    required this.parentUri,
    required this.isDir,
  });
}

class _ProjectSearchResult {
  final SafDocumentFile file;
  final String parentUri;
  final String relativePath;
  final List<int> matchingLines;

  const _ProjectSearchResult({
    required this.file,
    required this.parentUri,
    required this.relativePath,
    required this.matchingLines,
  });
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  static const String _savedDirectoryUriKey =
      'bisho_selected_directory_uri';

  static const String _savedDirectoryNameKey =
      'bisho_selected_directory_name';

  final Saf saf = Saf();
  final SafFileService safFiles = SafFileService();

  final Map<String, dynamic> languages = {
    'Dart': dart_lang.dart,
    'Python': python_lang.python,
    'JavaScript': js_lang.javascript,
    'TypeScript': ts_lang.typescript,
    'Java': java_lang.java,
    'Kotlin': kotlin_lang.kotlin,
    'Swift': swift_lang.swift,
    'C': cpp_lang.cpp,
    'C++': cpp_lang.cpp,
    'CSS': css_lang.css,
    'HTML': xml_lang.xml,
    'XML': xml_lang.xml,
    'JSON': json_lang.json,
    'SQL': sql_lang.sql,
    'Bash': bash_lang.bash,
    'Go': go_lang.go,
    'Rust': rust_lang.rust,
    'PHP': php_lang.php,
    'Markdown': markdown_lang.markdown,
    'YAML': yaml_lang.yaml,
  };

  final Map<String, String> extensions = {
    'Dart': 'dart',
    'Python': 'py',
    'JavaScript': 'js',
    'TypeScript': 'ts',
    'Java': 'java',
    'Kotlin': 'kt',
    'Swift': 'swift',
    'C': 'c',
    'C++': 'cpp',
    'CSS': 'css',
    'HTML': 'html',
    'XML': 'xml',
    'JSON': 'json',
    'SQL': 'sql',
    'Bash': 'sh',
    'Go': 'go',
    'Rust': 'rs',
    'PHP': 'php',
    'Markdown': 'md',
    'YAML': 'yaml',
  };

  final List<EditorTab> tabs = [];

  int activeIndex = 0;
  int nextTabId = 1;
  int _explorerRevision = 0;

  String status = 'جاهز';

  String? projectUri;
  String projectName = 'لا يوجد مشروع';

  String? selectedDirectoryUri;
  String selectedDirectoryName = '';

  bool isRestoring = false;
  bool explorerVisible = true;
  bool _bottomPanelVisible = false;
  int _bottomPanelTab = 0;
  double _editorFontSize = 14;
  double _bottomPanelHeight = 154;
  final Map<String, List<String>> _undoHistory = {};
  final Map<String, List<String>> _redoHistory = {};
  final Set<String> _historyApplying = {};
  final Set<String> _autoPairApplying = {};
  Timer? _tabStateSaveTimer;
  bool _tabStateSaveInProgress = false;
  bool _tabStateSavePending = false;
  bool _isDisposing = false;

  static const String _fontSizePreferenceKey = 'bisho_editor_font_size';
  static const String _explorerVisiblePreferenceKey = 'bisho_explorer_visible';
  static const String _bottomPanelVisiblePreferenceKey = 'bisho_bottom_panel_visible';
  static const String _bottomPanelHeightPreferenceKey = 'bisho_bottom_panel_height';

  EditorTab get activeTab => tabs[activeIndex];

  String? get creationDirectoryUri {
    return selectedDirectoryUri ?? projectUri;
  }

  String get creationDirectoryName {
    if (selectedDirectoryUri == null) {
      return projectName;
    }

    return selectedDirectoryName;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restoreTabs();
  }

  String createId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${nextTabId++}';
  }

  EditorTab createTab({
    String fileName = 'untitled.dart',
    String language = 'Dart',
    String? code,
    String? fileUri,
    String? parentUri,
    bool isSaved = false,
    int selectionBaseOffset = 0,
    int selectionExtentOffset = 0,
  }) {
    final controller = CodeController(
      text: code ??
          '// Welcome to Bisho IDE\n\nvoid main() {\n  print("Hello World");\n}',
      language: languages[language] ?? languages['Dart'],
    );
    final safeBaseOffset = selectionBaseOffset
        .clamp(0, controller.text.length)
        .toInt();
    final safeExtentOffset = selectionExtentOffset
        .clamp(0, controller.text.length)
        .toInt();
    controller.selection = TextSelection(
      baseOffset: safeBaseOffset,
      extentOffset: safeExtentOffset,
    );

    final tab = EditorTab(
      id: createId(),
      controller: controller,
      fileName: fileName,
      language: language,
      fileUri: fileUri,
      parentUri: parentUri,
      isSaved: isSaved,
      selectionBaseOffset: safeBaseOffset,
      selectionExtentOffset: safeExtentOffset,
    );

    _undoHistory[tab.id] = <String>[controller.text];
    _redoHistory[tab.id] = <String>[];

    controller.addListener(() {
      if (_historyApplying.contains(tab.id)) return;

      // Auto-close a single newly typed opening delimiter. Multi-character
      // edits, paste operations, undo and redo are left untouched.
      if (!_autoPairApplying.contains(tab.id)) {
        final historyBeforeEdit =
            _undoHistory.putIfAbsent(tab.id, () => <String>[]);
        final previousText = historyBeforeEdit.isEmpty
            ? controller.text
            : historyBeforeEdit.last;
        _tryDeletePairedOpeningDelimiter(tab, previousText);
        _trySkipExistingClosingDelimiter(tab, previousText);
        _tryInsertClosingPair(tab, previousText);
        _tryAutoIndentNewline(tab, previousText);
      }

      final history = _undoHistory.putIfAbsent(tab.id, () => <String>[]);
      final textChanged = history.isEmpty || history.last != controller.text;
      final selection = controller.selection;
      final safeBaseOffset = selection.isValid
          ? selection.baseOffset.clamp(0, controller.text.length).toInt()
          : controller.text.length;
      final safeExtentOffset = selection.isValid
          ? selection.extentOffset.clamp(0, controller.text.length).toInt()
          : controller.text.length;
      final selectionChanged =
          tab.selectionBaseOffset != safeBaseOffset ||
          tab.selectionExtentOffset != safeExtentOffset;
      tab.selectionBaseOffset = safeBaseOffset;
      tab.selectionExtentOffset = safeExtentOffset;

      if (textChanged) {
        history.add(controller.text);
        if (history.length > 101) history.removeAt(0);
        _redoHistory.putIfAbsent(tab.id, () => <String>[]).clear();
      }
      if (!mounted || isRestoring) return;

      // Selection changes also notify the controller. Refresh the cursor
      // indicator without incorrectly marking an unchanged file as dirty.
      setState(() {
        if (textChanged) {
          tab.isSaved = false;
          status = 'تعديلات جديدة';
        }
      });
      if (textChanged || selectionChanged) _scheduleTabStateSave();
    });

    return tab;
  }

  void _trySkipExistingClosingDelimiter(
    EditorTab tab,
    String previousText,
  ) {
    final controller = tab.controller;
    final result = EditorEditingAssist.skipExistingClosingDelimiter(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryDeletePairedOpeningDelimiter(
    EditorTab tab,
    String previousText,
  ) {
    final controller = tab.controller;
    final result = EditorEditingAssist.deletePairedOpeningDelimiter(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryAutoIndentNewline(EditorTab tab, String previousText) {
    final controller = tab.controller;
    final result = EditorEditingAssist.autoIndentNewline(
      previousText: previousText,
      currentText: controller.text,
      cursorOffset: controller.selection.extentOffset,
    );
    if (result == null) return;

    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(offset: result.cursorOffset),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  void _tryInsertClosingPair(EditorTab tab, String previousText) {
    final controller = tab.controller;
    final currentText = controller.text;
    if (currentText.length != previousText.length + 1) return;

    final cursor = controller.selection.extentOffset;
    if (cursor <= 0 || cursor > currentText.length) return;

    final insertionOffset = cursor - 1;
    if (currentText.substring(0, insertionOffset) !=
            previousText.substring(0, insertionOffset) ||
        currentText.substring(cursor) !=
            previousText.substring(insertionOffset)) {
      return;
    }

    final opening = currentText[insertionOffset];
    const closingPairs = <String, String>{
      '(': ')',
      '[': ']',
      '{': '}',
      '\'': '\'',
      '"': '"',
      '`': '`',
    };
    final closing = closingPairs[opening];
    if (closing == null) return;

    // Do not auto-pair an escaped quote.
    if (opening == '\'' || opening == '"' || opening == '`') {
      var backslashes = 0;
      for (var i = insertionOffset - 1; i >= 0 && currentText[i] == '\\'; i--) {
        backslashes++;
      }
      if (backslashes.isOdd) return;
    }

    final updatedText = currentText.replaceRange(
      cursor,
      cursor,
      closing,
    );
    _autoPairApplying.add(tab.id);
    try {
      controller.value = TextEditingValue(
        text: updatedText,
        selection: TextSelection.collapsed(offset: cursor),
      );
    } finally {
      _autoPairApplying.remove(tab.id);
    }
  }

  Future<void> _saveEditorPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizePreferenceKey, _editorFontSize);
      await prefs.setBool(_explorerVisiblePreferenceKey, explorerVisible);
      await prefs.setBool(
        _bottomPanelVisiblePreferenceKey,
        _bottomPanelVisible,
      );
      await prefs.setDouble(
        _bottomPanelHeightPreferenceKey,
        _bottomPanelHeight,
      );
    } catch (_) {
      // Preferences are optional; editor actions must keep working if storage fails.
    }
  }

  Future<void> _saveSelectedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    if (selectedDirectoryUri == null ||
        selectedDirectoryUri!.isEmpty) {
      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);
      return;
    }

    await prefs.setString(
      _savedDirectoryUriKey,
      selectedDirectoryUri!,
    );

    await prefs.setString(
      _savedDirectoryNameKey,
      selectedDirectoryName,
    );
  }

  Future<void> _clearSavedDirectoryState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_savedDirectoryUriKey);
    await prefs.remove(_savedDirectoryNameKey);
  }

  Future<void> selectCreationDirectory(
    String directoryUri,
    String directoryName,
  ) async {
    if (projectUri == null) return;

    try {
      final directory = await safFiles.getItem(directoryUri);

      if (directory == null || !directory.isDir) {
        showMessage('هذا المجلد غير متاح');
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        showMessage('تعذر الوصول إلى جذر المشروع');
        return;
      }

      final tree = await collectSubtree(root);

      final isInsideProject = tree.any(
        (entry) =>
            entry.uri == directoryUri &&
            entry.isDir,
      );

      if (!isInsideProject) {
        showMessage('المجلد ليس داخل المشروع المفتوح');
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = directory.uri;
        selectedDirectoryName = directory.name.isNotEmpty
            ? directory.name
            : directoryName;
        status = 'مجلد العمل: $selectedDirectoryName';
      });

      await _saveSelectedDirectoryState();

      if (!mounted) return;

      showMessage(
        'تم حفظ "$selectedDirectoryName" كمجلد عمل',
      );
    } catch (e) {
      showMessage('تعذر تحديد مجلد العمل: $e');
    }
  }

  Future<void> resetCreationDirectory() async {
    if (projectUri == null) return;

    try {
      if (!mounted) return;

      setState(() {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';
        status = 'مجلد العمل: جذر المشروع';
      });

      await _clearSavedDirectoryState();

      if (!mounted) return;

      showMessage('تمت العودة إلى جذر المشروع');
    } catch (e) {
      showMessage('تعذر تغيير مجلد العمل: $e');
    }
  }

  void refreshExplorer() {
    if (!mounted) return;

    setState(() {
      _explorerRevision++;
      status = 'تم تحديث المستكشف';
    });
  }

  Future<void> _restoreSelectedDirectory(
    SharedPreferences prefs,
  ) async {
    selectedDirectoryUri = null;
    selectedDirectoryName = '';

    try {
      if (projectUri == null || projectUri!.isEmpty) {
        await _clearSavedDirectoryState();
        return;
      }

      final savedUri = prefs.getString(_savedDirectoryUriKey);

      if (savedUri == null || savedUri.isEmpty) {
        return;
      }

      final root = await safFiles.getItem(projectUri!);

      if (root == null || !root.isDir) {
        await _clearSavedDirectoryState();
        return;
      }

      final tree = await collectSubtree(root);

      _SafTreeEntry? matchingDirectory;

      for (final entry in tree) {
        if (entry.uri == savedUri && entry.isDir) {
          matchingDirectory = entry;
          break;
        }
      }

      if (matchingDirectory == null) {
        await _clearSavedDirectoryState();
        return;
      }

      selectedDirectoryUri = matchingDirectory.uri;
      selectedDirectoryName = matchingDirectory.name;

      await _saveSelectedDirectoryState();
    } catch (_) {
      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      try {
        await _clearSavedDirectoryState();
      } catch (_) {}
    }
  }

  Future<void> restoreTabs() async {
    isRestoring = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      _editorFontSize = (prefs.getDouble(_fontSizePreferenceKey) ?? 14.0)
          .clamp(10.0, 24.0)
          .toDouble();
      explorerVisible = prefs.getBool(_explorerVisiblePreferenceKey) ?? true;
      _bottomPanelVisible =
          prefs.getBool(_bottomPanelVisiblePreferenceKey) ?? false;
      _bottomPanelHeight = (prefs.getDouble(_bottomPanelHeightPreferenceKey) ?? 154.0)
          .clamp(110.0, 420.0)
          .toDouble();

      final savedTabs = prefs.getString('bisho_tabs');
      final savedIndex = prefs.getInt('bisho_active_index') ?? 0;

      final savedProjectUri =
          prefs.getString('bisho_project_uri');

      final savedProjectName =
          prefs.getString('bisho_project_name') ??
              'لا يوجد مشروع';

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';

      if (savedProjectUri != null &&
          savedProjectUri.isNotEmpty) {
        try {
          final permissions =
              await safFiles.getPersistedPermissions();

          final matchingPermission = permissions.where(
            (permission) =>
                permission.uri == savedProjectUri &&
                permission.read &&
                permission.write,
          );

          if (matchingPermission.isNotEmpty) {
            final root = await safFiles.getItem(savedProjectUri);

            if (root != null && root.isDir) {
              projectUri = savedProjectUri;
              projectName = savedProjectName;

              await _restoreSelectedDirectory(prefs);
            } else {
              await prefs.remove('bisho_project_uri');
              await prefs.remove('bisho_project_name');

              await _clearSavedDirectoryState();
            }
          } else {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          }
        } catch (_) {
          projectUri = null;
          projectName = 'لا يوجد مشروع';

          selectedDirectoryUri = null;
          selectedDirectoryName = '';

          try {
            await prefs.remove('bisho_project_uri');
            await prefs.remove('bisho_project_name');

            await _clearSavedDirectoryState();
          } catch (_) {}
        }
      } else {
        await _clearSavedDirectoryState();
      }

      if (savedTabs != null) {
        final List<dynamic> data = jsonDecode(savedTabs);

        for (final item in data) {
          final language =
              item['language'] as String? ?? 'Dart';

          final safeLanguage =
              languages.containsKey(language)
                  ? language
                  : 'Dart';

          tabs.add(
            createTab(
              fileName:
                  item['fileName'] as String? ?? 'untitled.dart',
              language: safeLanguage,
              code: item['code'] as String? ?? '',
              fileUri: item['fileUri'] as String?,
              parentUri: item['parentUri'] as String?,
              isSaved: true,
              selectionBaseOffset: item['selectionBaseOffset'] is int
                  ? item['selectionBaseOffset'] as int
                  : ((item['cursorOffset'] is int)
                      ? item['cursorOffset'] as int
                      : 0),
              selectionExtentOffset: item['selectionExtentOffset'] is int
                  ? item['selectionExtentOffset'] as int
                  : ((item['cursorOffset'] is int)
                      ? item['cursorOffset'] as int
                      : 0),
            ),
          );
        }
      } else {
        final oldCode = prefs.getString('bisho_code');

        final oldName =
            prefs.getString('bisho_filename') ?? 'main.dart';

        final oldLanguage =
            prefs.getString('bisho_language') ?? 'Dart';

        final safeLanguage =
            languages.containsKey(oldLanguage)
                ? oldLanguage
                : 'Dart';

        tabs.add(
          createTab(
            fileName: oldName,
            language: safeLanguage,
            code: oldCode,
            isSaved: true,
          ),
        );
      }

      if (tabs.isEmpty) {
        tabs.add(createTab());
      }

      activeIndex =
          savedIndex.clamp(0, tabs.length - 1).toInt();
    } catch (e) {
      for (final tab in tabs) {
        tab.controller.dispose();
      }

      tabs.clear();
      tabs.add(createTab());

      activeIndex = 0;

      projectUri = null;
      projectName = 'لا يوجد مشروع';

      selectedDirectoryUri = null;
      selectedDirectoryName = '';
    }

    isRestoring = false;

    if (mounted) {
      setState(() {
        status = projectUri != null
            ? 'تم استعادة المشروع والملفات'
            : 'تم استعادة الملفات - افتح مجلد المشروع';
      });
    }
  }

  void _scheduleTabStateSave() {
    _tabStateSaveTimer?.cancel();
    _tabStateSaveTimer = Timer(const Duration(milliseconds: 650), () {
      saveTabStateSilently();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _tabStateSaveTimer?.cancel();
      saveTabStateSilently();
    }
  }

  Future<void> saveTabStateSilently() async {
    if (_tabStateSaveInProgress) {
      _tabStateSavePending = true;
      return;
    }
    _tabStateSaveInProgress = true;
    // Snapshot synchronously so controller disposal cannot invalidate a pending save.
    final data = tabs.map((tab) {
      return {
        'fileName': tab.fileName,
        'language': tab.language,
        'code': tab.controller.text,
        'fileUri': tab.fileUri,
        'parentUri': tab.parentUri,
        'selectionBaseOffset': tab.selectionBaseOffset
            .clamp(0, tab.controller.text.length)
            .toInt(),
        'selectionExtentOffset': tab.selectionExtentOffset
            .clamp(0, tab.controller.text.length)
            .toInt(),
      };
    }).toList();
    final savedIndex = activeIndex;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bisho_tabs', jsonEncode(data));
      await prefs.setInt('bisho_active_index', savedIndex);
    } catch (_) {
      // Local recovery is best-effort and must never interrupt editing.
    } finally {
      _tabStateSaveInProgress = false;
      if (_tabStateSavePending) {
        _tabStateSavePending = false;
        if (!_isDisposing) _scheduleTabStateSave();
      }
    }
  }

  String _mimeType(String name) {
    final ext =
        name.contains('.') ? name.split('.').last.toLowerCase() : '';

    const types = {
      'dart': 'text/plain',
      'py': 'text/x-python',
      'js': 'text/javascript',
      'ts': 'text/typescript',
      'html': 'text/html',
      'htm': 'text/html',
      'css': 'text/css',
      'json': 'application/json',
      'xml': 'application/xml',
      'java': 'text/x-java-source',
      'kt': 'text/plain',
      'php': 'text/plain',
      'sql': 'text/plain',
      'sh': 'text/plain',
      'txt': 'text/plain',
    };

    return types[ext] ?? 'application/octet-stream';
  }

  Future<bool> saveTabToSAF(EditorTab tab) async {
    if (tab.parentUri == null || tab.parentUri!.isEmpty) {
      return false;
    }

    final bytes = Uint8List.fromList(
      utf8.encode(tab.controller.text),
    );

    final document = await safFiles.saveFile(
      parentUri: tab.parentUri!,
      fileName: tab.fileName,
      mimeType: _mimeType(tab.fileName),
      bytes: bytes,
      overwrite: true,
    );

    tab.fileUri = document.uri;
    tab.isSaved = true;

    return true;
  }

  Future<void> saveAllTabs() async {
    try {
      int savedCount = 0;
      int skippedCount = 0;

      for (final tab in tabs) {
        if (tab.parentUri == null) {
          skippedCount++;
          continue;
        }

        await saveTabToSAF(tab);
        savedCount++;
      }

      await saveTabStateSilently();

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ $savedCount ملف';
      });

      if (skippedCount > 0) {
        showMessage(
          'تم حفظ $savedCount ملف. '
          '$skippedCount ملف يحتاج إلى تصدير منفصل.',
        );
      } else {
        showMessage('تم حفظ جميع الملفات');
      }
    } catch (e) {
      showMessage('تعذر حفظ بعض الملفات: $e');
    }
  }

  void createNewTab() {
    setState(() {
      tabs.add(createTab());
      activeIndex = tabs.length - 1;
      status = 'تم إنشاء ملف جديد';
    });

    saveTabStateSilently();
  }

  void selectTab(int index) {
    if (index < 0 || index >= tabs.length) return;

    setState(() {
      activeIndex = index;
      status = 'تم فتح ${activeTab.fileName}';
    });
    saveTabStateSilently();
  }

  Future<void> closeTab(int index) async {
    if (index < 0 || index >= tabs.length) return;

    final tab = tabs[index];

    if (!tab.isSaved) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('إغلاق الملف؟'),
          content: Text(
            'الملف ${tab.fileName} يحتوي على تعديلات غير محفوظة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق بدون حفظ'),
            ),
          ],
        ),
      );

      if (result != true || !mounted) return;
    }

    setState(() {
      tab.controller.dispose();
      tabs.removeAt(index);

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else if (activeIndex > index) {
        activeIndex--;
      } else if (activeIndex >= tabs.length) {
        activeIndex = tabs.length - 1;
      }
    });

    await saveTabStateSilently();
  }

  String detectLanguage(String extension) {
    const map = {
      'dart': 'Dart',
      'py': 'Python',
      'js': 'JavaScript',
      'mjs': 'JavaScript',
      'cjs': 'JavaScript',
      'ts': 'TypeScript',
      'tsx': 'TypeScript',
      'java': 'Java',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'c': 'C',
      'h': 'C',
      'cpp': 'C++',
      'cc': 'C++',
      'css': 'CSS',
      'html': 'HTML',
      'htm': 'HTML',
      'xml': 'XML',
      'json': 'JSON',
      'sql': 'SQL',
      'sh': 'Bash',
      'go': 'Go',
      'rs': 'Rust',
      'php': 'PHP',
      'md': 'Markdown',
      'markdown': 'Markdown',
      'yaml': 'YAML',
      'yml': 'YAML',
    };

    return map[extension.toLowerCase()] ?? 'Dart';
  }

  Future<void> openFile() async {
    try {
      final file = await saf.pickFile(
        persistablePermission: true,
      );

      if (file == null) return;

      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: null,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح الملف';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر فتح الملف: $e');
    }
  }

  Future<void> openProjectFolder() async {
    try {
      final directory = await safFiles.pickProjectFolder();

      if (directory == null) return;

      if (projectUri == directory.uri) {
        refreshExplorer();
        showMessage('هذا المشروع مفتوح بالفعل');
        return;
      }

      final projectTabs = tabs
          .where((tab) =>
              tab.parentUri != null && tab.parentUri!.isNotEmpty)
          .toList();

      final unsavedCount =
          projectTabs.where((tab) => !tab.isSaved).length;

      if (projectUri != null && projectTabs.isNotEmpty) {
        final message = unsavedCount > 0
            ? 'يوجد $unsavedCount ملف غير محفوظ في المشروع الحالي.\n\n'
                'ستبقى التبويبات القديمة مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.'
            : 'ستبقى تبويبات المشروع الحالي مفتوحة ومرتبطة بمجلداتها الأصلية. '
                'لن يتم نقلها إلى المشروع الجديد.';

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تغيير المشروع؟'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('متابعة'),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) return;
      }

      await saveTabStateSilently();

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('bisho_project_uri', directory.uri);
      await prefs.setString('bisho_project_name', directory.name);

      await prefs.remove(_savedDirectoryUriKey);
      await prefs.remove(_savedDirectoryNameKey);

      if (!mounted) return;

      setState(() {
        projectUri = directory.uri;
        projectName = directory.name;

        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        explorerVisible = true;
        _explorerRevision++;
        status = 'تم فتح المشروع عبر SAF';
      });

      showMessage('تم فتح مجلد المشروع');
    } catch (e) {
      showMessage('تعذر فتح المجلد: $e');
    }
  }

  /// إنشاء مشروع جديد باستخدام معالج المشاريع وSAF.
  Future<void> createNewProject() async {
    bool firstDirectory = true;

    try {
      await NewProjectWizard.show(
        context,
        pickLocation: () async {
          final folder = await safFiles.pickProjectFolder();

          if (folder == null) return null;

          return ProjectSaveLocation(
            uri: folder.uri,
            name: folder.name,
          );
        },
        createDirectory: (parentUri, directoryName) async {
          final existing = await safFiles.findChild(
            parentUri: parentUri,
            name: directoryName,
          );

          if (firstDirectory) {
            firstDirectory = false;

            if (existing != null) {
              throw Exception(
                'يوجد عنصر بالاسم "$directoryName" '
                'في مجلد الحفظ. اختر اسمًا آخر أو مجلدًا مختلفًا.',
              );
            }
          } else {
            if (existing != null) {
              if (existing.isDir) {
                return existing.uri;
              }

              throw Exception(
                'يوجد ملف بالاسم "$directoryName" '
                'ولا يمكن استخدامه كمجلد.',
              );
            }
          }

          final folder = await safFiles.createFolder(
            parentUri: parentUri,
            folderName: directoryName,
          );

          return folder.uri;
        },
        writeFile: (
          parentUri,
          fileName,
          mimeType,
          bytes,
        ) async {
          await safFiles.saveFile(
            parentUri: parentUri,
            fileName: fileName,
            mimeType: mimeType,
            bytes: Uint8List.fromList(bytes),
            overwrite: false,
          );
        },
        onCreated: (project) async {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(
            'bisho_project_uri',
            project.rootUri,
          );

          await prefs.setString(
            'bisho_project_name',
            project.name,
          );

          await prefs.remove(_savedDirectoryUriKey);
          await prefs.remove(_savedDirectoryNameKey);

          if (!mounted) return;

          setState(() {
            projectUri = project.rootUri;
            projectName = project.name;

            selectedDirectoryUri = null;
            selectedDirectoryName = '';

            explorerVisible = true;
            _explorerRevision++;

            status = 'تم إنشاء المشروع ${project.name}';
          });

          // البحث عن ملف البداية داخل المشروع.
          try {
            final segments = project.entryFile
                .split('/')
                .where((segment) => segment.isNotEmpty)
                .toList();

            var currentUri = project.rootUri;
            SafDocumentFile? entryFile;
            var entryParentUri = currentUri;

            for (var i = 0; i < segments.length; i++) {
              final found = await safFiles.findChild(
                parentUri: currentUri,
                name: segments[i],
              );

              if (found == null) {
                break;
              }

              if (i == segments.length - 1) {
                if (!found.isDir) {
                  entryFile = found;
                  entryParentUri = currentUri;
                }
              } else {
                if (!found.isDir) {
                  break;
                }

                currentUri = found.uri;
              }
            }

            if (!mounted) return;

            if (entryFile != null) {
              await openProjectFile(
                entryFile,
                entryParentUri,
              );
            } else {
              showMessage(
                'تم إنشاء المشروع، لكن تعذر العثور على ملف البداية.',
              );
            }
          } catch (e) {
            showMessage(
              'تم إنشاء المشروع، لكن تعذر فتح ملف البداية: $e',
            );
          }

          await saveTabStateSilently();

          if (!mounted) return;

          if (project.isFlutterSourceOnly) {
            showMessage(
              'تم إنشاء ملفات مصدر Flutter. '
              'يلزم Flutter SDK لإنشاء ملفات البناء الأصلية.',
            );
          } else {
            showMessage(
              'تم إنشاء المشروع وفتح ملف البداية بنجاح',
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;

      showMessage('تعذر إنشاء المشروع: $e');
    }
  }

  Future<void> openProjectFile(
    SafDocumentFile file,
    String parentUri,
  ) async {
    try {
      final bytes = await safFiles.readFile(file.uri);
      final content = utf8.decode(bytes, allowMalformed: true);

      final extension =
          file.name.contains('.') ? file.name.split('.').last : '';

      final language = detectLanguage(extension);

      final existingIndex = tabs.indexWhere(
        (tab) => tab.fileUri == file.uri,
      );

      if (existingIndex != -1) {
        selectTab(existingIndex);
        return;
      }

      setState(() {
        tabs.add(
          createTab(
            fileName: file.name,
            language: language,
            code: content,
            fileUri: file.uri,
            parentUri: parentUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        status = 'تم فتح ${file.name}';
      });

      await saveTabStateSilently();
    } catch (e) {
      showMessage('تعذر قراءة الملف: $e');
    }
  }

  Future<void> createProjectFile() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء ملف داخل $targetName',
      'مثال: main.dart',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final fileName = name.trim();

    if (fileName.contains('/') || fileName.contains('\\')) {
      showMessage('اكتب اسم ملف فقط');
      return;
    }

    try {
      final document = await safFiles.saveFile(
        parentUri: targetUri,
        fileName: fileName,
        mimeType: _mimeType(fileName),
        bytes: Uint8List(0),
        overwrite: false,
      );

      final language = detectLanguage(
        fileName.contains('.') ? fileName.split('.').last : '',
      );

      if (!mounted) return;

      setState(() {
        tabs.add(
          createTab(
            fileName: fileName,
            language: language,
            code: '',
            fileUri: document.uri,
            parentUri: targetUri,
            isSaved: true,
          ),
        );

        activeIndex = tabs.length - 1;
        _explorerRevision++;
        status = 'تم إنشاء الملف داخل $targetName';
      });

      await saveTabStateSilently();
      showMessage('تم إنشاء الملف داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء الملف: $e');
    }
  }

  Future<void> createProjectFolder() async {
    final targetUri = creationDirectoryUri;

    if (targetUri == null || targetUri.isEmpty) {
      showMessage('افتح مجلد مشروع أولاً');
      return;
    }

    final targetName = creationDirectoryName;

    final name = await askName(
      'إنشاء مجلد داخل $targetName',
      'اسم المجلد',
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final folderName = name.trim();

    if (folderName.contains('/') || folderName.contains('\\')) {
      showMessage('اكتب اسم مجلد فقط');
      return;
    }

    try {
      await safFiles.createFolder(
        parentUri: targetUri,
        folderName: folderName,
      );

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم إنشاء المجلد داخل $targetName';
      });

      showMessage('تم إنشاء المجلد داخل $targetName');
    } catch (e) {
      showMessage('تعذر إنشاء المجلد: $e');
    }
  }

  Future<String?> askName(String title, String hint) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('موافق'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<List<_SafTreeEntry>> collectSubtree(
    SafDocumentFile root,
  ) async {
    final result = <_SafTreeEntry>[];
    final visited = <String>{};

    Future<void> visit(
      SafDocumentFile item, {
      required String relativePath,
      required String? parentUri,
    }) async {
      if (!visited.add(item.uri)) return;

      result.add(
        _SafTreeEntry(
          uri: item.uri,
          name: item.name,
          relativePath: relativePath,
          parentUri: parentUri,
          isDir: item.isDir,
        ),
      );

      if (!item.isDir) return;

      final children = await safFiles.listDirectory(item.uri);

      for (final child in children) {
        final childPath = relativePath.isEmpty
            ? child.name
            : '$relativePath/${child.name}';

        await visit(
          child,
          relativePath: childPath,
          parentUri: item.uri,
        );
      }
    }

    await visit(
      root,
      relativePath: '',
      parentUri: null,
    );

    return result;
  }

  Future<void> renameEntity(SafDocumentFile entity) async {
    final name = await askName('إعادة تسمية', entity.name);

    if (name == null || name.trim().isEmpty || !mounted) return;

    final newName = name.trim();

    if (newName.contains('/') || newName.contains('\\')) {
      showMessage('اكتب اسمًا فقط');
      return;
    }

    if (newName == entity.name) return;

    try {
      final oldTree = await collectSubtree(entity);

      final renamed = await safFiles.renameItem(
        uri: entity.uri,
        newName: newName,
      );

      if (entity.isDir) {
        final newTree = await collectSubtree(renamed);

        final oldByUri = <String, _SafTreeEntry>{
          for (final item in oldTree) item.uri: item,
        };

        final newByPath = <String, _SafTreeEntry>{
          for (final item in newTree) item.relativePath: item,
        };

        if (selectedDirectoryUri != null) {
          final selectedEntry = oldByUri[selectedDirectoryUri];

          if (selectedEntry != null) {
            final newSelectedEntry =
                newByPath[selectedEntry.relativePath];

            if (newSelectedEntry != null) {
              selectedDirectoryUri = newSelectedEntry.uri;
              selectedDirectoryName = newSelectedEntry.name;
            }
          }
        }

        for (final tab in tabs) {
          final oldFileEntry = tab.fileUri == null
              ? null
              : oldByUri[tab.fileUri];

          if (oldFileEntry != null) {
            final newFileEntry =
                newByPath[oldFileEntry.relativePath];

            if (newFileEntry != null) {
              tab.fileUri = newFileEntry.uri;
              tab.fileName = newFileEntry.name;
            }
          }

          if (tab.parentUri != null) {
            final oldParentEntry = oldByUri[tab.parentUri];

            if (oldParentEntry != null) {
              final newParentEntry =
                  newByPath[oldParentEntry.relativePath];

              if (newParentEntry != null) {
                tab.parentUri = newParentEntry.uri;
              }
            }
          }
        }
      } else {
        for (final tab in tabs) {
          if (tab.fileUri == entity.uri) {
            tab.fileUri = renamed.uri;
            tab.fileName = renamed.name;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = 'تم تغيير الاسم';
      });

      await _saveSelectedDirectoryState();
      await saveTabStateSilently();

      if (!mounted) return;

      showMessage('تم تغيير الاسم وتحديث البيانات المحفوظة');
    } catch (e) {
      refreshExplorer();
      showMessage('تعذرت إعادة التسمية أو تحديث التبويبات: $e');
    }
  }

  Future<void> deleteEntity(SafDocumentFile entity) async {
    try {
      final subtree = await collectSubtree(entity);

      final deletedUris = subtree.map((item) => item.uri).toSet();

      final affectedTabs = tabs.where((tab) {
        final fileIsInside = tab.fileUri != null &&
            deletedUris.contains(tab.fileUri);

        final parentIsInside = tab.parentUri != null &&
            deletedUris.contains(tab.parentUri);

        return fileIsInside || parentIsInside;
      }).toList();

      final unsavedCount =
          affectedTabs.where((tab) => !tab.isSaved).length;

      final message = unsavedCount > 0
          ? 'هل تريد حذف ${entity.name}؟\n\n'
              'يوجد $unsavedCount ملف مفتوح يحتوي على تعديلات غير محفوظة. '
              'سيتم إغلاق التبويبات التابعة لهذا العنصر وفقدان تعديلاتها.'
          : 'هل تريد حذف ${entity.name}؟';

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      final activeId =
          tabs.isNotEmpty ? activeTab.id : null;
      final oldActiveIndex = activeIndex;

      await safFiles.deleteItem(entity.uri);

      final selectedDirectoryWasDeleted =
          selectedDirectoryUri != null &&
          deletedUris.contains(selectedDirectoryUri);

      if (selectedDirectoryWasDeleted) {
        selectedDirectoryUri = null;
        selectedDirectoryName = '';

        await _clearSavedDirectoryState();
      }

      for (final tab in affectedTabs) {
        tab.controller.dispose();
      }

      tabs.removeWhere((tab) => affectedTabs.contains(tab));

      if (tabs.isEmpty) {
        tabs.add(createTab());
        activeIndex = 0;
      } else {
        final preservedIndex = activeId == null
            ? -1
            : tabs.indexWhere((tab) => tab.id == activeId);

        if (preservedIndex != -1) {
          activeIndex = preservedIndex;
        } else {
          activeIndex = oldActiveIndex
              .clamp(0, tabs.length - 1)
              .toInt();
        }
      }

      if (!mounted) return;

      setState(() {
        _explorerRevision++;
        status = selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم حذف العنصر';
      });

      await saveTabStateSilently();

      if (!mounted) return;

      showMessage(
        selectedDirectoryWasDeleted
            ? 'تم الحذف والعودة إلى جذر المشروع'
            : 'تم الحذف وإغلاق التبويبات التابعة',
      );
    } catch (e) {
      refreshExplorer();
      showMessage('تعذر حذف العنصر: $e');
    }
  }

  Future<void> saveCurrentToDisk() async {
    final tab = activeTab;

    if (tab.parentUri == null) {
      showMessage('هذا الملف مستقل. استخدم تصدير لحفظ التعديلات.');
      return;
    }

    try {
      await saveTabToSAF(tab);

      if (!mounted) return;

      setState(() {
        status = 'تم حفظ ${tab.fileName}';
      });

      await saveTabStateSilently();
      showMessage('تم حفظ الملف');
    } catch (e) {
      showMessage('تعذر حفظ الملف: $e');
    }
  }

  Future<void> exportFile() async {
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(activeTab.controller.text),
      );

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'تصدير الملف',
        fileName: activeTab.fileName,
        bytes: bytes,
      );

      if (path != null && mounted) {
        setState(() {
          activeTab.isSaved = true;
          status = 'تم التصدير';
        });

        await saveTabStateSilently();
        showMessage('تم تصدير الملف');
      }
    } catch (e) {
      showMessage('تعذر تصدير الملف: $e');
    }
  }

  void changeLanguage(String? language) {
    if (language == null) return;

    setState(() {
      activeTab.language = language;
      activeTab.controller.language = languages[language];

      final parts = activeTab.fileName.split('.');
      final baseName = parts.length > 1
          ? parts.sublist(0, parts.length - 1).join('.')
          : activeTab.fileName;

      activeTab.fileName =
          '$baseName.${extensions[language] ?? 'txt'}';

      activeTab.isSaved = false;
      status = 'تم تغيير اللغة';
    });

    saveTabStateSilently();
  }

  Future<void> searchCode() async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    var replaceMode = false;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('البحث والاستبدال'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'بحث عن',
                  hintText: 'اكتب النص المطلوب',
                ),
              ),
              if (replaceMode)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: replaceController,
                    decoration: const InputDecoration(
                      labelText: 'استبدال بـ',
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setDialogState(
                    () => replaceMode = !replaceMode,
                  ),
                  icon: Icon(replaceMode ? Icons.search : Icons.find_replace),
                  label: Text(
                    replaceMode ? 'إخفاء الاستبدال' : 'إظهار الاستبدال',
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, {
                    'find': findController.text,
                    'mode': 'project',
                  }),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('البحث في جميع ملفات المشروع'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'find': findController.text,
                'replace': replaceController.text,
                'mode': replaceMode ? 'replace' : 'find',
              }),
              child: Text(replaceMode ? 'استبدال الكل' : 'بحث'),
            ),
          ],
        ),
      ),
    );

    findController.dispose();
    replaceController.dispose();

    if (result == null) return;
    final query = result['find'] ?? '';
    if (query.isEmpty) return;

    if (result['mode'] == 'project') {
      await searchProjectFiles(query);
      return;
    }

    final source = activeTab.controller.text;
    if (result['mode'] == 'replace') {
      final replacement = result['replace'] ?? '';
      final matches = query.allMatches(source).length;
      if (matches == 0) {
        showMessage('لم يتم العثور على النص');
        return;
      }
      activeTab.controller.text = source.replaceAll(query, replacement);
      activeTab.controller.selection = TextSelection.collapsed(
        offset: activeTab.controller.text.length,
      );
      showMessage('تم استبدال $matches تطابق');
      return;
    }

    final currentSelection = activeTab.controller.selection;
    final searchFrom = currentSelection.isValid
        ? currentSelection.extentOffset.clamp(0, source.length).toInt()
        : 0;
    var start = source.indexOf(query, searchFrom);
    if (start == -1 && searchFrom > 0) {
      start = source.indexOf(query);
    }
    if (start == -1) {
      showMessage('لم يتم العثور على النص');
      return;
    }
    activeTab.controller.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + query.length,
    );
    showMessage('تم العثور على النص');
  }

  Future<void> searchProjectFiles(String query) async {
    final rootUri = projectUri;
    if (rootUri == null || rootUri.isEmpty) {
      showMessage('افتح مجلد المشروع أولاً للبحث داخله');
      return;
    }

    final searchableExtensions = <String>{
      'dart', 'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'html', 'htm',
      'css', 'scss', 'sass', 'json', 'xml', 'yaml', 'yml', 'md', 'markdown',
      'txt', 'java', 'kt', 'kts', 'swift', 'c', 'h', 'cpp', 'hpp', 'sql',
      'sh', 'bash', 'go', 'rs', 'php', 'toml', 'ini', 'gradle', 'properties',
    };
    final results = <_ProjectSearchResult>[];
    var visitedFiles = 0;
    var skippedFiles = 0;
    const maxFiles = 500;
    const maxFileBytes = 1024 * 1024;
    final needle = query.toLowerCase();

    Future<void> scanDirectory(
      String directoryUri,
      String relativeDirectory,
    ) async {
      if (visitedFiles >= maxFiles || results.length >= 200) return;
      List<SafDocumentFile> items;
      try {
        items = await safFiles.listDirectory(directoryUri);
      } catch (_) {
        skippedFiles++;
        return;
      }

      for (final item in items) {
        if (visitedFiles >= maxFiles || results.length >= 200) break;
        final relativePath = relativeDirectory.isEmpty
            ? item.name
            : '$relativeDirectory/${item.name}';
        if (item.isDir) {
          await scanDirectory(item.uri, relativePath);
          continue;
        }

        final dot = item.name.lastIndexOf('.');
        final extension = dot < 0
            ? ''
            : item.name.substring(dot + 1).toLowerCase();
        if (!searchableExtensions.contains(extension)) continue;

        visitedFiles++;
        try {
          final bytes = await safFiles.readFile(item.uri);
          if (bytes.length > maxFileBytes) {
            skippedFiles++;
            continue;
          }
          final content = utf8.decode(bytes, allowMalformed: true);
          final lines = content.split('\n');
          final matchingLines = <int>[];
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains(needle)) {
              matchingLines.add(i + 1);
              if (matchingLines.length >= 20) break;
            }
          }
          if (matchingLines.isNotEmpty) {
            results.add(_ProjectSearchResult(
              file: item,
              parentUri: directoryUri,
              relativePath: relativePath,
              matchingLines: matchingLines,
            ));
          }
        } catch (_) {
          skippedFiles++;
        }
      }
    }

    showMessage('جارٍ البحث داخل ملفات المشروع...');
    await scanDirectory(rootUri, '');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('نتائج البحث: ${results.length}'),
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(dialogContext).size.height * 0.55,
          child: results.isEmpty
              ? const Center(child: Text('لم يتم العثور على تطابقات'))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final lineSummary =
                        result.matchingLines.take(5).join(', ');
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        result.file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${result.relativePath}\n'
                        'الأسطر: $lineSummary'
                        '${result.matchingLines.length > 5 ? ' ...' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        await openProjectFile(result.file, result.parentUri);
                        final opened = tabs.indexWhere(
                          (tab) => tab.fileUri == result.file.uri,
                        );
                        if (opened >= 0) {
                          selectTab(opened);
                          final text = tabs[opened].controller.text;
                          final offset = text.toLowerCase().indexOf(needle);
                          if (offset >= 0) {
                            tabs[opened].controller.selection = TextSelection(
                              baseOffset: offset,
                              extentOffset: offset + query.length,
                            );
                          }
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    final limitNote = visitedFiles >= maxFiles || results.length >= 200
        ? ' (توقف البحث عند بلوغ الحد الوقائي)'
        : '';
    showMessage(
      'اكتمل البحث: فُحص $visitedFiles ملفًا، وتُخطّي $skippedFiles$limitNote',
    );
  }

  void _applyHistoryText(EditorTab tab, String value) {
    _historyApplying.add(tab.id);
    tab.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _historyApplying.remove(tab.id);
    setState(() {
      tab.isSaved = false;
      status = 'تعديل في سجل التراجع';
    });
  }

  void undoCodeEdit() {
    final tab = activeTab;
    final history = _undoHistory.putIfAbsent(
      tab.id,
      () => <String>[tab.controller.text],
    );
    if (history.length <= 1) {
      showMessage('لا توجد تعديلات للتراجع عنها');
      return;
    }
    final current = history.removeLast();
    _redoHistory.putIfAbsent(tab.id, () => <String>[]).add(current);
    _applyHistoryText(tab, history.last);
  }

  void redoCodeEdit() {
    final tab = activeTab;
    final redo = _redoHistory.putIfAbsent(tab.id, () => <String>[]);
    if (redo.isEmpty) {
      showMessage('لا توجد تعديلات لإعادتها');
      return;
    }
    final next = redo.removeLast();
    _undoHistory.putIfAbsent(tab.id, () => <String>[]).add(next);
    _applyHistoryText(tab, next);
  }

  void _applyLineEdit(EditorLineEditResult? result, String successMessage) {
    if (result == null) {
      showMessage('لا يمكن تنفيذ العملية في هذا الموضع');
      return;
    }
    final tab = activeTab;
    if (result.text == tab.controller.text) return;
    tab.controller.value = TextEditingValue(
      text: result.text,
      selection: result.selection,
    );
    setState(() {
      tab.isSaved = false;
      status = successMessage;
    });
    _scheduleTabStateSave();
  }

  void duplicateSelectedLines() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.duplicateSelectedLines(
        text: tab.controller.text,
        selection: tab.controller.selection,
      ),
      'تم تكرار الأسطر المحددة',
    );
  }

  void moveCurrentLineUp() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.moveCurrentLine(
        text: tab.controller.text,
        selection: tab.controller.selection,
        down: false,
      ),
      'تم نقل السطر للأعلى',
    );
  }

  void moveCurrentLineDown() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.moveCurrentLine(
        text: tab.controller.text,
        selection: tab.controller.selection,
        down: true,
      ),
      'تم نقل السطر للأسفل',
    );
  }

  void toggleSelectedLineComments() {
    final tab = activeTab;
    _applyLineEdit(
      EditorLineActions.toggleLineComments(
        text: tab.controller.text,
        selection: tab.controller.selection,
        language: tab.language,
      ),
      'تم تبديل التعليق على الأسطر',
    );
  }

  void jumpToMatchingBracket() {
    final tab = activeTab;
    final selection = tab.controller.selection;
    final cursor = selection.isValid
        ? selection.extentOffset
        : tab.controller.text.length;
    final match = EditorBracketMatcher.findMatchingOffset(
      source: tab.controller.text,
      cursorOffset: cursor,
      language: tab.language,
    );
    if (match == null) {
      setState(() => status = 'لم يتم العثور على قوس مطابق');
      return;
    }
    tab.controller.selection = TextSelection.collapsed(offset: match);
    setState(() => status = 'تم الانتقال إلى القوس المطابق');
    _scheduleTabStateSave();
  }

  List<String> _getCurrentDiagnostics(EditorTab tab) {
    final source = tab.controller.text;
    final diagnostics = <String>[];
    try {
      switch (tab.language) {
        case 'JSON':
          jsonDecode(source);
          break;
        case 'XML':
          XmlDocument.parse(source);
          break;
        case 'YAML':
          loadYaml(source);
          break;
      }
    } catch (error) {
      final message = error.toString().replaceFirst(RegExp(r'^.*?:\s*'), '');
      diagnostics.add('${tab.language}: $message');
    }

    // Structural checks complement the real JSON/XML/YAML parsers. They are
    // deliberately labelled as lightweight editor diagnostics, not compiler
    // errors or a substitute for a language analyzer.
    diagnostics.addAll(
      EditorSyntaxDiagnostics.analyze(source, tab.language)
          .map((diagnostic) => '${tab.language}: $diagnostic'),
    );
    return diagnostics;
  }

  Widget buildBottomPanel(EditorTab tab) {
    final diagnostics = _getCurrentDiagnostics(tab);
    final lines = tab.controller.text.isEmpty
        ? 1
        : '\n'.allMatches(tab.controller.text).length + 1;
    final characters = tab.controller.text.length;
    final isProblems = _bottomPanelTab == 0;

    return Container(
      height: _bottomPanelHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF101827),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              final screenHeight = MediaQuery.of(context).size.height;
              final nextHeight = _bottomPanelHeight - details.delta.dy;
              final maxHeight = screenHeight * 0.55;
              setState(() {
                _bottomPanelHeight = nextHeight.clamp(110.0, maxHeight).toDouble();
              });
              _saveEditorPreferences();
            },
            child: SizedBox(
              height: 12,
              child: Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _bottomPanelTab = 0),
                  icon: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: _bottomPanelTab == 0
                        ? const Color(0xFF38BDF8)
                        : Colors.white54,
                  ),
                  label: Text(
                    'المشكلات${diagnostics.isEmpty ? '' : ' (${diagnostics.length})'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bottomPanelTab == 0
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _bottomPanelTab = 1),
                  icon: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: _bottomPanelTab == 1
                        ? const Color(0xFF38BDF8)
                        : Colors.white54,
                  ),
                  label: Text(
                    'معلومات الملف',
                    style: TextStyle(
                      fontSize: 11,
                      color: _bottomPanelTab == 1
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'إغلاق اللوحة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _bottomPanelVisible = false);
                    _saveEditorPreferences();
                  },
                  icon: const Icon(Icons.close, size: 17),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF263449)),
          Expanded(
            child: isProblems
                ? diagnostics.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد أخطاء تحقق معروفة لهذا النوع من الملفات',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: diagnostics.length,
                        itemBuilder: (context, index) => ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          title: Text(
                            diagnostics[index],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 8,
                        children: [
                          _panelInfo('الملف', tab.fileName),
                          _panelInfo('اللغة', tab.language),
                          _panelInfo('الأسطر', '$lines'),
                          _panelInfo('الأحرف', '$characters'),
                          _panelInfo('الحالة', tab.isSaved ? 'محفوظ' : 'معدّل'),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _panelInfo(String label, String value) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 11, color: Colors.white70),
    );
  }

  void changeEditorFontSize(double delta) {
    setState(() {
      _editorFontSize = (_editorFontSize + delta).clamp(10.0, 24.0).toDouble();
      status = 'حجم الخط: ${_editorFontSize.toStringAsFixed(0)}';
    });
    _saveEditorPreferences();
  }

  Future<void> showCodeCompletions() async {
    final tab = activeTab;
    final controller = tab.controller;
    final source = controller.text;
    final selection = controller.selection;
    final cursor = selection.isValid
        ? selection.extentOffset.clamp(0, source.length).toInt()
        : source.length;
    final beforeCursor = source.substring(0, cursor);
    final match = RegExp(r'[A-Za-z_][A-Za-z0-9_]*$').firstMatch(beforeCursor);
    final prefix = match?.group(0) ?? '';

    final Map<String, List<String>> completions = {
      'Dart': [
        'void main() {\n  \n}',
        'print()',
        'final ',
        'const ',
        'class ',
        'Future<void> ',
        'async',
        'if () {\n  \n}',
        'for (var i = 0; i < ; i++) {\n  \n}',
      ],
      'JavaScript': [
        'console.log()',
        'const ',
        'let ',
        'function ',
        'async function ',
        'if () {\n  \n}',
        'for (let i = 0; i < ; i++) {\n  \n}',
        'try {\n  \n} catch (error) {\n  console.error(error);\n}',
      ],
      'TypeScript': [
        'console.log()',
        'const ',
        'let ',
        'interface ',
        'type ',
        'function ',
        'async function ',
        'Promise<void>',
      ],
      'Python': [
        'print()',
        'def ',
        'class ',
        'if __name__ == "__main__":\n    ',
        'for item in :\n    ',
        'try:\n    \nexcept Exception as error:\n    print(error)',
        'import ',
      ],
      'HTML': [
        '<!DOCTYPE html>\n<html lang="ar">\n<head>\n  <meta charset="UTF-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1.0">\n  <title></title>\n</head>\n<body>\n  \n</body>\n</html>',
        '<div></div>',
        '<p></p>',
        '<script>\n\n</script>',
        '<style>\n\n</style>',
      ],
      'CSS': [
        'display: flex;',
        'display: grid;',
        'margin: ;',
        'padding: ;',
        'color: ;',
        '@media (max-width: 600px) {\n  \n}',
      ],
      'SQL': [
        'SELECT * FROM ;',
        'SELECT  FROM  WHERE ;',
        'INSERT INTO  () VALUES ();',
        'UPDATE  SET  =  WHERE ;',
        'CREATE TABLE  (\n  id INTEGER PRIMARY KEY\n);',
      ],
      'Markdown': ['# ', '## ', '- ', '1. ', '```\n\n```', '> '],
      'YAML': ['name: ', 'version: ', 'dependencies:\n  ', 'scripts:\n  '],
      'JSON': ['{\n  "": ""\n}', '[\n  \n]'],
      'XML': ['<?xml version="1.0" encoding="UTF-8"?>\n<root>\n</root>', '<root></root>'],
    };

    final candidates = completions[tab.language] ??
        <String>['// TODO: ', 'if () {\n  \n}', 'class ', 'function '];
    final options = EditorCompletionEngine.rank(
      language: tab.language,
      prefix: prefix,
      snippets: [
        ...candidates,
        ...EditorCompletionEngine.identifiersIn(
          source,
          language: tab.language,
        ),
      ],
      maximumResults: 50,
    );

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إكمال تلقائي — ${tab.language}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: options.isEmpty
              ? const Center(child: Text('لا توجد اقتراحات مطابقة'))
              : ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.code, size: 18),
                    title: Text(
                      options[index].replaceAll('\n', ' ↵ '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                    onTap: () => Navigator.pop(dialogContext, options[index]),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;
    final current = controller.text;
    final currentCursor = controller.selection.isValid
        ? controller.selection.extentOffset.clamp(0, current.length).toInt()
        : current.length;
    final currentBefore = current.substring(0, currentCursor);
    final currentMatch = RegExp(r'[A-Za-z_][A-Za-z0-9_]*$').firstMatch(currentBefore);
    final start = currentMatch?.start ?? currentCursor;
    final updated = current.replaceRange(start, currentCursor, chosen);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + chosen.length),
    );
    setState(() {
      activeTab.isSaved = false;
      status = 'تم إدراج الإكمال';
    });
  }

  Future<void> copyCode() async {
    await Clipboard.setData(
      ClipboardData(text: activeTab.controller.text),
    );

    showMessage('تم نسخ الكود');
  }

  void openFlutterPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlutterPreviewScreen(
          projectName: projectName,
        ),
      ),
    );
  }

  Future<void> openLanguagePreview() async {
    final tab = activeTab;
    final engine = LanguageEngineManager.engineForFile(tab.fileName);

    switch (engine) {
      case LanguageEngine.webProject:
        if (projectUri == null || projectUri!.isEmpty) {
          showMessage(
            'افتح مجلد المشروع أولاً لمعاينة ملفات HTML وموارد المشروع',
          );
          return;
        }

        if (tab.fileUri == null || tab.fileUri!.isEmpty) {
          showMessage(
            'احفظ ملف HTML داخل المشروع أو افتحه من مستكشف المشروع أولاً',
          );
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HtmlPreviewScreen(
              htmlCode: tab.controller.text,
              projectUri: projectUri,
              htmlFileUri: tab.fileUri!,
            ),
          ),
        );
        return;

      case LanguageEngine.webCode:
        final mode =
            LanguageEngineManager.webModeForFile(tab.fileName);

        if (mode == null) {
          showMessage('نوع ملف الويب غير مدعوم');
          return;
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: mode,
            ),
          ),
        );
        return;

      case LanguageEngine.jsonViewer:
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WebCodeRunnerScreen(
              code: tab.controller.text,
              fileName: tab.fileName,
              mode: 'json',
            ),
          ),
        );
        return;

      case LanguageEngine.unsupported:
        final extension = tab.fileName.contains('.')
            ? tab.fileName.split('.').last.toLowerCase()
            : '';

        if (extension == 'ts' || extension == 'tsx') {
          showMessage(
            'TypeScript يحتاج إلى إضافة مترجم محلي قبل التشغيل. '
            'سنضيفه في المرحلة التالية.',
          );
        } else {
          showMessage(
            'لا يوجد محرك تشغيل محلي لهذا النوع حتى الآن. '
            'الملف يبقى قابلًا للتحرير والحفظ.',
          );
        }
        return;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget buildExplorerNode(String directoryUri, int depth) {
    return FutureBuilder<List<SafDocumentFile>>(
      key: ValueKey('$_explorerRevision-$directoryUri'),
      future: safFiles.listDirectory(directoryUri),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const ListTile(
            dense: true,
            title: Text('تعذر قراءة المجلد'),
          );
        }

        final items =
            List<SafDocumentFile>.from(snapshot.data ?? []);

        items.sort((a, b) {
          if (a.isDir && !b.isDir) return -1;
          if (!a.isDir && b.isDir) return 1;

          return a.name.toLowerCase().compareTo(
                b.name.toLowerCase(),
              );
        });

        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'المجلد فارغ',
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((entity) {
            if (entity.isDir) {
              final isSelectedDirectory =
                  selectedDirectoryUri == entity.uri;

              return Padding(
                padding: EdgeInsets.only(right: depth * 5.0),
                child: ExpansionTile(
                  key: PageStorageKey<String>(entity.uri),
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),
                  leading: Icon(
                    isSelectedDirectory
                        ? Icons.folder_special
                        : Icons.folder,
                    color: isSelectedDirectory
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFFBBF24),
                    size: 20,
                  ),
                  title: Text(
                    entity.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelectedDirectory
                          ? const Color(0xFF38BDF8)
                          : null,
                      fontWeight: isSelectedDirectory
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'select') {
                        selectCreationDirectory(
                          entity.uri,
                          entity.name,
                        );
                      }

                      if (value == 'rename') {
                        renameEntity(entity);
                      }

                      if (value == 'delete') {
                        deleteEntity(entity);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(
                              Icons.drive_file_move,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('تعيين كمجلد عمل'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('إعادة تسمية'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                    ],
                  ),
                  children: [
                    buildExplorerNode(entity.uri, depth + 1),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(right: depth * 5.0),
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Color(0xFF38BDF8),
                  size: 19,
                ),
                title: Text(
                  entity.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => openProjectFile(entity, directoryUri),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'rename') {
                      renameEntity(entity);
                    }

                    if (value == 'delete') {
                      deleteEntity(entity);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('إعادة تسمية'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف'),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildExplorer() {
    return Container(
      width: 115,
      color: const Color(0xFF111827),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'المستكشف',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: createProjectFile,
                  icon: const Icon(Icons.note_add, size: 19),
                  tooltip: 'ملف جديد',
                ),
                IconButton(
                  onPressed: createProjectFolder,
                  icon: const Icon(Icons.create_new_folder, size: 19),
                  tooltip: 'مجلد جديد',
                ),
                IconButton(
                  onPressed: refreshExplorer,
                  icon: const Icon(Icons.refresh, size: 19),
                  tooltip: 'تحديث المستكشف',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (projectUri == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 38,
                        color: Colors.white54,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'لم يتم فتح مشروع',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: openProjectFolder,
                        child: const Text('فتح مجلد'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.folder,
                      color: Color(0xFFFBBF24),
                    ),
                    title: Text(
                      projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      onPressed: openProjectFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: selectedDirectoryUri != null
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedDirectoryUri != null
                              ? Icons.folder_special
                              : Icons.home_work,
                          size: 15,
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'العمل: $creationDirectoryName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        if (selectedDirectoryUri != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: 'العودة إلى جذر المشروع',
                            onPressed: resetCreationDirectory,
                            icon: const Icon(
                              Icons.home,
                              size: 17,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: buildExplorerNode(projectUri!, 0),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildTabBar() {
    return Container(
      height: 46,
      color: const Color(0xFF111827),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = index == activeIndex;

                return InkWell(
                  onTap: () => selectTab(index),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 100,
                      maxWidth: 180,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0B1020)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: selected
                              ? const Color(0xFF38BDF8)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          size: 15,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            tab.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        if (!tab.isSaved)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.amber,
                            ),
                          ),
                        GestureDetector(
                          onTap: () => closeTab(index),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: createNewTab,
            icon: const Icon(
              Icons.add,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposing = true;
    _tabStateSaveTimer?.cancel();
    // Capture the final editor state before releasing the controllers.
    saveTabStateSilently();
    for (final tab in tabs) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final tab = activeTab;
    final selection = tab.controller.selection;
    final cursorOffset = selection.isValid
        ? selection.extentOffset.clamp(0, tab.controller.text.length).toInt()
        : tab.controller.text.length;
    final textBeforeCursor = tab.controller.text.substring(0, cursorOffset);
    final cursorLine = '\n'.allMatches(textBeforeCursor).length + 1;
    final lastLineBreak = textBeforeCursor.lastIndexOf('\n');
    final cursorColumn = textBeforeCursor.length - lastLineBreak;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF151C30),
          title: const Row(
            children: [
              Icon(
                Icons.code,
                color: Color(0xFF38BDF8),
              ),
              SizedBox(width: 8),
              Text(
                'Bisho IDE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: openFlutterPreview,
              icon: const Icon(
                Icons.phone_android,
                color: Color(0xFF38BDF8),
              ),
              tooltip: 'معاينة Flutter',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  explorerVisible = !explorerVisible;
                });
                _saveEditorPreferences();
              },
              icon: const Icon(Icons.folder_open),
              tooltip: 'المستكشف',
            ),
            IconButton(
              onPressed: saveCurrentToDisk,
              icon: const Icon(Icons.save),
              tooltip: 'حفظ الملف',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'new') createNewTab();
                if (value == 'new_project') createNewProject();
                if (value == 'open') openFile();
                if (value == 'folder') openProjectFolder();
                if (value == 'export') exportFile();
                if (value == 'search') searchCode();
                if (value == 'copy') copyCode();
                if (value == 'saveall') saveAllTabs();
                if (value == 'complete') showCodeCompletions();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'new',
                  child: Text('ملف جديد'),
                ),
                PopupMenuItem(
                  value: 'new_project',
                  child: Row(
                    children: [
                      Icon(
                        Icons.create_new_folder,
                        size: 18,
                        color: Color(0xFF38BDF8),
                      ),
                      SizedBox(width: 8),
                      Text('إنشاء مشروع جديد'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open',
                  child: Text('فتح ملف'),
                ),
                PopupMenuItem(
                  value: 'folder',
                  child: Text('فتح مجلد مشروع'),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text('تصدير الملف'),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: Text('بحث'),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Text('نسخ الكود'),
                ),
                PopupMenuItem(
                  value: 'complete',
                  child: Text('الإكمال التلقائي'),
                ),
                PopupMenuItem(
                  value: 'saveall',
                  child: Text('حفظ جميع الملفات'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            buildTabBar(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              color: const Color(0xFF111827),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tab.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DropdownButton<String>(
                    value: tab.language,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    items: languages.keys.map((language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: changeLanguage,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  toolButton(Icons.add, 'جديد', createNewTab),
                  toolButton(Icons.folder_open, 'فتح', openFile),
                  toolButton(Icons.folder, 'مشروع', openProjectFolder),
                  toolButton(
                    Icons.create_new_folder,
                    'مشروع جديد',
                    createNewProject,
                  ),
                  toolButton(Icons.save, 'حفظ', saveCurrentToDisk),
                  toolButton(Icons.download, 'تصدير', exportFile),
                  toolButton(Icons.search, 'بحث', searchCode),
                  toolButton(Icons.undo, 'تراجع', undoCodeEdit),
                  toolButton(Icons.redo, 'إعادة', redoCodeEdit),
                  toolButton(Icons.copy_all, 'تكرار الأسطر', duplicateSelectedLines),
                  toolButton(Icons.arrow_upward, 'نقل السطر لأعلى', moveCurrentLineUp),
                  toolButton(Icons.arrow_downward, 'نقل السطر لأسفل', moveCurrentLineDown),
                  toolButton(Icons.comment, 'تعليق / إلغاء التعليق', toggleSelectedLineComments),
                  toolButton(Icons.compare_arrows, 'الانتقال إلى القوس المطابق', jumpToMatchingBracket),
                  toolButton(Icons.auto_awesome, 'إكمال', showCodeCompletions),
                  toolButton(Icons.text_decrease, 'تصغير الخط', () => changeEditorFontSize(-1)),
                  toolButton(Icons.text_increase, 'تكبير الخط', () => changeEditorFontSize(1)),
                  toolButton(
                    Icons.vertical_align_bottom,
                    'لوحة المشكلات',
                    () {
                      setState(() => _bottomPanelVisible = !_bottomPanelVisible);
                      _saveEditorPreferences();
                    },
                  ),
                  toolButton(Icons.copy, 'نسخ', copyCode),
                  toolButton(
                    Icons.phone_android,
                    'معاينة Flutter',
                    openFlutterPreview,
                  ),
                  toolButton(
                    Icons.language,
                    'تشغيل / معاينة',
                    openLanguagePreview,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (explorerVisible) buildExplorer(),
                        Expanded(
                          child: Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080D19),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF26334D),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CodeTheme(
                        data: CodeThemeData(
                          styles: monokaiSublimeTheme,
                        ),
                        child: CodeField(
                          key: ValueKey(tab.id),
                          controller: tab.controller,
                          expands: true,
                          wrap: false,
                          padding: const EdgeInsets.all(12),
                          textStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: _editorFontSize,
                          ),
                          gutterStyle: const GutterStyle(
                            showLineNumbers: true,
                            showErrors: true,
                            showFoldingHandles: true,
                          ),
                        ),
                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_bottomPanelVisible) buildBottomPanel(tab),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: const Color(0xFF151C30),
              child: Row(
                children: [
                  const Icon(
                    Icons.circle,
                    color: Colors.green,
                    size: 9,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Text(
                    'Ln $cursorLine, Col $cursorColumn',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.language,
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tab.isSaved ? 'محفوظ' : 'غير محفوظ',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget toolButton(
    IconData icon,
    String label,
    VoidCallback action,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}