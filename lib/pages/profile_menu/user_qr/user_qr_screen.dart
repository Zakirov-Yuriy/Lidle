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
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';

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
      print('✅ QR код сохранен: ${file.path}');

      // Делимся файлом
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Мой QR код в LIDLE - $username',
        subject: 'QR код пользователя LIDLE',
      );
    } catch (e) {
      print('❌ Ошибка при шаринге QR кода: $e');
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

            const SizedBox(height: 32),

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

            const SizedBox(height: 40),

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

            const SizedBox(height: 40),

            // ───── Save QR ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, '/qr_print_templates'),
                  icon: SvgPicture.asset(
                    'assets/user_qr/download-01.svg',
                    width: 20,
                    height: 20,
                  ),
                  label: const Text(
                    'Сохранения qr-код на телефон',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ───── Share QR ─────
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
                        color: accentColor,
                      ),
                      label: const Text(
                        'Поделится qr-код',
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
