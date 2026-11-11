
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'core/services/saf_file_service.dart';

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlCode;
  final String? projectUri;
  final String htmlFileUri;

  const HtmlPreviewScreen({
    super.key,
    required this.htmlCode,
    required this.htmlFileUri,
    this.projectUri,
  });

  @override
  State<HtmlPreviewScreen> createState() =>
      _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController _controller;

  final SafFileService _safFiles = SafFileService();

  bool _isLoading = true;
  String? _error;
  final List<String> _logs = <String>[];
  String _viewportMode = 'phone';
  String _logFilter = 'all';
  bool _consoleExpanded = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

  Directory? _previewDirectory;
  File? _htmlPreviewFile;
  Timer? _previewUpdateTimer;
  int _htmlUpdateGeneration = 0;
  Future<void> _htmlUpdateQueue = Future<void>.value();

  @override
  void didUpdateWidget(covariant HtmlPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final projectChanged = oldWidget.projectUri != widget.projectUri ||
        oldWidget.htmlFileUri != widget.htmlFileUri;

    if (projectChanged) {
      _previewUpdateTimer?.cancel();
      _htmlUpdateGeneration++;
      unawaited(_reloadPage());
      return;
    }

    if (oldWidget.htmlCode != widget.htmlCode) {
      _scheduleHtmlOnlyUpdate();
    }
  }

  void _scheduleHtmlOnlyUpdate() {
    _previewUpdateTimer?.cancel();
    final generation = ++_htmlUpdateGeneration;
    _previewUpdateTimer = Timer(
      const Duration(milliseconds: 350),
      () {
        _htmlUpdateQueue = _htmlUpdateQueue.then(
          (_) => _refreshHtmlOnly(generation),
        ).catchError((Object error) {
          debugPrint('تعذر إكمال تحديث المعاينة: $error');
        });
      },
    );
  }

  // تحديث HTML من المحرر دون إعادة نسخ بقية ملفات المشروع.
  // تتم مزامنة CSS والصور والموارد الأخرى عند طلب إعادة تحميل كاملة.
  Future<void> _refreshHtmlOnly(int generation) async {
    final htmlFile = _htmlPreviewFile;
    if (!mounted || generation != _htmlUpdateGeneration) return;

    if (htmlFile == null || !await htmlFile.exists()) {
      await _reloadPage();
      return;
    }

    try {
      await htmlFile.writeAsString(
        _injectConsoleBridge(widget.htmlCode),
        flush: true,
      );
      if (!mounted || generation != _htmlUpdateGeneration) return;

      setState(() {
        _isLoading = true;
        _error = null;
        _logs.clear();
      });
      await _controller.loadFile(htmlFile.path);
    } catch (error) {
      if (!mounted || generation != _htmlUpdateGeneration) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر تحديث HTML في المعاينة: $error';
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        const Color(0xFF101318),
      )
      ..addJavaScriptChannel(
        'BishoConsole',
        onMessageReceived: (message) {
          if (!mounted) return;
          setState(() {
            _logs.add(message.message);
            if (_logs.length > 500) {
              _logs.removeAt(0);
            }
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _error = null;
            });
          },
          onPageFinished: (_) async {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _error = null;
            });
            await _applyViewportPreset();
            await _refreshNavigationState();
          },
          onWebResourceError: (error) {
            if (!mounted) return;

            // تجاهل أخطاء الموارد الفرعية هنا.
            // قد تكون بعض الموارد اختيارية في المشروع.
            if (error.isForMainFrame == false) return;

            setState(() {
              _isLoading = false;
              _error = error.description;
            });
          },
        ),
      );

    _loadPage();
  }

  // إنشاء مسار محلي آمن داخل مجلد المعاينة.
  String _joinPath(
    String parent,
    String child,
  ) {
    final safeName = child.replaceAll(
      '\\',
      '/',
    );

    if (safeName.isEmpty ||
        safeName == '.' ||
        safeName == '..' ||
        safeName.startsWith('/') ||
        safeName.contains('/')) {
      throw Exception(
        'اسم ملف أو مجلد غير صالح: $child',
      );
    }

    return '$parent${Platform.pathSeparator}$safeName';
  }

  // التحقق من اسم ملف HTML.
  bool _isHtmlFile(String name) {
    final lower = name.toLowerCase();

    return lower.endsWith('.html') ||
        lower.endsWith('.htm');
  }

  // نسخ ملفات المشروع من SAF إلى المجلد المؤقت.
  //
  // يتم الاحتفاظ بالهيكل الأصلي للمجلدات.
  // وتتم إعادة المسار النسبي لملف HTML المطلوب.
  Future<String?> _copyProjectDirectory({
    required String sourceUri,
    required String destinationPath,
    required String htmlFileUri,
    String relativePath = '',
  }) async {
    final items = await _safFiles.listDirectory(
      sourceUri,
    );

    String? htmlRelativePath;

    for (final item in items) {
      final name = item.name;

      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains('/') ||
          name.contains('\\')) {
        continue;
      }

      final currentRelativePath = relativePath.isEmpty
          ? name
          : '$relativePath/$name';

      final destinationItemPath = _joinPath(
        destinationPath,
        name,
      );

      if (item.isDir) {
        final directory = Directory(
          destinationItemPath,
        );

        await directory.create(
          recursive: true,
        );

        final nestedHtmlPath =
            await _copyProjectDirectory(
          sourceUri: item.uri,
          destinationPath: destinationItemPath,
          htmlFileUri: htmlFileUri,
          relativePath: currentRelativePath,
        );

        if (nestedHtmlPath != null) {
          htmlRelativePath = nestedHtmlPath;
        }
      } else {
        try {
          final bytes = await _safFiles.readFile(
            item.uri,
          );

          final outputFile = File(
            destinationItemPath,
          );

          await outputFile.parent.create(
            recursive: true,
          );

          await outputFile.writeAsBytes(
            bytes,
            flush: true,
          );

          if (item.uri == htmlFileUri) {
            htmlRelativePath = currentRelativePath;
          }
        } catch (e) {
          debugPrint(
            'تعذرت قراءة الملف $name: $e',
          );
        }
      }
    }

    return htmlRelativePath;
  }

  // إنشاء مجلد مؤقت مستقل لكل عملية معاينة.
  Future<Directory> _createPreviewDirectory() async {
    final temporaryDirectory =
        await getTemporaryDirectory();

    final previewPath =
        '${temporaryDirectory.path}'
        '${Platform.pathSeparator}'
        'bisho_preview_${DateTime.now().microsecondsSinceEpoch}';

    final directory = Directory(
      previewPath,
    );

    await directory.create(
      recursive: true,
    );

    return directory;
  }

  // حذف مجلد المعاينة السابق.
  Future<void> _deletePreviousPreview() async {
    final oldDirectory = _previewDirectory;

    _previewDirectory = null;
    _htmlPreviewFile = null;

    if (oldDirectory == null) return;

    try {
      if (await oldDirectory.exists()) {
        await oldDirectory.delete(
          recursive: true,
        );
      }
    } catch (e) {
      debugPrint(
        'تعذر حذف ملفات المعاينة السابقة: $e',
      );
    }
  }


  // التقاط console وأخطاء JavaScript وإرسالها إلى لوحة المخرجات في Flutter.
  String _injectConsoleBridge(String html) {
    const bridge = r'''
<script>
(function () {
  if (window.__bishoConsoleInstalled) return;
  window.__bishoConsoleInstalled = true;

  function stringify(value) {
    if (typeof value === 'string') return value;
    if (value instanceof Error) return value.stack || value.message;
    try {
      var result = JSON.stringify(value);
      return result === undefined ? String(value) : result;
    } catch (_) {
      return String(value);
    }
  }

  function send(level, args) {
    try {
      var line = '[' + level + '] ' +
        Array.prototype.map.call(args, stringify).join(' ');
      if (window.BishoConsole && window.BishoConsole.postMessage) {
        window.BishoConsole.postMessage(line);
      }
    } catch (_) {}
  }

  ['log', 'info', 'warn', 'error', 'debug', 'trace', 'assert', 'count', 'timeEnd', 'table'].forEach(function (level) {
    var original = console[level] ? console[level].bind(console) : function () {};
    console[level] = function () {
      send(level, arguments);
      original.apply(console, arguments);
    };
  });

  window.addEventListener('error', function (event) {
    if (event.target && event.target !== window) return;
    send('error', [
      (event.message || 'JavaScript error') +
      (event.filename ? ' — ' + event.filename : '') +
      (event.lineno ? ':' + event.lineno : '') +
      (event.colno ? ':' + event.colno : '')
    ]);
  });

  window.addEventListener('unhandledrejection', function (event) {
    send('unhandledrejection', [event.reason || 'Unhandled promise rejection']);
  });

  window.addEventListener('error', function (event) {
    if (event.target && event.target !== window) {
      var target = event.target;
      send('resource', [
        'تعذر تحميل مورد: ' + (target.src || target.href || target.tagName || 'unknown')
      ]);
    }
  }, true);

  document.addEventListener('DOMContentLoaded', function () {
    send('system', ['تم تحميل صفحة المعاينة']);
  });
})();
</script>
''';

    final headPattern = RegExp(r'<head(?:\s[^>]*)?>', caseSensitive: false);
    final match = headPattern.firstMatch(html);
    if (match != null) {
      return html.replaceRange(match.end, match.end, bridge);
    }

    final doctypePattern = RegExp(r'<!doctype[^>]*>', caseSensitive: false);
    final doctype = doctypePattern.firstMatch(html);
    if (doctype != null) {
      return html.replaceRange(doctype.end, doctype.end, '<head>$bridge</head>');
    }
    return '<!doctype html><html><head>$bridge</head><body>$html</body></html>';
  }

  // محاكاة عرض شاشات شائعة عبر viewport دون تغيير ملفات المشروع الأصلية.
  Future<void> _applyViewportPreset() async {
    if (!mounted) return;
    final width = switch (_viewportMode) {
      'tablet' => '768',
      'desktop' => '1280',
      'phone-landscape' => '844',
      _ => 'device-width',
    };
    try {
      await _controller.runJavaScript('''
(function () {
  var meta = document.querySelector('meta[name="viewport"]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'viewport';
    document.head.appendChild(meta);
  }
  meta.setAttribute('content', 'width=$width, initial-scale=1, maximum-scale=5, user-scalable=yes');
})();
''');
    } catch (error) {
      debugPrint('تعذر تطبيق حجم المعاينة: $error');
    }
  }

  Future<void> _refreshNavigationState() async {
    try {
      final back = await _controller.canGoBack();
      final forward = await _controller.canGoForward();
      if (!mounted) return;
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    } catch (_) {}
  }

  Future<void> _goBack() async {
    if (!_canGoBack) return;
    await _controller.goBack();
    await _refreshNavigationState();
  }

  Future<void> _goForward() async {
    if (!_canGoForward) return;
    await _controller.goForward();
    await _refreshNavigationState();
  }

  List<String> get _visibleLogs {
    if (_logFilter == 'errors') {
      return _logs.where((line) =>
        line.startsWith('[error]') ||
        line.startsWith('[unhandledrejection]') ||
        line.startsWith('[resource]')).toList();
    }
    if (_logFilter == 'warnings') {
      return _logs.where((line) => line.startsWith('[warn]')).toList();
    }
    return _logs;
  }

  // تجهيز المشروع وفتح ملف HTML.
  Future<void> _loadPage() async {
    try {
      if (mounted) {
        setState(() {
          _logs.clear();
          _error = null;
        });
      }

      if (widget.projectUri == null ||
          widget.projectUri!.isEmpty) {
        throw Exception(
          'لم يتم تحديد مجلد المشروع.',
        );
      }

      if (widget.htmlFileUri.isEmpty) {
        throw Exception(
          'تعذر تحديد ملف HTML.',
        );
      }

      await _deletePreviousPreview();

      if (!mounted) return;

      final previewDirectory =
          await _createPreviewDirectory();

      _previewDirectory = previewDirectory;

      final htmlRelativePath =
          await _copyProjectDirectory(
        sourceUri: widget.projectUri!,
        destinationPath: previewDirectory.path,
        htmlFileUri: widget.htmlFileUri,
      );

      if (htmlRelativePath == null) {
        throw Exception(
          'لم يتم العثور على ملف HTML داخل مجلد المشروع. '
          'تأكد من أن الملف موجود وأن صلاحية الوصول إلى المجلد محفوظة.',
        );
      }

      // استبدال النسخة المؤقتة بمحتوى المحرر الحالي.
      // هذا يسمح بمعاينة التعديلات غير المحفوظة.
      final normalizedRelativePath =
          htmlRelativePath.replaceAll(
        '/',
        Platform.pathSeparator,
      );

      final htmlFile = File(
        '${previewDirectory.path}'
        '${Platform.pathSeparator}'
        '$normalizedRelativePath',
      );

      final htmlWithConsole = _injectConsoleBridge(widget.htmlCode);
      await htmlFile.writeAsString(
        htmlWithConsole,
        flush: true,
      );

      if (!mounted) return;

      if (!await htmlFile.exists()) {
        throw Exception(
          'تعذر إنشاء ملف HTML المؤقت.',
        );
      }

      _htmlPreviewFile = htmlFile;

      // فتح ملف HTML المحلي مباشرة.
      await _controller.loadFile(
        htmlFile.path,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // إعادة تجهيز المشروع بالكامل.
  Future<void> _reloadPage() async {
    if (!mounted) return;
    _previewUpdateTimer?.cancel();
    _htmlUpdateGeneration++;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _loadPage();
  }

  @override
  void dispose() {
    _previewUpdateTimer?.cancel();
    _htmlUpdateGeneration++;
    final directory = _previewDirectory;

    if (directory != null) {
      unawaited(
        directory.delete(
          recursive: true,
        ).catchError((Object error) {
          debugPrint(
            'تعذر حذف مجلد المعاينة: $error',
          );
          return directory;
        }),
      );
    }

    super.dispose();
  }

  double? get _fixedViewportWidth {
    return switch (_viewportMode) {
      'phone-landscape' => 844.0,
      'tablet' => 768.0,
      'desktop' => 1280.0,
      _ => null,
    };
  }

  Widget _buildPreviewSurface() {
    final viewportWidth = _fixedViewportWidth;
    if (viewportWidth == null) {
      return WebViewWidget(controller: _controller);
    }

    // يحافظ WebView على عرض CSS الحقيقي للجهاز المحدد، مع تمرير أفقي
    // عند كون إطار المعاينة أعرض من شاشة الهاتف الفعلية.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: viewportWidth,
            height: constraints.maxHeight,
            child: WebViewWidget(controller: _controller),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101318),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191E26),
        foregroundColor: Colors.white,
        title: const Text(
          'معاينة مشروع الويب',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _canGoBack ? _goBack : null,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'رجوع',
          ),
          IconButton(
            onPressed: _canGoForward ? _goForward : null,
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'تقدم',
          ),
          PopupMenuButton<String>(
            tooltip: 'حجم شاشة المعاينة',
            initialValue: _viewportMode,
            onSelected: (value) async {
              setState(() => _viewportMode = value);
              await _applyViewportPreset();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'phone', child: Text('هاتف · متجاوب')),
              PopupMenuItem(value: 'phone-landscape', child: Text('هاتف عريض · 844px')),
              PopupMenuItem(value: 'tablet', child: Text('جهاز لوحي · 768px')),
              PopupMenuItem(value: 'desktop', child: Text('سطح مكتب · 1280px')),
            ],
            icon: const Icon(Icons.devices),
          ),
          IconButton(
            onPressed: _isLoading ? null : _reloadPage,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة مزامنة ملفات المشروع وإعادة تحميل المعاينة',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildPreviewSurface(),
                ),
                if (_isLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33101318),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                if (_error != null)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF101318),
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252B35),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 44,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'تعذر عرض المشروع',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: _reloadPage,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _consoleExpanded ? 210 : 46,
            width: double.infinity,
            color: const Color(0xFF080D19),
            child: Column(
              children: [
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                      bottom: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        color: Color(0xFF38BDF8),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'وحدة التحكم',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_visibleLogs.length}/${_logs.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'تصفية المخرجات',
                        onSelected: (value) => setState(() => _logFilter = value),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'all', child: Text('الكل')),
                          PopupMenuItem(value: 'errors', child: Text('الأخطاء فقط')),
                          PopupMenuItem(value: 'warnings', child: Text('التحذيرات فقط')),
                        ],
                        icon: const Icon(Icons.filter_list, color: Colors.white70, size: 19),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _consoleExpanded ? 'طي وحدة التحكم' : 'توسيع وحدة التحكم',
                        onPressed: () => setState(() => _consoleExpanded = !_consoleExpanded),
                        icon: Icon(
                          _consoleExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                          color: Colors.white70, size: 19,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'مسح المخرجات',
                        onPressed: () => setState(_logs.clear),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white70,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_consoleExpanded)
                  Expanded(
                    child: _visibleLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'ستظهر هنا رسائل console وأخطاء JavaScript',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          itemCount: _visibleLogs.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: SelectableText(
                              _visibleLogs[index],
                              style: TextStyle(
                                color: _visibleLogs[index].startsWith('[error]') ||
                                        _visibleLogs[index].startsWith('[unhandledrejection]') ||
                                        _visibleLogs[index].startsWith('[resource]')
                                    ? Colors.redAccent
                                    : Colors.white70,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}