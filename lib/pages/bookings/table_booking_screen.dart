// ============================================================
//  Карточка выбранного стола (29.09.2026)
// ============================================================
//
// Путь гостя по макетам заказчика:
//
//   схема зала → выбрал стол и время → «Перейти к бронированию» → ЭТОТ экран:
//   какой стол достался, на какое время, депозит и что важно знать о столе.
//   Ниже блоки «Добавить меню / товар / услугу / доставку»: человек заранее
//   собирает, что его ждёт за столом.
//   «Забронировать» → подтверждение брони, где виден весь счёт.
//
// Блоки показываются только те, которые заведение действительно завело: если
// меню нет, обещать «Перейти в меню» нечестно.
//
// Набранное живёт на сервере (`PreorderService`), поэтому экран не копит
// состояние у себя: он показывает корзину, которую вернул сервер.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/bookings/booking_labels.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/pages/bookings/booking_confirm_screen.dart';
import 'package:lidle/pages/bookings/preorder_catalog_screen.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Подписи блока по роду: заголовок, подсказка и ссылка.
const Map<String, List<String>> _blockWords = {
  'menu': [
    'Добавить меню',
    'Вы можете заранее заказать блюда к вашему визиту',
    'Перейти в меню',
  ],
  'product': [
    'Добавить товар',
    'Вы можете заранее заказать товар к вашему визиту',
    'Перейти в товар',
  ],
  'service': [
    'Добавить услугу',
    'Вы можете заранее заказать услугу к вашему визиту',
    'Перейти в услугу',
  ],
  'delivery': [
    'Добавить доставку',
    'Вы можете заранее выбрать доставку или самовывоз',
    'Перейти в доставку',
  ],
};

/// Порядок блоков на экране, как на макете.
const List<String> _blockOrder = ['menu', 'product', 'service', 'delivery'];

class TableBookingScreen extends StatefulWidget {
  const TableBookingScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.hall,
    this.table,
    this.isTakeaway = false,
    this.labels = BookingLabels.standard,
    this.photos = const [],
    required this.startsAt,
    required this.endsAt,
    required this.startsAtRaw,
    required this.endsAtRaw,
    required this.needsConfirmation,
    this.maxGuests,
  });

  final int advertId;
  final String advertTitle;
  final BookingHall hall;

  /// Выбранный стол. Пусто у заказа навынос (29.09.2026): человек забирает
  /// еду сам, и садиться ему некуда.
  final BookingHallTable? table;

  /// Заказ навынос: столик не бронируется, депозита нет, вместо «Важно!»
  /// заведения стоит объяснение, что будет дальше.
  final bool isTakeaway;

  /// Слова по роду заведения (29.09.2026): столик, кресло или место.
  final BookingLabels labels;

  /// Фотографии объявления (29.09.2026). Показываются, когда у зала нет
  /// плана: пустой серый прямоугольник наверху экрана выглядит поломкой, а
  /// фотографии заведения человек уже видел в карточке и узнаёт.
  final List<String> photos;

  /// Для показа — время по часам заведения, для отправки — строки сервера.
  final DateTime startsAt;
  final DateTime endsAt;
  final String startsAtRaw;
  final String endsAtRaw;

  final bool needsConfirmation;
  final int? maxGuests;

  @override
  State<TableBookingScreen> createState() => _TableBookingScreenState();
}

class _TableBookingScreenState extends State<TableBookingScreen> {
  List<PreorderBlock> _blocks = const [];
  bool _loading = true;

  /// Листалка фотографий наверху экрана и точка под ней.
  final PageController _photos = PageController();
  int _photo = 0;

