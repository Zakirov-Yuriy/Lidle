// ============================================================
//  Экран блока «Добавить …» (22.09.2026)
// ============================================================
//
// Макет «Добавить общий план ресторана»:
//
//   1. Поля зала (атрибуты блока из админки) и «PDF зала»: плюс, выбор
//      картинки или PDF. После выбора на месте плюса превью и «Изменить».
//   2. «Сохранить» → экран-подтверждение: крупно план и текст «Вы добавили
//      план зала…». Ещё раз «Сохранить» → назад в форму объявления, зал
//      появляется в списке под блоком.
//
// Экран ничего не отправляет на сервер: зал уедет вместе с объявлением
// (см. BlockItemsService). Возвращает заполненный BlockItemDraft или null.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/filter_models.dart';
import 'package:lidle/pages/dynamic_filter/block/block_fields_form.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:pdfx/pdfx.dart';

const Color _divider = Color(0xFF474747);

/// «Добавить общий план зала» → «общий план зала».
String _tail(String title) =>
    title.replaceFirst(RegExp(r'^Добавить\s+', caseSensitive: false), '');

/// Подпись раздела файла: «PDF зала», «PDF меню».
String _fileLabel(String title) {
  final words = title.trim().split(RegExp(r'\s+'));
  return 'PDF ${words.isEmpty ? '' : words.last}'.trim();
}

void _soon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('Скоро будет доступно'),
      backgroundColor: secondaryBackground,
    ));
}

class BlockItemScreen extends StatefulWidget {
  const BlockItemScreen({
    super.key,
    required this.block,
    required this.fields,
    this.initial,
  });

  final Attribute block;
  final List<Attribute> fields;
  final BlockItemDraft? initial;

  @override
  State<BlockItemScreen> createState() => _BlockItemScreenState();
}

class _BlockItemScreenState extends State<BlockItemScreen> {
  late final BlockFieldsController _controller;

  String? _localPath;
  String? _remoteUrl;
  String? _kind;
  bool _removedFile = false;

  @override
  void initState() {
    super.initState();
    _controller = BlockFieldsController(widget.fields);

    final initial = widget.initial;
    if (initial != null) {
      _controller.prefill(initial.values);
      _localPath = initial.localFilePath;
      _remoteUrl = initial.remoteFileUrl;
      _kind = initial.fileKind;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasFile => _localPath != null || _remoteUrl != null;

  /// Экран сотрудника (22.09.2026): вместо плана фото человека, без PDF и
  /// без экрана-подтверждения с планом.
  bool get _isStaff => widget.block.title.toLowerCase().contains('сотрудник');

  Future<void> _pickFile() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: secondaryBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in [
              ['gallery', 'Фото из галереи', Icons.photo_library_outlined],
              ['camera', 'Сделать фото', Icons.photo_camera_outlined],
              if (!_isStaff) ['pdf', 'PDF-файл', Icons.picture_as_pdf_outlined],
            ])
              ListTile(
                leading: Icon(entry[2] as IconData, color: activeIconColor),
                title: Text(entry[1] as String, style: const TextStyle(color: textPrimary)),
                onTap: () => Navigator.pop(context, entry[0] as String),
              ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    String? path;
    String kind = 'image';

    if (choice == 'pdf') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      path = result?.files.single.path;
      kind = 'pdf';
    } else {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2400,
        imageQuality: 90,
      );
      path = picked?.path;
    }

    if (path == null || !mounted) return;

