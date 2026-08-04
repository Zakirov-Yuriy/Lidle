// ============================================================
// "Виджет: Экран QR-кода продавца"
// ============================================================
//
// Аналог AdvertQrScreen, но для страницы продавца: показывает имя
// продавца и QR-код со ссылкой на его профиль, плюс кнопки поделиться
// ссылкой / сохранить QR / распечатать / поделиться QR.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SellerQrScreen extends StatefulWidget {
  /// Имя/название продавца (для подписи над QR).
  final String sellerName;

  /// Ссылка на профиль продавца (данные QR-кода и шаринга).
  final String sellerUrl;

  const SellerQrScreen({
    super.key,
    required this.sellerName,
    required this.sellerUrl,
  });

  @override
  State<SellerQrScreen> createState() => _SellerQrScreenState();
}

class _SellerQrScreenState extends State<SellerQrScreen> {
  static const bgColor = Color(0xFF243241);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  late GlobalKey qrKey;

  @override
  void initState() {
    super.initState();
    qrKey = GlobalKey();
  }

  /// Ссылка на профиль продавца (данные QR).
  String _getSellerUrl() => widget.sellerUrl;

  /// Поделиться ссылкой на профиль продавца.
  Future<void> _shareLink() async {
    try {
      final url = _getSellerUrl();
      final message =
          'Профиль продавца в LIDLE:\n${widget.sellerName}\n$url';

      await Share.share(
        message,
        subject: 'Продавец из LIDLE',
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

  /// Поделиться изображением QR-кода.
  Future<void> _shareQrCode() async {
    try {
      final boundary =
          qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_code_seller.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR код продавца: ${widget.sellerName}',
        subject: 'QR код продавца LIDLE',
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

  /// Сохранить QR-код в галерею.
  Future<void> _saveQrToGallery() async {
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Сохранение QR кода...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final boundary =
          qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/lidle_qr_seller.png');
      await file.writeAsBytes(bytes);

      if (Platform.isAndroid) {
        await _saveToAndroidGallery(file);
      } else if (Platform.isIOS) {
        await _saveToIOSGallery(file);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR код успешно сохранен в галерею!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

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

  Future<void> _saveToAndroidGallery(File file) async {
    try {
      final directory = Directory('/storage/emulated/0/DCIM/Camera');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final fileName = 'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = File('${directory.path}/$fileName');
      await file.copy(savedFile.path);
    } catch (e) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final picturesDir =
            Directory('${appDocDir.parent.path}/Pictures/LIDLE');
        if (!await picturesDir.exists()) {
          await picturesDir.create(recursive: true);
        }
        final fileName =
            'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
        final savedFile = File('${picturesDir.path}/$fileName');
        await file.copy(savedFile.path);
      } catch (e2) {
        throw Exception('Ошибка сохранения на Android: $e, fallback: $e2');
      }
    }
  }

  Future<void> _saveToIOSGallery(File file) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'LIDLE_QR_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedFile = File('${appDocDir.path}/$fileName');
      await file.copy(savedFile.path);
    } catch (e) {
      throw Exception('Ошибка сохранения на iOS: $e');
    }
  }

  /// Распечатать QR-код (общий экран шаблонов печати).
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
        child: SingleChildScrollView(
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
                      'QR-код продавца',
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

              // ───── Seller Info ─────
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Продавец:',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: Text(
                        widget.sellerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // ───── QR CODE (CENTER) ─────
              Center(
                child: RepaintBoundary(
                  key: qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _getSellerUrl(),
                      version: QrVersions.auto,
                      size: 280.0,
                      gapless: false,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ───── Button 1: Share Link ─────
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
                    onPressed: _shareLink,
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
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _saveQrToGallery,
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
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: accentColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _shareQrCode,
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
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
