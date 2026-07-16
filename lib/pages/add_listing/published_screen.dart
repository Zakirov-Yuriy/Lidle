import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/pages/profile_dashboard/my_listings/my_listings_screen.dart';
import 'package:lidle/models/main_content_model.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';

class PublishedScreen extends StatefulWidget {
  final UserAdvert? advert;

  const PublishedScreen({
    super.key,
    this.advert,
  });

  @override
  State<PublishedScreen> createState() => _PublishedScreenState();
}

class _PublishedScreenState extends State<PublishedScreen> {
  // Акцентный цвет кнопок (как на экране QR-кода объявления и на скриншоте)
  static const Color _accentColor = Color(0xFF00B7FF);

  // Ключ для захвата QR-кода в картинку (сохранение / шаринг)
  late final GlobalKey _qrKey;

  // Короткий доступ к объявлению (чтобы не переписывать build-методы карточек)
  UserAdvert? get advert => widget.advert;

  @override
  void initState() {
    super.initState();
    _qrKey = GlobalKey();
  }

  // ── Логика ссылки / QR (перенесено из AdvertQrScreen, единый источник) ──

  /// Транслитерация названия в slug (запасной вариант, если slug пуст).
  String _generateSlugFromTitle(String title) {
    const translitMap = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya'
    };

