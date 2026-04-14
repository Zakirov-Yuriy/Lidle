// ============================================================
// "Виджет: Экран пользовательского QR-кода"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/core/config/app_config.dart';

class UserQrScreen extends StatefulWidget {
  const UserQrScreen({super.key});

  @override
  State<UserQrScreen> createState() => _UserQrScreenState();
}

class _UserQrScreenState extends State<UserQrScreen> {
  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfileEvent());
  }

  /// Функция для поделиться ссылкой на профиль
  /// Использует правильный домен в зависимости от окружения (dev/prod)
  /// Prod: https://lidle.io/ru/users/{userId}
  /// Dev: https://dev.lidle.io/ru/users/{userId}
  Future<void> _shareLink(String userId, String username) async {
    try {
      // Очищаем userId от префикса "ID: " если присутствует
      final cleanUserId = userId.replaceFirst('ID: ', '').trim();
      final profileUrl = '${AppConfig().websiteUrl}/users/$cleanUserId';
      
      final message = 'Посмотри мой профиль в LIDLE: $username\n$profileUrl';
      
      // Отправляем только текст со ссылкой (без картинки для совместимости с Telegram)
      await Share.share(
        message,
        subject: 'Мой профиль в LIDLE',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при шаринге: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Функция для поделиться QR кодом
  Future<void> _shareQrCode(String qrCodeBase64, String username) async {
    try {
      // Декодируем base64 в байты
      final bytes = base64Decode(qrCodeBase64);

      // Получаем временную директорию
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code_$username.png');

      // Сохраняем файл
      await file.writeAsBytes(bytes);
      // log.d('✅ QR код сохранен: ${file.path}');

      // Делимся файлом
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Мой QR код в LIDLE - $username',
        subject: 'QR код пользователя LIDLE',
      );
    } catch (e) {
      // log.d('❌ Ошибка при шаринге QR кода: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при шаринге: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Функция для сохранения QR кода в галерею
  /// Декодирует base64 QR код и сохраняет в галерею телефона
  Future<void> _saveQrToGallery(String qrCodeBase64, String username) async {
    try {
      // Запрашиваем разрешения на сохранение
      PermissionStatus status;
      if (Platform.isAndroid) {
        // Для Android 13+ нужно разрешение PHOTOS, для ранних версий WRITE_EXTERNAL_STORAGE
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.photos.request();
        } else {
          status = await Permission.storage.request();
        }
      } else if (Platform.isIOS) {
        status = await Permission.photos.request();
      } else {
        status = PermissionStatus.granted;
      }

      // Проверяем было ли разрешение дано
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Требуется разрешение на сохранение файлов'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранение QR кода...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Декодируем base64 в байты
      final bytes = base64Decode(qrCodeBase64);

      // Получаем временную директорию
      final tempDir = await getTemporaryDirectory();
      final fileName = 'lidle_qr_$username.png';
      final file = File('${tempDir.path}/$fileName');

      // Сохраняем файл временно
      await file.writeAsBytes(bytes);

      // Сохраняем в галерею используя методы платформы
      if (Platform.isAndroid) {
        await _saveToAndroidGallery(file);
      } else if (Platform.isIOS) {
        await _saveToIOSGallery(file);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ QR код успешно сохранен в галерею!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Очищаем временный файл
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка при сохранении: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Сохранить QR код в галерею Android
  Future<void> _saveToAndroidGallery(File file) async {
    try {
      // Получаем публичную директорию для фото
      final directory = Directory('/storage/emulated/0/DCIM/Camera');
      
      // Создаём директорию если её нет
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Сохраняем файл с уникальным именем
      final fileName = 'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = File('${directory.path}/$fileName');
      
      // Копируем файл
      await file.copy(savedFile.path);
      
      // log.d('✅ QR код сохранен в: ${savedFile.path}');
    } catch (e) {
      // Fallback: сохраняем в папку PICTURES
      try {
        // На некоторых устройствах нужно использовать getExternalFilesDir
        // Сохраняем через временное решение в app documents
        final appDocDir = await getApplicationDocumentsDirectory();
        final picturesDir = Directory('${appDocDir.parent.path}/Pictures/LIDLE');
        
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        
        final fileName = 'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedFile = File('${picturesDir.path}/$fileName');
        await file.copy(savedFile.path);
      } catch (e2) {
        throw Exception('Ошибка сохранения на Android: $e, fallback: $e2');
      }
    }
  }

  /// Сохранить QR код в галерею iOS
  Future<void> _saveToIOSGallery(File file) async {
    try {
      // Для iOS сохраняем в Documents директорию приложения
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = File('${appDocDir.path}/$fileName');
      await file.copy(savedFile.path);

      // log.d('QR код сохранен в Documents: ${savedFile.path}');
    } catch (e) {
      throw Exception('Ошибка сохранения на iOS: $e');
    }
  }

  /// Функция для печати QR кода
  Future<void> _printQrCode() async {
    try {
      Navigator.pushNamed(context, '/qr_print_templates');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(children: const [Header()]),
            ),

            // ───── Back row ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ваш QR-код',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ───── Username ─────
            Center(
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  final username = state is ProfileLoaded
                      ? state.username
                      : '@Name';
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ваш ник: ',
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // ───── QR CODE (CENTER) ─────
            Center(
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  if (state is ProfileLoaded && state.qrCode != null) {
                    // Используем готовый QR код от API (base64)
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.memory(
                        base64Decode(state.qrCode!),
                        width: 340,
                        height: 340,
                        fit: BoxFit.contain,
                      ),
                    );
                  }
                  // Fallback если QR код не загружен
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const SizedBox(
                      width: 340,
                      height: 340,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // ───── Button 1: Share Link ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    final username = state is ProfileLoaded
                        ? state.username
                        : '@Name';
                    final userId = state is ProfileLoaded
                        ? state.userId
                        : '';
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: (state is ProfileLoaded)
                          ? () => _shareLink(userId, username)
                          : null,
                      icon: SvgPicture.asset(
                        'assets/home_page/share_outlined.svg',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text(
                        'Поделиться ссылкой',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ───── Button 2: Save QR ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: (state is ProfileLoaded && state.qrCode != null)
                          ? () => _saveQrToGallery(state.qrCode!, state.username)
                          : null,
                      icon: SvgPicture.asset(
                        'assets/user_qr/download-01.svg',
                        width: 20,
                        height: 20,
                      ),
                      label: const Text(
                        'Сохранение qr-код на телефон',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ───── Button 3: Print QR ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _printQrCode,
                  icon: const Icon(
                    Icons.print,
                    color: accentColor,
                  ),
                  label: const Text(
                    'Распечатать qr-код',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ───── Button 4: Share QR ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    return OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: accentColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed:
                          (state is ProfileLoaded && state.qrCode != null)
                          ? () => _shareQrCode(state.qrCode!, state.username)
                          : null,
                      icon: SvgPicture.asset(
                        'assets/user_qr/share-01.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          accentColor,
                          BlendMode.srcIn,
                        ),
                      ),
                      label: const Text(
                        'Поделиться qr-код',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

