/// Тексты блока брони (22.09.2026).
///
/// Приложение говорит «Записаться» и «Сколько длится приём»: это верно для
/// мастеров и врачей, но у ресторана бронируют столик. Сервер присылает свои
/// тексты для таких категорий: в форме подачи блоком `form.booking_labels`,
/// гостю полем `labels` в свободном времени объявления. Не прислал, значит
/// действуют обычные ([BookingLabels.standard]).
class BookingLabels {
  /// Заголовок блока в карточке объявления.
  final String bookTitle;

  /// Кнопка в карточке, `{time}` заменяется временем.
  final String bookButton;

  /// Заголовок экрана подтверждения.
  final String confirmTitle;

  /// Подсказка владельцу под переключателем брони.
  final String ownerHint;

  /// Подпись под «По часам».
  final String slotsSubtitle;

  /// «Сколько длится приём».
  final String durationTitle;

  /// «Перерыв между записями».
  final String bufferTitle;

  const BookingLabels({
    required this.bookTitle,
    required this.bookButton,
    required this.confirmTitle,
    required this.ownerHint,
    required this.slotsSubtitle,
    required this.durationTitle,
    required this.bufferTitle,
  });

  static const BookingLabels standard = BookingLabels(
    bookTitle: 'Записаться',
    bookButton: 'Записаться на {time}',
    confirmTitle: 'Подтверждение записи',
    ownerHint:
        'В объявлении появится календарь свободного времени и кнопка «Записаться».',
    slotsSubtitle: 'Приём, просмотр, занятие',
    durationTitle: 'Сколько длится приём',
    bufferTitle: 'Перерыв между записями',
  );

  /// Пустые и отсутствующие поля берём из [standard]: сервер может прислать
  /// не всё, и падать или показывать пустоту из-за этого нельзя.
  static BookingLabels fromJson(dynamic json) {
    if (json is! Map) return standard;

    String text(String key, String orElse) {
      final v = json[key]?.toString().trim() ?? '';
      return v.isEmpty ? orElse : v;
    }

    return BookingLabels(
      bookTitle: text('book_title', standard.bookTitle),
      bookButton: text('book_button', standard.bookButton),
      confirmTitle: text('confirm_title', standard.confirmTitle),
      ownerHint: text('owner_hint', standard.ownerHint),
      slotsSubtitle: text('slots_subtitle', standard.slotsSubtitle),
      durationTitle: text('duration_title', standard.durationTitle),
      bufferTitle: text('buffer_title', standard.bufferTitle),
    );
  }

  String button(String time) => bookButton.replaceAll('{time}', time);
}
