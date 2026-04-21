// ============================================================
// "Виджет: Изображение профиля пользователя"
// ============================================================
// Отображает аватар из URL (Image.network) или локального
// файла (Image.file). При ошибке или отсутствии пути —
// серый placeholder.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

/// Возвращает виджет изображения профиля.
///
/// - Если [imagePath] начинается с `http` — загружает по сети.
/// - Если это локальный путь — загружает из файла.
/// - Если пусто или null — серый placeholder.
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
    return Image.network(
      imagePath,
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
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        );
      },
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
