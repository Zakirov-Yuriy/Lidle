import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/home_models.dart';
import 'package:lidle/pages/bookings/preorder_catalog_screen.dart';
import 'package:lidle/pages/bookings/table_booking_screen.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/bookings/booking_calendar_dialog.dart';
import 'package:lidle/widgets/components/header.dart';

/// Бронь столика по схеме зала (29.09.2026).
///
/// Человек выбирает дату, время и стол ПАЛЬЦЕМ на плане, а не доверяет
/// подбору: в ресторане место у окна и место у кухни это разные вещи.
///
/// Занятость считается на выбранный слот, а не на день: в семь вечера стол
/// занят, в девять свободен. Поэтому схема перечитывается при каждой смене
/// времени, и до выбора времени столы не показываются доступными — иначе
/// человек ткнёт в стол и получит отказ уже на подтверждении.
class HallBookingScreen extends StatefulWidget {
  static const String routeName = '/booking-hall';

  const HallBookingScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.hall,
    required this.halls,
    this.maxGuests,
    this.listing,
  });

  final int advertId;
  final String advertTitle;
  final BookingHall hall;

  /// Все залы объявления: по ним работает «Сменить».
  final List<BookingHall> halls;

  final int? maxGuests;

  /// Объявление, из карточки которого пришли: по названию сверху человек
  /// открывает его и смотрит фотографии, описание и отзывы (29.09.2026).
  final Listing? listing;

  @override
  State<HallBookingScreen> createState() => _HallBookingScreenState();
}

class _HallBookingScreenState extends State<HallBookingScreen> {
  late BookingHall _hall = widget.hall;

  DateTime _date = DateTime.now();

  BookingAvailability? _availability;
  BookingDay? _day;
  BookingSlot? _slot;

  List<BookingHallTable> _tables = const [];
  String? _tableKey;

  bool _isLoadingDay = true;
  bool _isLoadingTables = false;

  /// Зал закрыт в выбранное время: столы рисуем, но занять нельзя.
  bool _isWorking = true;

  /// Грузим меню для заказа навынос (29.09.2026): между нажатием кнопки и
  /// открытием витрины есть запрос, и второе нажатие открыло бы её дважды.
  bool _takeawayLoading = false;

  @override
  void initState() {
    super.initState();
    _tables = _hall.layout;
    _loadDay();
  }

  /// Слоты выбранного дня.
  Future<void> _loadDay() async {
    setState(() {
      _isLoadingDay = true;
      _slot = null;
      _tableKey = null;
    });

    final data = await BookingsService.availability(
      widget.advertId,
      from: _date,
      to: _date,
      hallId: _hall.id,
    );

    if (!mounted) return;

    final day = data?.days.where((d) => _sameDate(d.date, _date)).firstOrNull;

    setState(() {
      _availability = data;
      _day = day;
      _isLoadingDay = false;
      _tables = _hall.layout;
    });
  }

