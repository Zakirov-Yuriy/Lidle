// ============================================================
//  "Видео первым слайдом галереи"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/video_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Видеообзор на первом слайде карточки (19.10.2026, задача 10).
///
/// Где площадка разрешает, ролик играет прямо здесь и запускается САМ, без
/// звука. Со звуком автоматически не запускается ничто и нигде: это
/// запрещают и площадки, и сами телефоны. Звук человек включает значком, и
/// тогда плеер перезагружается уже со звуком, с начала ролика.
///
/// Где встроенного плеера нет (Телеграм, Дзен и прочие), слайд показывает
/// обложку с кнопкой запуска и открывает площадку наружу.
class VideoReviewSlide extends StatefulWidget {
  final VideoReview video;

  /// Чем закрыть место, пока плеер грузится, и что показать там, где
  /// встроить нельзя. Обычно первая фотография карточки.
  final String? fallbackImage;

  const VideoReviewSlide({
    super.key,
    required this.video,
    this.fallbackImage,
  });

  @override
  State<VideoReviewSlide> createState() => _VideoReviewSlideState();
}

class _VideoReviewSlideState extends State<VideoReviewSlide> {
  WebViewController? _controller;

  /// Звук включён: плеер перезагружен адресом со звуком.
  bool _sound = false;

  @override
  void initState() {
    super.initState();

    if (widget.video.canEmbed) {
      _controller = _build(widget.video.embedUrl!);
    }
  }

  WebViewController _build(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Фон под плеером тёмный: пока страница грузится, белый прямоугольник
      // на тёмной карточке бьёт по глазам.
      ..setBackgroundColor(const Color(0xFF1F2C3A))
      ..loadRequest(Uri.parse(url));

    // БЕЗ ЭТОГО АВТОЗАПУСКА НЕ БУДЕТ. Android по умолчанию требует, чтобы
    // воспроизведение начинал человек, и `autoplay=1` в адресе ничего не
    // меняет.
    final platform = controller.platform;

    if (platform is AndroidWebViewController) {
      platform.setMediaPlaybackRequiresUserGesture(false);
    }

    return controller;
  }

  void _toggleSound() {
    final url = _sound ? widget.video.embedUrl : widget.video.embedUrlWithSound;

    if (url == null) return;

    setState(() {
      _sound = !_sound;
      _controller = _build(url);
    });
  }

  Future<void> _openOutside() async {
    final uri = Uri.tryParse(widget.video.url);

    if (uri == null) return;

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      log.d('⚠️ Не удалось открыть видео наружу: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return _outsideSlide();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: controller),

        // Значок звука поверх плеера, как в лентах соцсетей.
        Positioned(
          right: 10,
          bottom: 10,
          child: GestureDetector(
            onTap: _toggleSound,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _sound ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Слайд площадки, которую встроить нельзя.
  Widget _outsideSlide() {
    final image = widget.video.thumbnail ?? widget.fallbackImage;

    return GestureDetector(
      onTap: _openOutside,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF1F2C3A)),
            )
          else
            Container(color: const Color(0xFF1F2C3A)),

          // Затемнение: поверх светлой фотографии значок и подпись иначе не
          // читаются.
          Container(color: Colors.black.withValues(alpha: 0.35)),

          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 56,
                ),
                const SizedBox(height: 8),
                Text(
                  'Смотреть в ${widget.video.platformName}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
