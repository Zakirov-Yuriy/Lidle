// ============================================================
// "Сохранение картинки в галерею"
// ============================================================
//
// Вынесено отдельно 17.09.2026, когда сохранять понадобилось из двух мест:
// карточку с кодом получения и чек по заказу. Две копии одного и того же
// кода означали бы два разных ответа на вопрос «куда сохранилось» и два
// разных поведения при отказе в разрешении.
//
// Снимок делаем с самого экрана (`RepaintBoundary`), а не рисуем картинку
// второй раз: так сохраняется ровно то, что человек видит.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:lidle/core/logger.dart';

/// Чем закончилось сохранение. Разные причины разбираем отдельно: «не дали
/// разрешение» это не то же самое, что «не получилось», и человеку надо
/// сказать разное.
enum ImageSaveResult { saved, noPermission, failed }

class ImageSaver {
  /// Снять с экрана участок под [key] и положить PNG в галерею.
  static Future<ImageSaveResult> saveBoundary(
    GlobalKey key,
    String fileName, {
    double pixelRatio = 3.0,
  }) async {
    try {
      if (!await _ensurePermission()) return ImageSaveResult.noPermission;

      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return ImageSaveResult.failed;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      if (data == null) return ImageSaveResult.failed;

      final temp = await getTemporaryDirectory();
      final file = File('${temp.path}/$fileName');

      await file.writeAsBytes(data.buffer.asUint8List());
      await _copyToGallery(file, fileName);

      if (await file.exists()) await file.delete();

      return ImageSaveResult.saved;
    } catch (e) {
      log.d('Картинка не сохранилась: $e');

      return ImageSaveResult.failed;
    }
  }

  static Future<bool> _ensurePermission() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;

      // С Android 13 доступ к галерее спрашивают как доступ к фотографиям, а
      // не к хранилищу целиком: старое разрешение там просто не выдаётся.
      final status = info.version.sdkInt >= 33
          ? await Permission.photos.request()
          : await Permission.storage.request();

      return status.isGranted;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();

      return status.isGranted;
    }

    return true;
  }

  /// Куда класть файл. Путь один и тот же у кода, чека и QR продавца: два
  /// разных места означали бы два разных ответа на вопрос «куда сохранилось».
  static Future<void> _copyToGallery(File file, String name) async {
    if (Platform.isAndroid) {
      try {
        final directory = Directory('/storage/emulated/0/DCIM/Camera');

        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        await file.copy('${directory.path}/$name');

        return;
      } catch (e) {
        log.d('DCIM недоступен, кладём в папку приложения: $e');
      }
    }

    final documents = await getApplicationDocumentsDirectory();

    await file.copy('${documents.path}/$name');
  }
}