  /// Столы на выбранное время.
  Future<void> _loadTables(BookingSlot slot) async {
    setState(() {
      _isLoadingTables = true;
      _tableKey = null;
    });

    final state = await BookingsService.hallTables(
      advertId: widget.advertId,
      hallId: _hall.id,
      startsAt: slot.startsAtRaw,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingTables = false;

      // Не дозвонились: схему прежнего времени показывать нельзя, она уже
      // про другое время.
      _tables = state?.tables ?? const [];
      _isWorking = state?.isWorking ?? true;

      if (state?.hall != null) {
        _hall = state!.hall!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            _backRow(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _titleRow(),
                  const SizedBox(height: 10),
                  _hallRow(),
                  const SizedBox(height: 12),
                  ..._hall.lines.map(_line),
                  const SizedBox(height: 10),
                  _dateRow(),
                  const SizedBox(height: 12),
                  _changeDateButton(),
                  const SizedBox(height: 16),
                  _slots(),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF2C3A47), height: 1),
                  const SizedBox(height: 16),
                  _plan(),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFF2C3A47), height: 1),
                  const SizedBox(height: 16),
                  _yourBooking(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new, color: activeIconColor, size: 16),
            SizedBox(width: 4),
            Text('Назад', style: TextStyle(color: activeIconColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  /// Название заведения ведёт в само объявление: фотографии, описание,
  /// контакты и отзывы живут там (29.09.2026).
  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openAdvert,
        child: Row(
          children: [
            Flexible(
              child: Text(
                widget.advertTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.listing != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, color: textSecondary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _openAdvert() {
    final listing = widget.listing;

    if (listing == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniPropertyDetailsScreen(listing: listing),
      ),
    );
  }

  /// Название зала и «Сменить»: второе показываем, только если залов правда
  /// несколько, иначе кнопка вела бы в список из одного пункта.
  Widget _hallRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _hall.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (widget.halls.length > 1)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _changeHall,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Сменить', style: TextStyle(color: activeIconColor, fontSize: 15)),
                SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios, color: activeIconColor, size: 13),
              ],
            ),
          ),
      ],
    );
  }

  Widget _line(BookingHallLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${line.title}: ',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            TextSpan(
              text: line.value,
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow() {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Дата бронирования: ',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          TextSpan(
            text: _ddmmyyyy(_date),
            style: const TextStyle(color: textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _changeDateButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: activeIconColor),
          minimumSize: const Size.fromHeight(46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _pickDate,
        child: const Text(
          'Сменить дату',
          style: TextStyle(color: activeIconColor, fontSize: 16),
        ),
      ),
    );
  }

  Widget _slots() {
    if (_isLoadingDay) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: CircularProgressIndicator(color: activeIconColor),
        ),
      );
    }

    final day = _day;

    if (day == null || !day.isWorking || day.slots.isEmpty) {
      return const Text(
        'В этот день зал не работает. Выберите другую дату.',
        style: TextStyle(color: textSecondary, fontSize: 14),
      );
    }

    final now = DateTime.now();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final slot in day.slots)
          _SlotChip(
            text: '${_hhmm(slot.startsAt)} - ${_hhmm(slot.endsAt)}',
            state: slot.startsAt.isBefore(now)
                ? _SlotState.past
                : (_slot == slot
                    ? _SlotState.picked
                    : (slot.isFree ? _SlotState.free : _SlotState.taken)),
            onTap: slot.isFree && !slot.startsAt.isBefore(now)
                ? () {
                    setState(() => _slot = slot);
                    _loadTables(slot);
                  }
                : null,
          ),
      ],
    );
  }

  Widget _plan() {
    if (!_hall.hasLayout) {
      return const Text(
        'Схему зала здесь пока не расставили. Столик подберёт заведение.',
        style: TextStyle(color: textSecondary, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);

              return Stack(
                children: [
                  Positioned.fill(child: _PlanImage(hall: _hall)),
                  for (final table in _tables)
                    Positioned(
                      left: table.x * size.width - 22,
                      top: table.y * size.height - 22,
                      child: _TableMark(
                        table: table,
                        // До выбора времени занятость неизвестна: столы
                        // показываем спокойным цветом и не даём нажать.
                        pickable: _slot != null && _isWorking && table.isFree,
                        selected: table.key == _tableKey,
                        unknown: _slot == null,
                        onTap: () => _pickTable(table),
                      ),
                    ),
                  if (_isLoadingTables)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x88121A22),
                        child: Center(
                          child: CircularProgressIndicator(color: activeIconColor),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _slot == null
              ? 'Выберите время, и на схеме станет видно, какие столики свободны.'
              : (_isWorking
                  ? 'Красный столик занят, зелёный вы выбрали.'
                  : 'В это время зал не работает.'),
          style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _yourBooking() {
    final table = _tables.where((t) => t.key == _tableKey).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ваша бронь',
          style: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (table == null)
          const Text(
            'Столик пока не выбран.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          )
        else
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_hall.name}: ',
                        style: const TextStyle(color: textSecondary, fontSize: 14),
                      ),
                      TextSpan(
                        text: 'Столик № ${table.number}',
                        style: const TextStyle(color: textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: textSecondary),
                onPressed: () => setState(() => _tableKey = null),
              ),
            ],
          ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: table == null ? textMuted : const Color(0xFF3ECF6E),
              ),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: table == null ? null : () => _goToConfirm(table),
            child: Text(
              'Перейти к бронированию',
              style: TextStyle(
                color: table == null ? textMuted : const Color(0xFF3ECF6E),
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Заказ навынос (29.09.2026): столик не нужен, нужно только время, к
        // которому заказ будет готов. Поэтому кнопка живёт, даже когда стол не
        // выбран, и гаснет только без выбранного времени.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              // Закрытый зал заказ навынос тоже не примет: готовить некому.
              side: BorderSide(color: _canTakeaway ? activeIconColor : textMuted),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _canTakeaway ? _goToTakeaway : null,
            child: _takeawayLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: activeIconColor,
                    ),
                  )
                : Text(
                    'Сделать заказ на самовывоз',
                    style: TextStyle(
                      color: _canTakeaway ? activeIconColor : textMuted,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _pickTable(BookingHallTable table) {
    if (_slot == null) {
      SnackBarHelper.showWarning(context, 'Сначала выберите время');

      return;
    }

    if (!_isWorking) {
      SnackBarHelper.showWarning(context, 'В это время зал не работает');

      return;
    }

    if (!table.isFree) {
      SnackBarHelper.showWarning(context, 'Этот столик уже занят');

      return;
    }

    setState(() => _tableKey = table.key == _tableKey ? null : table.key);
  }

  Future<void> _changeHall() async {
    final picked = await showModalBottomSheet<BookingHall>(
      context: context,
      backgroundColor: formBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Выберите зал',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final hall in widget.halls)
              ListTile(
                title: Text(
                  hall.name,
                  style: TextStyle(
                    color: hall.id == _hall.id ? activeIconColor : textPrimary,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(hall),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked.id == _hall.id) return;

    setState(() {
      _hall = picked;
      _tables = picked.layout;
      _tableKey = null;
    });

    await _loadDay();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    // Свой календарь вместо системного (29.09.2026): тот показывал английские
    // дни недели и светлую вёрстку, и выглядел чужим на тёмном экране.
    final picked = await showBookingDatePicker(
      context,
      initial: _date.isBefore(now) ? now : _date,
      first: DateTime(now.year, now.month, now.day),
      // Дальше горизонта объявления бронировать всё равно нельзя, а
      // календарь без края выглядит как обещание.
      // Столько же, сколько просит календарь в карточке: дальше сервер всё
      // равно обрежет по горизонту объявления.
      last: now.add(const Duration(days: 62)),
      title: 'Дата бронирования',
    );

    if (picked == null) return;

    setState(() => _date = picked);

    await _loadDay();
  }

  Future<void> _goToConfirm(BookingHallTable table) async {
    final slot = _slot;

    if (slot == null) return;

    final token = await TokenService.getCurrentToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы забронировать столик',
      );

      return;
    }

    // Сначала карточка стола (29.09.2026): там человек видит, что именно ему
    // достанется, и собирает предзаказ. Подтверждение брони открывается уже
    // оттуда.
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TableBookingScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          hall: _hall,
          table: table,
          startsAt: slot.startsAt,
          endsAt: slot.endsAt,
          startsAtRaw: slot.startsAtRaw,
          endsAtRaw: slot.endsAtRaw,
          needsConfirmation: _availability?.needsConfirmation ?? false,
          // За столиком не больше, чем он вмещает: число гостей человек
          // указывает на подтверждении.
          maxGuests: table.seats > 0 ? table.seats : widget.maxGuests,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.of(context).pop(true);

      return;
    }

    // Время или стол заняли, пока человек заполнял форму: перечитываем день,
    // чтобы он выбирал из свежего.
    if (result == false) {
      await _loadDay();
    }
  }

  /// Можно ли заказать навынос: нужно выбранное время в рабочие часы. Стол
  /// при этом не нужен (29.09.2026).
  bool get _canTakeaway => _slot != null && _isWorking;

  /// Заказ навынос (29.09.2026).
  ///
  /// Сначала меню, потом карточка заказа: человек нажал «на самовывоз», то
  /// есть уже решил, что хочет еду. Показывать ему сперва пустую карточку с
  /// «Столик не выбран» значит заставить сделать лишний шаг ради того, за чем
  /// он и пришёл.
  ///
  /// Ушёл с витрины назад — возвращаемся к залу, карточку не открываем.
  Future<void> _goToTakeaway() async {
    final slot = _slot;

    if (slot == null || _takeawayLoading) return;

    final token = await TokenService.getCurrentToken();

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      SnackBarHelper.showAuthRequired(
        context,
        'Войдите в профиль, чтобы сделать заказ',
      );

      return;
    }

    setState(() => _takeawayLoading = true);

    // Корзина могла остаться от другого заведения: там своё меню.
    if (PreorderService.isForeign(widget.advertId)) PreorderService.forget();

    final blocks = await PreorderService.catalog(widget.advertId);

    await PreorderService.load(widget.advertId, hallId: _hall.id);

    if (!mounted) return;

    setState(() => _takeawayLoading = false);

    // Меню вперёд всего: за ним и пришли. Нет меню — открываем то, что у
    // заведения вообще есть, а нет ничего — сразу карточку заказа.
    final kind = blocks.any((b) => b.kind == 'menu')
        ? 'menu'
        : (blocks.isEmpty ? null : blocks.first.kind);

    if (kind != null) {
      final added = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PreorderCatalogScreen(
            advertId: widget.advertId,
            advertTitle: widget.advertTitle,
            kind: kind,
            blocks: blocks.where((b) => b.kind == kind).toList(),
            hallId: _hall.id,
            isTakeaway: true,
          ),
        ),
      );

      if (!mounted || added != true) return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TableBookingScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          hall: _hall,
          isTakeaway: true,
          startsAt: slot.startsAt,
          endsAt: slot.endsAt,
          startsAtRaw: slot.startsAtRaw,
          endsAtRaw: slot.endsAtRaw,
          needsConfirmation: _availability?.needsConfirmation ?? false,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      Navigator.of(context).pop(true);

      return;
    }

    if (result == false) {
      await _loadDay();
    }
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _two(int v) => v.toString().padLeft(2, '0');

  static String _hhmm(DateTime v) => '${_two(v.hour)}:${_two(v.minute)}';

  static String _ddmmyyyy(DateTime v) =>
      '${_two(v.day)}.${_two(v.month)}.${v.year}';
}

enum _SlotState { free, taken, picked, past }

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final _SlotState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _SlotState.picked => const Color(0xFF3ECF6E),
      _SlotState.taken => const Color(0xFFE05A6B),
      _SlotState.past => textMuted,
      _SlotState.free => textPrimary,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 14)),
      ),
    );
  }
}

/// План зала как фон схемы. Нет картинки (или это PDF) — ровный фон: столы
/// всё равно стоят по своим местам, и выбрать их можно.
class _PlanImage extends StatelessWidget {
  const _PlanImage({required this.hall});

  final BookingHall hall;

  @override
  Widget build(BuildContext context) {
    final url = hall.planImageUrl;

    final empty = Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    if (url == null) return empty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => empty,
      ),
    );
  }
}

/// Столик на схеме: номер и места, цвет по состоянию.
class _TableMark extends StatelessWidget {
  const _TableMark({
    required this.table,
    required this.pickable,
    required this.selected,
    required this.unknown,
    required this.onTap,
  });

  final BookingHallTable table;
  final bool pickable;
  final bool selected;

  /// Время ещё не выбрано: занятость неизвестна.
  final bool unknown;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF3ECF6E)
        : (unknown
            ? textSecondary
            : (table.isFree ? textPrimary : const Color(0xFFE05A6B)));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x333ECF6E)
              : (!unknown && !table.isFree
                  ? const Color(0x33E05A6B)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              table.number,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (table.seats > 0)
              Text(
                '${table.seats}',
                style: TextStyle(color: color, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}