  @override
  void dispose() {
    _photos.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Корзина могла остаться от другого заведения: там своё меню, и показывать
    // его здесь нельзя.
    if (PreorderService.isForeign(widget.advertId)) PreorderService.forget();

    final blocks = await PreorderService.catalog(widget.advertId);

    await PreorderService.load(
      widget.advertId,
      hallId: widget.hall.id,
      tableKey: widget.table?.key,
    );

    if (!mounted) return;

    setState(() {
      _blocks = blocks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            _topRow(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: activeIconColor))
                  : ValueListenableBuilder<PreorderCart>(
                      valueListenable: PreorderService.cart,
                      builder: (_, cart, __) => ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        children: [
                          _plan(),
                          const SizedBox(height: 14),
                          _tableCard(),
                          const SizedBox(height: 12),
                          _deposit(),
                          if (_noteText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _note(),
                          ],
                          for (final kind in _blockOrder)
                            if (_blocksOf(kind).isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _block(kind, cart.ofKind(kind)),
                            ],
                        ],
                      ),
                    ),
            ),
            _bookButton(),
          ],
        ),
      ),
    );
  }

  Widget _topRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios, color: activeIconColor, size: 15),
                Text('Назад', style: TextStyle(color: activeIconColor, fontSize: 16)),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cancel,
            child: Text(
              widget.isTakeaway ? 'Отмена заказа' : 'Отмена брони',
              style: const TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  /// Что показать наверху экрана.
  ///
  /// Сначала план зала: он отвечает на вопрос «где это место». Плана нет —
  /// фотографии заведения: человек видел их в карточке и узнаёт. Нет и их —
  /// заглушка.
  Widget _plan() {
    final plan = widget.hall.planImageUrl;
    final photos = plan != null ? [plan] : widget.photos;

    if (photos.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Container(
            color: secondaryBackground,
            alignment: Alignment.center,
            child: const Icon(Icons.map_outlined, color: textMuted, size: 40),
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: PageView.builder(
              controller: _photos,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => _photo = index),
              itemBuilder: (_, index) => Image.network(
                photos[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: secondaryBackground,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, color: textMuted, size: 40),
                ),
              ),
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _photo ? activeIconColor : textMuted,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tableCard() {
    final table = widget.table;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.hall.name,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            table == null ? widget.labels.seatNone : widget.labels.seat(table.number),
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          // У самовывоза мест нет, но строку оставляем: так видно, что это не
          // потерялось, а именно не нужно.
          _row('Количество мест', table == null ? '-' : '${table.seats}'),
          _row('Дата бронирования', _date(widget.startsAt)),
          _row('Время бронирования', '${_time(widget.startsAt)}-${_time(widget.endsAt)}'),
        ],
      ),
    );
  }

  int get _deposedAmount => widget.table?.deposit ?? 0;

  Widget _deposit() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Депозит ',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: '(будет входить в счёт)',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _deposedAmount > 0 ? '$_deposedAmount ₽' : 'Нет',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// «Важно!»: у столика это примечание заведения, у самовывоза — что будет
  /// дальше с заказом.
  String get _noteText => widget.isTakeaway
      ? 'Вы выбрали самовывоз. По готовности вашего заказа с вами свяжется администратор.'
      : (widget.table?.note ?? '');

  Widget _note() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Важно!',
            style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _noteText,
            style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }

  /// Блок предзаказа: либо подсказка, либо набранное с крестиками.
  Widget _block(String kind, List<PreorderLine> lines) {
    final words = _blockWords[kind] ?? const ['Добавить', '', 'Перейти'];

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            words[0],
            style: const TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(
              words[1],
              style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
            )
          else ...[
            const Text(
              'Ваш предзаказ:',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            for (final line in lines) _preorderLine(line),
          ],
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openCatalog(kind),
            child: Row(
              children: [
                Text(
                  words[2],
                  style: const TextStyle(color: activeIconColor, fontSize: 14),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, color: activeIconColor, size: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preorderLine(PreorderLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: 34,
              height: 34,
              child: line.imageUrl == null
                  ? Container(
                      color: secondaryBackground,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: textMuted, size: 16),
                    )
                  : Image.network(
                      line.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: secondaryBackground,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: textMuted, size: 16),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${line.name}: ${line.quantity}шт',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.25),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: textSecondary, size: 18),
            onPressed: () => _drop(line),
          ),
        ],
      ),
    );
  }

  Widget _bookButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: activeIconColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _loading ? null : _goToConfirm,
          child: Text(
            widget.isTakeaway ? 'Оформить заказ' : 'Забронировать',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  Widget _row(String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$title: ',
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(color: textPrimary, fontSize: 14),
              ),
            ],
          ),
        ),
      );

  List<PreorderBlock> _blocksOf(String kind) =>
      _blocks.where((b) => b.kind == kind).toList();

  Future<void> _openCatalog(String kind) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreorderCatalogScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          kind: kind,
          blocks: _blocksOf(kind),
          hallId: widget.hall.id,
          tableKey: widget.table?.key,
          isTakeaway: widget.isTakeaway,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _drop(PreorderLine line) async {
    final error = await PreorderService.setQuantity(
      widget.advertId,
      lineId: line.id,
      quantity: 0,
      hallId: widget.hall.id,
      tableKey: widget.table?.key,
    );

    if (!mounted) return;

    if (error != null) SnackBarHelper.showWarning(context, error);
  }

  /// «Отмена брони»: возвращаемся к схеме зала выбирать заново. Набранное
  /// остаётся в корзине — человек мог передумать про время, а не про заказ.
  void _cancel() => Navigator.of(context).pop();

  Future<void> _goToConfirm() async {
    final table = widget.table;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          startsAt: widget.startsAt,
          endsAt: widget.endsAt,
          startsAtRaw: widget.startsAtRaw,
          endsAtRaw: widget.endsAtRaw,
          needsConfirmation: widget.needsConfirmation,
          title: widget.isTakeaway ? 'Подтверждение заказа' : 'Подтверждение брони',
          hallId: widget.hall.id,
          tableKey: widget.table?.key,
          isTakeaway: widget.isTakeaway,
          place: table == null
              ? '${widget.hall.name}, самовывоз'
              : '${widget.hall.name}, ${widget.labels.seat(table.number).toLowerCase()}',
          // За столиком не больше, чем он вмещает. У самовывоза гостей не
          // спрашивают вовсе: человек не садится.
          maxGuests: table == null
              ? null
              : (table.seats > 0 ? table.seats : widget.maxGuests),
          labels: widget.labels,
          tableNumber: table?.number,
          tableSeats: table?.seats,
          deposit: (table?.deposit ?? 0).toDouble(),
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) Navigator.of(context).pop(result);
  }

  String _date(DateTime value) =>
      '${_two(value.day)}.${_two(value.month)}.${value.year}';

  String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';

  String _two(int value) => value.toString().padLeft(2, '0');
}
