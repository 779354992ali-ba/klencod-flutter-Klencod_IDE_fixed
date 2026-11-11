# Bisho IDE – Package 1 progress

This archive continues the supplied Bisho IDE Flutter project; it is not a new project.

## Included in this update
- Retains the local HTML/JavaScript preview and existing SAF project/file workflows.
- Retains Markdown preview and XML/YAML/JSON local parsing/formatting features from the previous package.
- Retains project-wide SAF search, editor undo/redo, template-based completion, adjustable font size, and resizable bottom panel.
- Adds a live cursor position indicator (`Ln`, `Col`) to the status bar.
- Fixes dirty-state tracking so moving the cursor or changing the selection alone does not mark a saved file as modified.
- Adds automatic closing-pair insertion for `()`, `[]`, `{}`, single/double quotes, and backticks when a single opening character is typed. The caret remains between the pair; multi-character edits and escaped quotes are not auto-paired.

## Verification
- ZIP archive integrity checked after packaging.
- Source changes were reviewed for balanced delimiters and expected insertion points.
- Automatic-pair insertion was reviewed for single-character diff detection, cursor placement, and listener recursion protection.
- Flutter/Dart SDK is not available in the packaging environment, so `flutter analyze`, widget tests, Android build, and on-device runtime tests were not run.
- TypeScript remains syntax-highlighted only; no embedded TypeScript compiler is claimed in this package.

## دفعة مساعدة التحرير التالية

- أضيفت خدمة `EditorEditingAssist` لتحسين التحرير اليومي: المسافة البادئة التلقائية عند Enter، وتجاوز قوس الإغلاق الموجود بدل تكراره، وحذف قوس الإغلاق المقابل عند حذف قوس الفتح بـ Backspace.
- تُنسخ المسافة البادئة الحالية في السطر الجديد.
- عند إدخال سطر بين زوج أقواس متطابق مثل `{}`، يُنشأ سطر داخلي بمسافة بادئة إضافية ويُحاذى قوس الإغلاق في السطر التالي.
- الميزة لا تتدخل في اللصق متعدد الأحرف أو التغييرات متعددة الأسطر أو التراجع/الإعادة.
- أضيفت اختبارات وحدات للحالات الأساسية في `test/editor_editing_assist_test.dart`.

## التحقق

- فُحصت بنية ZIP بعد إنشائه.
- أُجري فحص توازن الأقواس للملف المساعد الجديد.
- لم تتوفر أدوات Flutter/Dart في بيئة إعداد الحزمة؛ لذلك لم تُشغّل `flutter test` ولم يُبنَ APK.
