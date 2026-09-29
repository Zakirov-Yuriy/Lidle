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

  // ── Слова про единицу и место (29.09.2026) ──────────────────────
  //
  // Механика у ресторана и барбершопа одна, а слова разные: там столик,
  // здесь кресло. Род меняет всё предложение, поэтому сервер присылает
  // фразы целиком, а не одно слово для подстановки.

  /// «Выберите зал» / «Выберите зону».
  final String unitPick;

  /// «Сменить зал».
  final String unitChange;

  /// Название единицы, когда своего у неё нет: «Зал», «Зона».
  final String unitFallback;

  /// «Выбрать столик на схеме» / «Выбрать кресло на схеме».
  final String seatPick;

  /// «Столик № :number» / «Кресло № :number».
  final String seatTitle;

  /// «Столик не выбран» / «Кресло не выбрано».
  final String seatNone;

  /// «Депозит за столик» / «Депозит за кресло».
  final String seatDeposit;

  /// «Этот столик уже занят» / «Это кресло уже занято».
  final String seatBusy;

  /// «Перейти к бронированию» / «Перейти к записи».
  final String bookingGo;

  /// Предлагать ли заказ навынос (29.09.2026).
  ///
  /// Это ресторанная вещь: из барбершопа еду не забирают, а товары человек и
  /// так заберёт, когда придёт стричься.
  final bool hasTakeaway;

  /// Спрашивать ли число гостей. В барбершоп приходят по одному, и поле
  /// «Количество гостей» там выглядит ошибкой.
  final bool hasGuests;

  const BookingLabels({
    required this.bookTitle,
    required this.bookButton,
    required this.confirmTitle,
    required this.ownerHint,
    required this.slotsSubtitle,
    required this.durationTitle,
    required this.bufferTitle,
    this.unitPick = 'Выберите зону',
    this.unitChange = 'Сменить зону',
    this.unitFallback = 'Зона',
    this.seatPick = 'Выбрать место на схеме',
    this.seatTitle = 'Место № :number',
    this.seatNone = 'Место не выбрано',
    this.seatDeposit = 'Депозит за место',
    this.seatBusy = 'Это место уже занято',
    this.bookingGo = 'Перейти к записи',
    this.hasTakeaway = false,
    this.hasGuests = false,
  });

  /// Номер места в подпись: «Столик № 5».
  String seat(String number) => seatTitle.replaceAll(':number', number);

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

    bool flag(String key, bool orElse) {
      final v = json[key];

      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v == '1' || v.toLowerCase() == 'true';

      return orElse;
    }

    return BookingLabels(
      bookTitle: text('book_title', standard.bookTitle),
      bookButton: text('book_button', standard.bookButton),
      confirmTitle: text('confirm_title', standard.confirmTitle),
      ownerHint: text('owner_hint', standard.ownerHint),
      slotsSubtitle: text('slots_subtitle', standard.slotsSubtitle),
      durationTitle: text('duration_title', standard.durationTitle),
      bufferTitle: text('buffer_title', standard.bufferTitle),
      unitPick: text('unit_pick', standard.unitPick),
      unitChange: text('unit_change', standard.unitChange),
      unitFallback: text('unit_fallback', standard.unitFallback),
      seatPick: text('seat_pick', standard.seatPick),
      seatTitle: text('seat_title', standard.seatTitle),
      seatNone: text('seat_none', standard.seatNone),
      seatDeposit: text('seat_deposit', standard.seatDeposit),
      seatBusy: text('seat_busy', standard.seatBusy),
      bookingGo: text('booking_go', standard.bookingGo),
      hasTakeaway: flag('has_takeaway', standard.hasTakeaway),
      hasGuests: flag('has_guests', standard.hasGuests),
    );
  }

  String button(String time) => bookButton.replaceAll('{time}', time);
}