    String slug = title.toLowerCase();
    slug = slug.replaceAllMapped(RegExp('[а-яё]'), (match) {
      return translitMap[match.group(0)] ?? '';
    });
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    slug = slug.replaceAll(RegExp(r'\s+'), '-');
    slug = slug.replaceAll(RegExp(r'-+'), '-');
    slug = slug.replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length > 80) {
      slug = slug.substring(0, 80).replaceAll(RegExp(r'-+$'), '');
    }
    return slug;
  }

  /// URL объявления. Формат: https://lidle.io/ru/advertisements/{id}-{slug}
  /// Предпочитаем реальный slug из модели, иначе генерим из названия.
  String _getAdvertUrl() {
    final title = advert?.name ?? '';
    final rawSlug = advert?.slug;
    final slug = (rawSlug != null && rawSlug.isNotEmpty)
        ? rawSlug
        : _generateSlugFromTitle(title);
    final id = advert?.id ?? 0;
    return 'https://lidle.io/ru/advertisements/$id-$slug';
  }

  String get _advertTitle => advert?.name ?? 'Объявление';
  String get _advertPrice => advert?.price ?? '';

  /// Поделиться ссылкой на объявление.
  Future<void> _shareLink() async {
    try {
      final advertUrl = _getAdvertUrl();
      final priceLine = _advertPrice.isNotEmpty ? '\n$_advertPrice ₽' : '';
      final message =
          'Посмотри это объявление в LIDLE:\n$_advertTitle$priceLine\n$advertUrl';

      await Share.share(
        message,
        subject: 'Объявление из LIDLE',
      );
    } catch (e) {
      _showError('Ошибка при шаринге: $e');
    }
  }

  /// Поделиться QR-кодом (картинкой).
  Future<void> _shareQrCode() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file =
          File('${tempDir.path}/qr_code_advert_${advert?.id ?? 0}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'QR код объявления: $_advertTitle',
        subject: 'QR код объявления LIDLE',
      );
    } catch (e) {
      _showError('Ошибка при шаринге: $e');
    }
  }

  /// Сохранить QR-код в галерею телефона.
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
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = 'lidle_qr_advert_${advert?.id ?? 0}.png';
      final file = File('${tempDir.path}/$fileName');
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
      _showError('❌ Ошибка при сохранении: $e');
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
        final picturesDir = Directory('${appDocDir.parent.path}/Pictures/LIDLE');
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

  /// Печать QR-кода (тот же роут, что и на экране QR-кода объявления).
  Future<void> _printQrCode() async {
    try {
      Navigator.pushNamed(context, '/qr_print_templates');
    } catch (e) {
      _showError('Ошибка: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Лого ──────────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Header(),
                ),
                _buildSecondaryNav(context),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildPublishedCard(),
                        const SizedBox(height: 12),
                        _buildListingCard(context),
                        if (advert != null) ...[
                          const SizedBox(height: 16),
                          _buildQrActions(),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Скрытый (за экраном) QR для сохранения / шаринга ───────────
            if (advert != null)
              Positioned(
                left: -10000,
                top: 0,
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: QrImageView(
                      data: _getAdvertUrl(),
                      version: QrVersions.auto,
                      size: 280.0,
                      gapless: false,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Блок из 4 кнопок (как на скриншоте / на сайте) ──────────────────────
  Widget _buildQrActions() {
    return Column(
      children: [
        // 1. Поделиться ссылкой (заливка)
        _filledButton(
          label: 'Поделиться ссылкой',
          onPressed: _shareLink,
          icon: SvgPicture.asset(
            'assets/home_page/share_outlined.svg',
            width: 20,
            height: 20,
          ),
        ),
        const SizedBox(height: 12),
        // 2. Сохранение qr-код на телефон (заливка)
        _filledButton(
          label: 'Сохранение qr-код на телефон',
          onPressed: _saveQrToGallery,
          icon: SvgPicture.asset(
            'assets/user_qr/download-01.svg',
            width: 20,
            height: 20,
          ),
        ),
        const SizedBox(height: 12),
        // 3. Распечатать qr-код (обводка)
        _outlinedButton(
          label: 'Распечатать qr-код',
          onPressed: _printQrCode,
          icon: const Icon(Icons.print, color: _accentColor),
        ),
        const SizedBox(height: 12),
        // 4. Поделиться qr-код (обводка)
        _outlinedButton(
          label: 'Поделиться qr-код',
          onPressed: _shareQrCode,
          icon: SvgPicture.asset(
            'assets/user_qr/share-01.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              _accentColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filledButton({
    required String label,
    required VoidCallback onPressed,
    required Widget icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _outlinedButton({
    required String label,
    required VoidCallback onPressed,
    required Widget icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _accentColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: onPressed,
        icon: icon,
        label: Text(
          label,
          style: const TextStyle(
            color: _accentColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Назад / Отмена ──────────────────────────────────────────────────────
  Widget _buildSecondaryNav(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                MyListingsScreen.routeName,
                (route) => false,
              );
            },
            child: Row(
              children: const [
                Icon(
                  Icons.chevron_left,
                  color: Color(0xFF4FA3E3),
                  size: 22,
                ),
                SizedBox(width: 2),
                Text(
                  'Назад',
                  style: TextStyle(
                    color: Color(0xFF4FA3E3),
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                MyListingsScreen.routeName,
                (route) => false,
              );
            },
            child: const Text(
              'Отмена',
              style: TextStyle(
                color: Color(0xFF4FA3E3),
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка «Объявление опубликовано» ──────────────────────────────────
  Widget _buildPublishedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Ваше объявление опубликовано ЛИДЛЕ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Вы можете поделиться ссылкой на товар со своими '
            'друзьями или потенциальными покупателями, удобным '
            'для вас способом. Так быстрее произойдет сделка.',
            style: TextStyle(
              color: Color(0xFF8E8E9E),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Карточка объявления ─────────────────────────────────────────────────
  Widget _buildListingCard(BuildContext context) {
    if (advert == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'Объявление не найдено',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final priceText = (advert!.price != null && advert!.price!.isNotEmpty)
        ? '${advert!.price} ₽'
        : 'Договорная';

    final title = advert!.name ?? 'Без названия';
    final imageUrl = advert!.thumbnail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 100,
              height: 80,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2C3E50),
                                Color(0xFF3D5A6E),
                                Color(0xFF4A6C82),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF2C3E50),
                            Color(0xFF3D5A6E),
                            Color(0xFF4A6C82),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final listing = Listing(
                      id: advert!.id.toString(),
                      slug: advert!.slug,
                      imagePath: advert!.thumbnail ?? '',
                      title: advert!.name ?? 'Без названия',
                      price: advert!.price ?? 'Договорная',
                      location: advert!.address ?? 'Адрес не указан',
                      date: advert!.createdAt ?? '',
                      images: advert!.thumbnail != null
                          ? [advert!.thumbnail!]
                          : [],
                      description: '',
                      characteristics: {},
                      sellerName: '',
                      sellerAvatar: '',
                      sellerRegistrationDate: '',
                      userId: null,
                      isBargain: false,
                      isFavorited: false,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MiniPropertyDetailsScreen(listing: listing),
                      ),
                    );
                  },
                  child: Row(
                    children: const [
                      Text(
                        'Перейти',
                        style: TextStyle(
                          color: Color(0xFF4FA3E3),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: Color(0xFF4FA3E3),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}