// ============================================================
//  "Видео первым слайдом галереи"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/video_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// Наш источник для встроенных плееров.
///
/// ЭТО НЕ КОСМЕТИКА. Площадка видит, с какого сайта её плеер встроили, и по
/// этому имени решает, показывать ролик или нет. 19.10.2026 мы подставляли
/// сюда сам youtube.com, рассуждая «источник и плеер с одного домена, значит
/// претензий не будет». Вышло наоборот: страница в приложении назвалась
/// Ютубом, Ютуб такого встраивания не признал и ответил «This video is
/// unavailable, error 152». Наш настоящий домен площадки принимают.
const String _siteOrigin = 'https://lidle.ru';

/// Видеообзор на первом слайде карточки (19.10.2026, задача 10).
///
/// Где площадка разрешает, ролик играет прямо здесь и запускается САМ, без
/// звука. Со звуком автоматически не запускается ничто и нигде: это
/// запрещают и площадки, и сами телефоны. Звук человек включает значком.
///
/// Где встроенного плеера нет (Телеграм, Дзен и прочие) и где площадка
/// отказалась показывать ролик, слайд показывает обложку с кнопкой запуска и
/// открывает площадку наружу.
class VideoReviewSlide extends StatefulWidget {
  final VideoReview video;

  /// Чем закрыть место, пока плеер грузится, и что показать там, где
  /// встроить нельзя. Обычно первая фотография карточки.
  final String? fallbackImage;

  /// Слайд открыт человеком.
  ///
  /// Галерея строит соседнюю страницу ЗАРАНЕЕ, чтобы плеер успел
  /// подгрузиться, пока человек смотрит первый снимок (19.10.2026). Но
  /// играть в этот момент ролик не должен: человек его ещё не видит, а
  /// трафик уже идёт. Поэтому запуск отложен до открытия слайда.
  final bool active;

  const VideoReviewSlide({
    super.key,
    required this.video,
    this.fallbackImage,
    this.active = true,
  });

  @override
  State<VideoReviewSlide> createState() => _VideoReviewSlideState();
}

class _VideoReviewSlideState extends State<VideoReviewSlide> {
  WebViewController? _controller;

  /// Звук включён.
  bool _sound = false;

  /// Площадка отказалась показывать ролик внутри приложения.
  ///
  /// Так бывает у роликов, которым владелец запретил встраивание. Показывать
  /// человеку чужой экран ошибки нельзя: вместо него обложка с переходом.
  bool _refused = false;

  /// Ютуб ведём своим плеером, а не ссылкой на готовую страницу.
  bool get _isYoutube =>
      widget.video.platform == 'youtube' && widget.video.videoId != null;

  bool get _canPlayInside => _isYoutube || widget.video.canEmbed;

  @override
  void initState() {
    super.initState();

    // Ютуб грузим сразу, даже у закрытого слайда: его плеером мы управляем
    // сами, и ролик будет молчать, пока человек до него не долистает. У
    // остальных площадок такой власти над плеером нет, их рамка начала бы
    // играть сама собой, поэтому они ждут открытия слайда.
    if (_isYoutube || (widget.active && widget.video.canEmbed)) {
      _start();
    }
  }

  @override
  void didUpdateWidget(covariant VideoReviewSlide oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.active || oldWidget.active) return;

    final controller = _controller;

    // Слайд открыли. Ютуб уже загружен, его достаточно попросить играть.
    if (_isYoutube && controller != null) {
      controller.runJavaScript('lidlePlay()');

      return;
    }