    // 20 МБ — предел сервера.
    if (await File(path).length() > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Файл больше 20 МБ'),
        backgroundColor: secondaryBackground,
      ));
      return;
    }

    setState(() {
      _localPath = path;
      _remoteUrl = null;
      _kind = kind;
      _removedFile = false;
    });
  }

  Future<void> _save() async {
    final missing = _controller.missingRequired();
    final problem = _controller.rangeProblem();

    if (missing.isNotEmpty || problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(problem ?? 'Заполните: ${missing.join(', ')}'),
        backgroundColor: secondaryBackground,
      ));
      return;
    }

    // С планом — сначала экран-подтверждение, как на макете.
    if (_hasFile && !_isStaff) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _BlockPreviewScreen(
            title: widget.block.title,
            preview: BlockFilePreview(localPath: _localPath, remoteUrl: _remoteUrl, kind: _kind),
          ),
        ),
      );
      if (ok != true || !mounted) return;
    }

    final draft = widget.initial ?? BlockItemDraft();
    draft
      ..values = _controller.payload()
      ..summary = _controller.summary()
      ..localFilePath = _localPath
      ..remoteFileUrl = _remoteUrl
      ..fileKind = _hasFile ? _kind : null
      ..removeFile = _removedFile && !_hasFile
      ..dirty = true;

    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.block.title;
    final label = _isStaff ? 'Фото сотрудника' : _fileLabel(title);

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 30),
                children: [
                  _TitleRow(title: title, onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 10),
                  _Links(tail: _tail(title)),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 20),
                  BlockFieldsForm(controller: _controller),
                  if (_hasFile) ...[
                    const Divider(color: _divider, height: 1),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
                        ),
                        GestureDetector(
                          onTap: _pickFile,
                          child: const Text('Изменить', style: TextStyle(color: activeIconColor, fontSize: 15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    BlockFilePreview(localPath: _localPath, remoteUrl: _remoteUrl, kind: _kind),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _localPath = null;
                          _remoteUrl = null;
                          _kind = null;
                          _removedFile = true;
                        }),
                        child: const Text('Удалить файл', style: TextStyle(color: textSecondary, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: _divider, height: 1),
                  ] else ...[
                    Text(label, style: const TextStyle(color: textPrimary, fontSize: 16)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        height: 125,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: formBackground,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: textSecondary, width: 1.5),
                              ),
                              child: const Icon(Icons.add, color: textSecondary, size: 24),
                            ),
                            const SizedBox(height: 10),
                            Text(_isStaff ? 'Добавить фото' : 'Добавить изображение',
                                style: TextStyle(color: textSecondary, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isStaff
                          ? 'Фото сотрудника, до 20 МБ. Его видно при выборе официанта '
                              'и администратора стола.'
                          : 'PDF или фото плана одного этажа вашего заведения, до 20 МБ. '
                              'После загрузки объект проходит модерацию и появится у вас в аккаунте.',
                      style: TextStyle(color: textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _SaveButton(onTap: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Padding(
            padding: EdgeInsets.only(right: 6, top: 2),
            child: Icon(Icons.arrow_back_ios_new, color: textPrimary, size: 18),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onBack,
          child: const Text('Отмена', style: TextStyle(color: activeIconColor, fontSize: 15)),
        ),
      ],
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.tail});

  final String tail;

  @override
  Widget build(BuildContext context) {
    Widget link(String text) => GestureDetector(
          onTap: () => _soon(context),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: const TextStyle(color: activeIconColor, fontSize: 14)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        link('Что такое $tail?'),
        link('Заказать $tail'),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: activeIconColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: const Text('Сохранить', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }
}

/// Экран-подтверждение с планом (второй макет).
class _BlockPreviewScreen extends StatelessWidget {
  const _BlockPreviewScreen({required this.title, required this.preview});

  final String title;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 30),
                children: [
                  _TitleRow(title: title, onBack: () => Navigator.pop(context, false)),
                  const SizedBox(height: 10),
                  _Links(tail: _tail(title)),
                  const SizedBox(height: 16),
                  const Divider(color: _divider, height: 1),
                  const SizedBox(height: 20),
                  preview,
                  const SizedBox(height: 24),
                  const Text(
                    'Вы добавили план зала в своем ресторане. Теперь пользователи '
                    'смогут бронировать места и выбирать время своего визита к вам.',
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 40),
                  _SaveButton(onTap: () => Navigator.pop(context, true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Превью файла: картинка как есть, у PDF первая страница.
class BlockFilePreview extends StatelessWidget {
  const BlockFilePreview({super.key, this.localPath, this.remoteUrl, this.kind});

  final String? localPath;
  final String? remoteUrl;
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final Widget child;

    if (kind == 'pdf') {
      child = _PdfFirstPage(localPath: localPath, remoteUrl: remoteUrl);
    } else if (localPath != null) {
      child = Image.file(File(localPath!), fit: BoxFit.contain);
    } else if (remoteUrl != null) {
      child = Image.network(remoteUrl!, fit: BoxFit.contain);
    } else {
      child = const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: child,
      ),
    );
  }
}

class _PdfFirstPage extends StatefulWidget {
  const _PdfFirstPage({this.localPath, this.remoteUrl});

  final String? localPath;
  final String? remoteUrl;

  @override
  State<_PdfFirstPage> createState() => _PdfFirstPageState();
}

class _PdfFirstPageState extends State<_PdfFirstPage> {
  // Страница рисуется один раз, а не на каждую перерисовку экрана.
  late Future<Uint8List?> _future = _render();

  @override
  void didUpdateWidget(covariant _PdfFirstPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath || oldWidget.remoteUrl != widget.remoteUrl) {
      _future = _render();
    }
  }

  String? get localPath => widget.localPath;
  String? get remoteUrl => widget.remoteUrl;

  Future<Uint8List?> _render() async {
    PdfDocument? doc;
    try {
      if (localPath != null) {
        doc = await PdfDocument.openFile(localPath!);
      } else if (remoteUrl != null) {
        final response = await http.get(Uri.parse(remoteUrl!));
        if (response.statusCode != 200) return null;
        doc = await PdfDocument.openData(response.bodyBytes);
      } else {
        return null;
      }

      final page = await doc.getPage(1);
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();

      return image?.bytes;
    } catch (_) {
      return null;
    } finally {
      await doc?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator(color: activeIconColor)),
          );
        }
        final bytes = snap.data;
        if (bytes == null) {
          return Container(
            height: 120,
            color: formBackground,
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: textSecondary),
                SizedBox(width: 8),
                Text('PDF-файл', style: TextStyle(color: textSecondary)),
              ],
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.contain);
      },
    );
  }
}
