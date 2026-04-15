// ============================================================
// "Виджет: Экран печатных форм для QR-кода"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class QrPrintTemplatesScreen extends StatelessWidget {
  const QrPrintTemplatesScreen({super.key});

  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

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
              child: Row(
                children: const [Header()],
              ),
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
                  const Expanded(
                    child: Text(
                      'Печатные формы для qr-кода',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── List ─────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: const [
                  _TemplateCard(
                    image: 'assets/user_qr/image1.jpg',
                    title: 'QR-код для печати',
                    subtitle: '1000 x 1000 px (10 на 10 см)',
                  ),
                  _TemplateCard(
                    image: 'assets/user_qr/image2.jpg',
                    title: 'Визитка для типографии',
                    subtitle: '50 на 90 мм',
                  ),
                  _TemplateCard(
                    image: 'assets/user_qr/image3.jpg',
                    title: 'Форма для печати тейбл тент A5',
                    subtitle: 'A5 - 14,8 x 21 см',
                  ),
                  _TemplateCard(
                    image: 'assets/user_qr/image4.jpg',
                    title: 'Форма для печати стикер A4',
                    subtitle: 'A4 - 29,7 x 29,7 см',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEMPLATE CARD
// ─────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final String image;
  final String title;
  final String subtitle;

  const _TemplateCard({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;
  bool _isDownloading = false;

  /// Скачать PDF с QR кодом
  Future<void> _downloadQrPdf() async {
    try {
      // Запрашиваем разрешения
      PermissionStatus status;
      if (Platform.isAndroid) {
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

      if (mounted) {
        setState(() => _isDownloading = true);
      }

      // Получаем директорию для сохранения
      final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Создаем имя файла на основе названия шаблона
      final fileName = 'QR_${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';

      // TODO: Здесь должна быть логика генерации PDF с QR кодом
      // Пока просто создаем пустой файл для демонстрации
      final file = File(filePath);
      await file.writeAsString('PDF QR Code - ${widget.title}');

      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ PDF скачан в: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка скачивания: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.asset(
                widget.image,
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle
          Text(
            widget.subtitle,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 10),

          // Buttons row
          Row(
            children: [
              // PDF button
              SizedBox(
                height: 29,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: () {
                    // TODO: Обработка нажатия на кнопку PDF
                  },
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Download button
              SizedBox(
                height: 29,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: accentColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: _isDownloading ? null : _downloadQrPdf,
                  child: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        )
                      : const Text(
                          'Скачать',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
