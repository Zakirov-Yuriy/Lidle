// ============================================================
//  "Видеообзор объявления или товара"
// ============================================================

/// Разобранная сервером ссылка на видео (19.10.2026, задача 10).
///
/// Приходит полем `video_review` в карточке объявления и товара. Разбирает
/// ссылку СЕРВЕР: у каждой площадки свой адрес встроенного плеера, и держать
/// эти правила ещё и в приложении значит чинить их дважды при каждом
/// изменении на стороне площадки.
class VideoReview {
  /// Ссылка, как её дал продавец. Ею открываем площадку наружу.
  final String url;

  /// youtube, rutube, vk, ok, telegram, dzen, other.
  final String platform;

  /// Адрес встроенного плеера. Пусто, если играть внутри нельзя.
  final String? embedUrl;

  /// Обложка с площадки. Пусто у всех, кроме Ютуба: см. разбор на сервере.
  final String? thumbnail;

  /// Можно ли играть внутри приложения.
  final bool canEmbed;

  const VideoReview({
    required this.url,
    required this.platform,
    this.embedUrl,
    this.thumbnail,
    required this.canEmbed,
  });

  static VideoReview? tryParse(dynamic raw) {
    if (raw is! Map) return null;

    final url = '${raw['url'] ?? ''}'.trim();

    if (url.isEmpty) return null;

    final embed = '${raw['embed_url'] ?? ''}'.trim();
    final thumb = '${raw['thumbnail'] ?? ''}'.trim();

    return VideoReview(
      url: url,
      platform: '${raw['platform'] ?? 'other'}',
      embedUrl: embed.isEmpty ? null : embed,
      thumbnail: thumb.isEmpty ? null : thumb,
      canEmbed: raw['can_embed'] == true && embed.isNotEmpty,
    );
  }

  /// Тот же плеер, но со звуком.
  ///
  /// Включить звук на лету во встроенном плеере нельзя: он живёт в своей
  /// странице, и управлять им из приложения площадки не дают. Поэтому по
  /// нажатию на значок звука плеер перезагружается этим адресом, и ролик
  /// начинается сначала, уже со звуком.
  String? get embedUrlWithSound {
    final embed = embedUrl;

    if (embed == null) return null;

    return embed
        .replaceAll('mute=1', 'mute=0')
        .replaceAll('muted=1', 'muted=0');
  }

  /// Название площадки для подписи на слайде.
  String get platformName => switch (platform) {
        'youtube' => 'YouTube',
        'rutube' => 'Rutube',
        'vk' => 'ВКонтакте',
        'ok' => 'Одноклассники',
        'telegram' => 'Telegram',
        'dzen' => 'Дзен',
        _ => 'видео',
      };
}
