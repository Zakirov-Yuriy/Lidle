// ============================================================
// Диалог группы: картинка и название (макет 10.09.2026).
// ============================================================
//
// Один диалог на товары и на доставку: группы там устроены одинаково, и
// заводить их человек должен одинаково. Показывается и при заведении новой
// группы, и при правке — по нажатию на название или на значок фотоаппарата.
//
// Картинка выбирается здесь, а уходит на сервер уже вызывающим экраном:
// у новой группы её некуда грузить, пока группы нет.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';

/// Что человек ввёл в диалоге группы.
class GroupForm {
  const GroupForm({required this.name, this.photoPath});

  final String name;

  /// Путь к выбранному файлу. Пусто — картинку не трогали.
  final String? photoPath;
}

/// Показать диалог группы.
///
/// Возвращает `null`, если человек передумал.
Future<GroupForm?> showGroupDialog(
  BuildContext context, {
  String title = 'Добавить группу',
  String initialName = '',
  String? imageUrl,
}) {
  return showDialog<GroupForm>(
    context: context,
    builder: (context) => _GroupDialog(
      title: title,
      initialName: initialName,
      imageUrl: imageUrl,
    ),
  );
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({
    required this.title,
    required this.initialName,
    this.imageUrl,
  });

  final String title;
  final String initialName;
  final String? imageUrl;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);

  String? _photo;

  // Контроллер намеренно не освобождаем: диалог закрывается с анимацией, и
  // поле живёт ещё несколько кадров. Освобождение здесь оставляет живой
  // TextField с мёртвым контроллером — приложение намертво зависает.

  Future<void> _pickPhoto() async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    setState(() => _photo = picked.first);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: textPrimary, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text('Изображение группы',
                style: TextStyle(color: textPrimary, fontSize: 15)),
            const SizedBox(height: 8),
            _photoBlock(),

            const SizedBox(height: 16),
            const Text('Название группы',
                style: TextStyle(color: textPrimary, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _name,
                autofocus: widget.initialName.isEmpty,
                style: const TextStyle(color: textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Например, Куртки зима',
                  hintStyle: TextStyle(color: textMuted, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () {
                    final name = _name.text.trim();

                    if (name.isEmpty) return;

                    Navigator.pop(
                      context,
                      GroupForm(name: name, photoPath: _photo),
                    );
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: activeIconColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoBlock() {
    final local = _photo;
    final saved = widget.imageUrl;

    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: local != null
            ? Image.file(File(local), fit: BoxFit.cover)
            : saved != null
                ? Image.network(
                    saved,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, color: textSecondary, size: 28),
          SizedBox(height: 8),
          Text('Добавить изображение',
              style: TextStyle(color: textSecondary, fontSize: 14)),
        ],
      );
}
