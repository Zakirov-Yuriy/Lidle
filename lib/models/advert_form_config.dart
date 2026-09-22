/// Постоянная часть формы подачи объявления (22.09.2026).
///
/// Приходит блоком `form` в ответе `GET /v1/adverts/create` рядом с
/// атрибутами категории. В каталоге «Бронирование» форма своя: поля «Цена»
/// нет (её заменяют атрибуты вроде «Средней суммы чека»), первое поле
/// называется «Название компании», под категорией её путь.
///
/// Если сервер блок не прислал (старый бэкенд), действует [fallback]:
/// форма рисуется как раньше.
class AdvertFormConfig {
  final bool isBooking;
  final bool showPrice;
  final String titleLabel;
  final String titleHint;

  /// Путь родительских категорий: «Бронирование / Рестораны и кафе».
  final String? breadcrumbs;

  const AdvertFormConfig({
    required this.isBooking,
    required this.showPrice,
    required this.titleLabel,
    required this.titleHint,
    this.breadcrumbs,
  });

  static const AdvertFormConfig fallback = AdvertFormConfig(
    isBooking: false,
    showPrice: true,
    titleLabel: 'Заголовок объявления',
    titleHint: 'Например, уютная 2-комнатная квартира',
  );

  factory AdvertFormConfig.fromJson(Map<String, dynamic> json) {
    String text(String key, String orElse) {
      final v = json[key]?.toString().trim() ?? '';
      return v.isEmpty ? orElse : v;
    }

    final crumbs = json['breadcrumbs']?.toString().trim() ?? '';

    return AdvertFormConfig(
      isBooking: json['is_booking'] == true,
      showPrice: json['price'] != false,
      titleLabel: text('title_label', fallback.titleLabel),
      titleHint: text('title_hint', fallback.titleHint),
      breadcrumbs: crumbs.isEmpty ? null : crumbs,
    );
  }
}
