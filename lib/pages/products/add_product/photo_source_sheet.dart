// ============================================================
// Выбор фотографий для товаров: камера или галерея.
// ============================================================
//
// Ровно то же, что человек видит при подаче объявления: снизу выезжает выбор
// источника, дальше системный выбор файла. Вынесено отдельно, потому что
// пользуются им два экрана — обложка группы и фотографии позиции, — а
// повторять один и тот же лист в обоих значит однажды поправить только один.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';

/// Выбрать фотографии.
///
/// Возвращает пути к файлам. Пустой список означает, что человек передумал:
/// это не ошибка, и говорить ему об этом не надо.
Future<List<String>> pickProductPhotos(
  BuildContext context, {
  bool multiple = false,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: secondaryBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined,
                color: textPrimary, size: 24),
            title: const Text(
              'Сделать фотографию',
              style: TextStyle(color: textPrimary, fontSize: 15),
            ),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined,
                color: textPrimary, size: 24),
            title: Text(
              multiple ? 'Выбрать из галереи' : 'Загрузить фотографию',
              style: const TextStyle(color: textPrimary, fontSize: 15),
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (source == null) return const [];

  final picker = ImagePicker();

  try {
    // Из галереи берём сразу несколько, если экран это позволяет: выбирать
    // фотографии по одной для карточки товара мучительно.
    if (source == ImageSource.gallery && multiple) {
      final files = await picker.pickMultiImage();

      return files.map((file) => file.path).toList();
    }

    final file = await picker.pickImage(source: source);

    return file == null ? const [] : [file.path];
  } catch (e) {
    log.e('Не получилось выбрать фотографию: $e');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось открыть фотографии')),
      );
    }

    return const [];
  }
}
