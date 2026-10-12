// ============================================================
// "Виджет: Изображение профиля пользователя"
// ============================================================
// Отображает аватар из URL (с кешем на диске) или локального
// файла (Image.file). При ошибке или отсутствии пути —
// серый placeholder.
// ============================================================

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Возвращает виджет изображения профиля.
///
/// - Если [imagePath] начинается с `http` — загружает по сети, с кешем.
/// - Если это локальный путь — загружает из файла.
/// - Если пусто или null — серый placeholder.
///
/// КЕШ (12.10.2026). Раньше здесь стоял `Image.network`: он держит картинку
/// только в памяти, и после перезапуска приложения или вытеснения из памяти
/// аватар качался заново, показывая поверх себя кружок загрузки. Человек
/// видел это при каждом заходе в профиль и в настройки.
///
/// `CachedNetworkImage` хранит файл на диске, поэтому второй и все следующие
/// разы аватар появляется сразу.
///
/// Кружка тут больше нет СОЗНАТЕЛЬНО: пока картинка едет, показываем ровный
/// серый кружок-заглушку. Крутилка на месте лица мигает при каждом переходе
/// и выглядит хуже, чем спокойная заливка.
Widget buildProfileImage(
  String? imagePath, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
}) {
  if (imagePath == null || imagePath.isEmpty) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(color: Colors.grey[300]),
    );
  }

  if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: imagePath,
      width: width,
      height: height,
      fit: fit,
      // Та же картинка в памяти переживает переходы между экранами, а на
      // диске — перезапуск приложения.
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[800],
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  } else {
    try {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } catch (e) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      );
    }
  }
}