    if (controller == null && widget.video.canEmbed) {
      _start();
    }
  }

  /// Собрать плеер и начать загрузку.
  ///
  /// ПОРЯДОК ШАГОВ ЗДЕСЬ ГЛАВНОЕ. Разрешение играть без нажатия ставится
  /// ДО загрузки страницы: телефон смотрит на эту настройку в тот момент,
  /// когда страница начинает грузиться, и выставленная следом она уже ничего
  /// не меняет. 19.10.2026 ролик не запускался сам именно поэтому.
  ///
  /// У айфона это разрешение выдаётся ИНАЧЕ, чем у андроида: не настройкой
  /// готового окна, а при его создании. Пока окно создавалось обычным
  /// способом, ролик на айфоне не запускался сам никогда, сколько бы раз мы
  /// ни чинили сторону андроида.
  Future<void> _start({bool sound = false}) async {
    final controller = WebViewController.fromPlatformCreationParams(
      WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              // Играть прямо в карточке, а не разворачивать на весь экран.
              allowsInlineMediaPlayback: true,
              // Пустой набор означает «ничего не требует нажатия»: и видео,
              // и звук запускаются сами.
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams(),
    );

    final platform = controller.platform;

    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }

    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // Фон под плеером тёмный: пока страница грузится, белый прямоугольник на
    // тёмной карточке бьёт по глазам.
    //
    // ТОЛЬКО НА АНДРОИДЕ (20.10.2026). На айфоне заданный фон окна ломает
    // отрисовку видео: вместо картинки идут цветные полосы и шум, звук при
    // этом играет. Окно там рисуется поверх обычных слоёв приложения, и
    // собственный цвет фона сбивает ему прозрачность. Место под плеером и
    // так не светится: под ним лежит обложка ролика.
    if (platform is AndroidWebViewController) {
      await controller.setBackgroundColor(const Color(0xFF1F2C3A));
    }

    // Обратная связь от плеера: заиграл, не смог, площадка отказала.
    await controller.addJavaScriptChannel(
      'LidleVideo',
      onMessageReceived: _onMessage,
    );

    final page = _isYoutube
        ? _youtubePage(widget.video.videoId!, autoplay: widget.active)
        : _framePage(
            sound
                ? widget.video.embedUrlWithSound ?? widget.video.embedUrl!
                : widget.video.embedUrl!,
          );

    await controller.loadHtmlString(page, baseUrl: _siteOrigin);

    if (!mounted) return;

    setState(() {
      _controller = controller;
      _sound = sound;
      _refused = false;
    });
  }

  void _onMessage(JavaScriptMessage message) {
    final text = message.message;

    log.d('🎬 Плеер: $text');

    if (!text.startsWith('error')) return;

    if (!mounted) return;

    setState(() {
      _refused = true;
      _controller = null;
    });
  }

  /// Своя страница с плеером Ютуба.
  ///
  /// Плеер собирается скриптом площадки, а не вставляется ссылкой. Так мы
  /// можем ЗАПУСТИТЬ ролик сами, а не надеяться на `autoplay` в адресе: в
  /// приложении автозапуск по адресу срабатывает через раз. И так же сами
  /// включаем звук по значку, не перезагружая ролик с начала.
  String _youtubePage(String videoId, {required bool autoplay}) => '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>
      html, body { margin: 0; padding: 0; height: 100%; background: #1F2C3A; overflow: hidden; }
      #player { width: 100%; height: 100%; }
    </style>
  </head>
  <body>
    <div id="player"></div>
    <script src="https://www.youtube.com/iframe_api"></script>
    <script>
      var player = null;
      var tries = 0;
      // Открыт ли слайд. Пока нет, плеер только грузится и молчит.
      var play = $autoplay;

      function send(text) {
        try { LidleVideo.postMessage(text); } catch (e) {}
      }

      // Пробуем запустить, пока не поедет. Первые попытки приходятся на
      // момент, когда плеер ещё добирает данные, и тогда запуск молча
      // пропадает.
      function kick() {
        if (player === null || tries > 25) return;

        tries++;

        try {
          player.mute();
          player.playVideo();
        } catch (e) {}

        var state = -1;

        try { state = player.getPlayerState(); } catch (e) {}

        if (state !== 1) {
          setTimeout(kick, 400);
        }
      }

      function onYouTubeIframeAPIReady() {
        player = new YT.Player('player', {
          videoId: '$videoId',
          width: '100%',
          height: '100%',
          playerVars: {
            autoplay: play ? 1 : 0,
            mute: 1,
            // Без этого телефон разворачивает ролик на весь экран, едва он
            // начался.
            playsinline: 1,
            rel: 0,
            modestbranding: 1,
            origin: '$_siteOrigin'
          },
          events: {
            onReady: function () { send('ready'); if (play) kick(); },
            onStateChange: function (e) { if (e.data === 1) send('playing'); },
            onError: function (e) { send('error:' + e.data); }
          }
        });
      }

      // Скрипт площадки не доехал: сети нет или её режут. Слайд уйдёт на
      // обложку с переходом наружу.
      setTimeout(function () { if (player === null) send('error:api'); }, 9000);

      // Слайд открыли: пора играть.
      function lidlePlay() {
        play = true;
        tries = 0;
        kick();
      }

      function lidleSound(on) {
        try {
          if (on) { player.unMute(); player.setVolume(100); } else { player.mute(); }
        } catch (e) {}
      }
    </script>
  </body>
</html>
''';

  /// Страница-рамка для остальных площадок: Рутуб, ВК, Одноклассники.
  ///
  /// У них своего скрипта плеера нет, поэтому рамка со ссылкой. Разрешение
  /// `allow="autoplay"` обязательно: без него автозапуск запрещён, сколько
  /// бы настроек ни стояло в самом приложении.
  String _framePage(String url) => '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>
      html, body { margin: 0; padding: 0; height: 100%; background: #1F2C3A; overflow: hidden; }
      iframe { border: 0; width: 100%; height: 100%; display: block; }
    </style>
  </head>
  <body>
    <iframe src="$url"
            allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
            allowfullscreen></iframe>
  </body>
</html>
''';

  Future<void> _toggleSound() async {
    final controller = _controller;

    if (controller == null) return;

    // У Ютуба звук включается на лету, ролик не прерывается.
    if (_isYoutube) {
      await controller.runJavaScript('lidleSound(${!_sound})');

      if (!mounted) return;

      setState(() => _sound = !_sound);

      return;
    }

    // У остальных площадок управлять плеером снаружи нельзя: он живёт в своей
    // странице. Поэтому плеер перезагружается адресом со звуком, и ролик
    // начинается сначала.
    await _start(sound: !_sound);
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

    if (_refused || (!_canPlayInside && controller == null)) {
      return _outsideSlide();
    }

    if (controller == null) {
      // Плеер ещё собирается: место под него занимает первая фотография, а не
      // пустой тёмный прямоугольник.
      return _loadingSlide();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Подложка под плеером (20.10.2026): на айфоне окно плеера рисуется
        // без своего фона, и пока ролик не пошёл, под ним должно быть хоть
        // что-то, иначе проступает тёмная пустота.
        _backdrop(),

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

  /// Картинка под плеером: обложка ролика, иначе первая фотография.
  Widget _backdrop() {
    final image = widget.video.thumbnail ?? widget.fallbackImage;

    if (image == null) {
      return Container(color: const Color(0xFF1F2C3A));
    }

    return Image.network(
      image,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1F2C3A)),
    );
  }

  Widget _loadingSlide() {
    final image = widget.video.thumbnail ?? widget.fallbackImage;

    return Stack(
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
        Container(color: Colors.black.withValues(alpha: 0.35)),
        const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Слайд площадки, которую встроить нельзя или которая отказала.
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
