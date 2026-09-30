import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/pages/bookings/booking_flow.dart';
import 'package:lidle/models/bookings/booking_labels.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/pages/bookings/my_bookings_screen.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/services/bookings_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:url_launcher/url_launcher.dart';

/// Порядок блоков предзаказа на счёте, как на макете (29.09.2026).
const List<String> _preorderOrder = ['menu', 'product', 'service', 'delivery'];

/// Заголовок блока и ссылка возврата к витрине.
const Map<String, List<String>> _preorderWords = {
  'menu': ['Предзаказ меню', 'Перейти в меню'],
  'product': ['Добавить товар', 'Перейти в товар'],
  'service': ['Добавить услугу', 'Перейти в услугу'],
  'delivery': ['Добавить доставку', 'Перейти в доставку'],
};

/// Цена без лишних нулей: 755, а не 755.00.
String _money(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();

  return value.toStringAsFixed(2);
}

/// Экран подтверждения записи: показывает выбранное время, спрашивает имя,
/// телефон и комментарий, отправляет бронь.
///
/// Бронь создана — экран сам открывает «Мои брони» на ней и убирает из
/// стопки экраны выбора зала, времени и стола (30.09.2026): возвращаться к
/// ним незачем, а в списке человек видит состав заказа, сумму и реквизиты
/// заведения.
///
/// В остальных случаях возвращает через Navigator.pop:
///   false — время заняли, пока человек заполнял форму (409), календарь надо
///           перечитать, а экран мы закрываем, чтобы человек выбрал другое
///           время из свежих данных;
///   null  — просто ушли назад, ничего не изменилось.
class BookingConfirmScreen extends StatefulWidget {
  final int advertId;
  final String advertTitle;
  /// Для показа: время по часам мастера.
  final DateTime startsAt;
  final DateTime endsAt;

  /// Для отправки: строки сервера как есть, со смещением.
  final String startsAtRaw;
  final String endsAtRaw;

  final bool needsConfirmation;
  final int? maxGuests;

  /// Заголовок экрана: «Подтверждение записи» или, у ресторана,
  /// «Подтверждение брони» (22.09.2026).
  final String title;

  /// Ресторан с залами (22.09.2026): зал, банкет, число гостей (уже выбрано
  /// в карточке) и подпись «Основной зал, столик».
  final int? hallId;
  final bool wholeHall;
  final int? fixedGuests;
  final String? place;

  /// Стол, выбранный гостем на схеме зала (28.09.2026). Пусто — сервер
  /// подберёт столик сам.
  final String? tableKey;

  /// Стол и его депозит (29.09.2026): нужны для счёта. Пусто у записи на
  /// услугу и у банкета — там счёта нет вовсе.
  final String? tableNumber;
  final int? tableSeats;
  final double deposit;

  /// Заказ навынос (29.09.2026): столика нет, но предзаказ и счёт есть.
  final bool isTakeaway;

  /// Слова по роду заведения (29.09.2026): столик, кресло или место.
  final BookingLabels labels;

  /// Названия блоков из админки по роду (29.09.2026): «Предзаказ меню»,
  /// «Добавить товар». Пусто — берём своё слово.
  final Map<String, String> blockTitles;

  const BookingConfirmScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.startsAt,
    required this.endsAt,
    required this.startsAtRaw,
    required this.endsAtRaw,
    required this.needsConfirmation,
    this.title = 'Подтверждение записи',
    this.hallId,
    this.wholeHall = false,
    this.fixedGuests,
    this.place,
    this.tableKey,
    this.maxGuests,
    this.tableNumber,
    this.tableSeats,
    this.deposit = 0,
    this.isTakeaway = false,
    this.labels = BookingLabels.standard,
    this.blockTitles = const {},
  });

  @override
  State<BookingConfirmScreen> createState() => _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends State<BookingConfirmScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentController = TextEditingController();

  int _guests = 1;

  /// Гостей выбрали руками: до этого в поле стоит «Выбрать» (29.09.2026).
  bool _guestsPicked = false;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  /// Имя и телефон подставляем из профиля: человек уже вошёл, спрашивать его
  /// же данные заново невежливо. Поля остаются редактируемыми, записаться
  /// можно и не на себя.
  Future<void> _prefillFromProfile() async {
    try {
      final token = await TokenService.getCurrentToken();
      if (token == null || token.isEmpty) return;

      final profile = await UserService.getProfile(token: token);
      if (!mounted) return;

      setState(() {
        if (_nameController.text.isEmpty) {
          _nameController.text = profile.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = profile.phone ?? '';
        }
      });
    } catch (_) {
      // Профиль не обязателен: поля просто останутся пустыми.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) return;

    // Сколько человек придёт, заведению важно: стол на четверых и стол на
    // двоих это разные столы. Молча отправлять одного гостя, когда в поле
    // стоит «Выбрать», нечестно (29.09.2026).
    if (_asksGuests && !_guestsPicked) {
      SnackBarHelper.showWarning(context, 'Выберите количество гостей');

      return;
    }

    setState(() => _isSending = true);

    final result = await BookingsService.create(
      advertId: widget.advertId,
      startsAt: widget.startsAtRaw,
      endsAt: widget.endsAtRaw,
      guestsCount: widget.fixedGuests ??
          (widget.maxGuests == null ? null : _guests),
      hallId: widget.hallId,
      wholeHall: widget.wholeHall,
      tableKey: widget.tableKey,
      isTakeaway: widget.isTakeaway,
      comment: _commentController.text,
      contactName: _nameController.text,
      contactPhone: _phoneController.text,
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    switch (result.kind) {
      case BookingResultKind.created:
        // Корзина уехала в бронь: сервер пометил её строки номером брони, и
        // держать их в памяти дальше нельзя — иначе следующая бронь показала
        // бы уже заказанное (29.09.2026).
        PreorderService.forget();

        // Календарь в карточке объявления остаётся в стопке под нами, и сам
        // об этой брони не узнает (30.09.2026).
        BookingsService.notifyChanged();

        SnackBarHelper.showSuccess(
          context,
          result.needsOwnerAnswer
              ? 'Заявка отправлена, ждём ответа владельца'
              : 'Время забронировано',
        );

        // Сразу открываем «Мои брони» на только что созданной броне
        // (30.09.2026). Там человек видит состав заказа, сумму и реквизиты
        // заведения: после «Забронировать» это и есть его следующий шаг.
        //
        // Из стопки убираем только шаги самой брони: выбор зала, времени,
        // стола, витрину и корзину. Карточка объявления и лента, из которой
        // человек пришёл, остаются, и «Назад» возвращает туда, а не на
        // главный экран.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => MyBookingsScreen(highlightId: result.id),
          ),
          (route) => route.settings.name != kBookingStepRoute,
        );
        break;

      case BookingResultKind.conflict:
        // Не вина человека: пока он заполнял форму, время заняли. Уводим
        // назад к свежему календарю вместо того, чтобы держать его на форме
        // с уже невозможным временем.
        // Сообщение сервера точнее нашего: он знает, заняли время целиком
        // или один столик, и называет место словами заведения (30.09.2026).
        SnackBarHelper.showWarning(
          context,
          result.message.trim().isEmpty
              ? 'Это время только что заняли. Выберите другое, календарь обновлён.'
              : result.message,
        );
        Navigator.pop(context, false);
        break;

      case BookingResultKind.rejected:
        SnackBarHelper.showError(context, result.message);
        break;
    }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Назад',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Отказаться от брони целиком, а не вернуться на шаг назад
                  // (29.09.2026): «Назад» ведёт к столу, эта кнопка уводит с
                  // всего пути к схеме зала.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelBooking,
                    child: Text(
                      widget.isTakeaway
                          ? 'Отмена заказа'
                          : (widget.tableKey != null ? 'Отмена брони' : 'Отмена записи'),
                      style: const TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                children: [
                  // const SizedBox(height: 12),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(),
                  // Предзаказ и счёт (29.09.2026). Показываем до полей: человек
                  // сначала смотрит, за что платит, и только потом называется.
                  //
                  // Только у брони стола: корзина общая на приложение, и на
                  // записи к мастеру остаток ресторанной корзины был бы здесь
                  // совершенно некстати.
                  if (widget.tableKey != null || widget.isTakeaway)
                  ValueListenableBuilder<PreorderCart>(
                    valueListenable: PreorderService.cart,
                    builder: (_, cart, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final kind in _preorderOrder)
                          if (cart.ofKind(kind).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildPreorderBlock(kind, cart.ofKind(kind)),
                          ],
                        if (widget.tableNumber != null) ...[
                          const SizedBox(height: 12),
                          _buildTableCard(),
                        ],
                        if (!cart.isEmpty || widget.deposit > 0) ...[
                          const SizedBox(height: 12),
                          _buildBasket(cart),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Ваше имя',
                    controller: _nameController,
                    hint: 'Введите',
                  ),
                  if (_asksGuests) ...[
                    const SizedBox(height: 12),
                    _buildGuestsPicker(),
                  ],
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Номер телефона',
                    controller: _phoneController,
                    hint: 'Введите',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    label: 'Комментарий, необязательно',
                    controller: _commentController,
                    hint: 'Что важно знать заранее',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  _buildTermsNote(),
                  // Строка «Время закрепится за вами сразу после отправки»
                  // убрана (29.09.2026): под кнопкой уже стоит согласие, и
                  // два пояснения подряд читаются как оправдание.
                  //
                  // Про ожидание ответа владельца говорим по-прежнему: это не
                  // пояснение, а условие, которое меняет дело.
                  if (widget.needsConfirmation) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Владелец подтвердит запись. Пока он не ответил, время держится за вами.',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.advertTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (widget.place != null) ...[
            Row(
              children: [
                const Icon(Icons.table_restaurant, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.fixedGuests == null
                        ? widget.place!
                        : '${widget.place!}, гостей: ${widget.fixedGuests}',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Запись на услугу укладывается в один день, и её показываем как
          // «дата, с и до». Жильё занимает несколько суток, и та же подпись
          // выглядела бы как «с 14:00 до 11:00», то есть задом наперёд.
          if (_isSameDay) ...[
            Row(
              children: [
                const Icon(Icons.event, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  _humanDate(widget.startsAt),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_time(widget.startsAt)} — ${_time(widget.endsAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.login, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Заезд ${_humanDate(widget.startsAt)}, с ${_time(widget.startsAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.logout, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Выезд ${_humanDate(widget.endsAt)}, до ${_time(widget.endsAt)}',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.nightlight_round, color: activeIconColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  _nightsLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Предзаказ одного рода: что человек набрал и куда вернуться, если передумал.
  Widget _buildPreorderBlock(String kind, List<PreorderLine> lines) {
    final words = _preorderWords[kind] ?? const ['Предзаказ', 'Перейти'];

    // Название из админки, если оно есть: на всех экранах блок называется
    // одинаково (29.09.2026).
    final title = (widget.blockTitles[kind] ?? '').isNotEmpty
        ? widget.blockTitles[kind]!
        : words[0];

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ваш предзаказ:',
            style: TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${line.name}: ${line.quantity}шт',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _dropLine(line),
                    child: const Icon(Icons.close, color: textSecondary, size: 18),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Возврат на карточку стола: витрина открывается оттуда, и второй
            // путь к тому же экрану только запутал бы.
            onTap: () => Navigator.pop(context),
            child: Text(
              words[1],
              style: const TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// «Бронирование столик № 5»: что именно забронировано.
  Widget _buildTableCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Бронирование: ${widget.labels.seat('${widget.tableNumber}')}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.tableSeats != null && widget.tableSeats! > 0)
            _line('Количество мест', '${widget.tableSeats}'),
          _line('Дата бронирования', _humanDate(widget.startsAt)),
          _line(
            'Время бронирования',
            '${_time(widget.startsAt)}-${_time(widget.endsAt)}',
          ),
          if (widget.deposit > 0)
            _line(widget.labels.seatDeposit, '${_money(widget.deposit)} ₽'),
        ],
      ),
    );
  }

  /// «Ваша корзина»: строки предзаказа и всё, что войдёт в счёт.
  Widget _buildBasket(PreorderCart cart) {
    final totals = cart.totals;

    // Депозит знаем и сами: сервер считает его только когда корзину просили
    // вместе со столом.
    final deposit = totals.depositAmount > 0 ? totals.depositAmount : widget.deposit;
    final total = totals.itemsTotal + deposit + totals.feeAmount;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваша корзина',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in cart.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${line.quantity}шт',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '${_money(line.sum)}₽',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (cart.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Divider(color: Color(0xFF2C3A48), height: 1),
            const SizedBox(height: 8),
          ],
          if (deposit > 0) _line(widget.labels.seatDeposit, '${_money(deposit)} ₽'),
          if (totals.feeAmount > 0)
            _line('Оплата за услугу бронирования', '${_money(totals.feeAmount)} ₽'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Итог к оплате:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_money(total)} ₽',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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

  Widget _line(String title, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
      );

  Future<void> _dropLine(PreorderLine line) async {
    final error = await PreorderService.setQuantity(
      widget.advertId,
      lineId: line.id,
      quantity: 0,
      hallId: widget.hallId,
      tableKey: widget.tableKey,
    );

    if (!mounted || error == null) return;

    SnackBarHelper.showWarning(context, error);
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: textMuted, fontSize: 15),
            filled: true,
            fillColor: formBackground,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  /// Количество гостей: окном со списком, как на макете заказчика. Больше,
  /// чем помещается за стол, выбрать нельзя.
  Widget _buildGuestsPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Количество гостей',
          style: TextStyle(color: textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickGuests,
          child: Container(
            height: 47,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _guestsPicked ? _guestsWord(_guests) : 'Выбрать',
                    style: TextStyle(
                      color: _guestsPicked ? Colors.white : textMuted,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickGuests() async {
    final maxGuests = widget.maxGuests ?? 1;
    int chosen = _guests;

    final picked = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => Dialog(
          backgroundColor: formBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Количество гостей',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: textSecondary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (var i = 1; i <= maxGuests; i++)
                          InkWell(
                            onTap: () => setLocal(() => chosen = i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _guestsWord(i),
                                      style: const TextStyle(color: Colors.white, fontSize: 15),
                                    ),
                                  ),
                                  Icon(
                                    i == chosen
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: i == chosen ? activeIconColor : textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена', style: TextStyle(color: textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: activeIconColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context, chosen),
                      child: const Text('Готово', style: TextStyle(color: activeIconColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _guests = picked;
      _guestsPicked = true;
    });
  }

  String _guestsWord(int count) {
    final last = count % 10;
    final lastTwo = count % 100;

    if (last == 1 && lastTwo != 11) return '$count гость';
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) return '$count гостя';

    return '$count гостей';
  }

  /// Согласие под кнопкой (29.09.2026).
  ///
  /// Ссылки те же, что при регистрации: документы лежат на lidle.ru, и второй
  /// набор адресов однажды разошёлся бы с первым.
  Widget _buildTermsNote() {
    return ValueListenableBuilder<PreorderCart>(
      valueListenable: PreorderService.cart,
      builder: (_, __, ___) => RichText(
        text: TextSpan(
          text: 'Нажимая на кнопку «$_buttonTitle», вы соглашаетесь с ',
          style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.35),
          children: [
            TextSpan(
              text: 'политикой конфиденциальности',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF38BDF8),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openURL('https://lidle.ru/documents/privacy-policy.pdf'),
            ),
            const TextSpan(text: ' и '),
            TextSpan(
              text: 'нашими правилами',
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF38BDF8),
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _openURL('https://lidle.ru/documents/user-agreement.pdf'),
            ),
          ],
        ),
      ),
    );
  }

  /// Открыть правовой документ во внешнем браузере, как на регистрации.
  Future<void> _openURL(String urlString) async {
    try {
      final url = Uri.parse(urlString);

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);

        return;
      }

      if (mounted) SnackBarHelper.showWarning(context, 'Не удалось открыть ссылку');
    } catch (_) {
      if (mounted) SnackBarHelper.showWarning(context, 'Не удалось открыть ссылку');
    }
  }

  /// «Отмена брони»: уходим со всего пути выбора стола к схеме зала. Бронь
  /// ещё не создана, отменять на сервере нечего, а набранное остаётся в
  /// корзине — человек мог передумать про время, а не про заказ.
  void _cancelBooking() => Navigator.pop(context, false);

  Widget _buildSubmitButton() {
    // Слушаем корзину: убрали позицию крестиком — подпись кнопки должна
    // поменяться вместе со счётом.
    return ValueListenableBuilder<PreorderCart>(
      valueListenable: PreorderService.cart,
      builder: (_, __, ___) => _submitButton(),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: activeIconColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: _isSending ? null : _submit,
        child: _isSending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _buttonTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Спрашиваем ли число гостей (29.09.2026).
  ///
  /// Только там, где приходят компанией: в ресторане за столиком, но не в
  /// барбершопе, куда человек идёт один. Признак приходит с сервера вместе со
  /// словами по роду заведения.
  bool get _asksGuests =>
      widget.labels.hasGuests && widget.maxGuests != null && widget.fixedGuests == null;

  /// Что написано на кнопке.
  ///
  /// «Внести депозит» — когда за бронь действительно есть что платить. Сама
  /// оплата ещё не подключена: кнопка создаёт бронь, а счёт человек видит
  /// выше, чтобы знать, сколько с него возьмут.
  String get _buttonTitle {
    if (widget.needsConfirmation) return 'Отправить заявку';

    final totals = PreorderService.cart.value.totals;
    final hasBill = widget.deposit > 0 || totals.itemsTotal > 0 || totals.feeAmount > 0;

    return hasBill ? 'Внести депозит' : 'Забронировать';
  }

  /// Уложилась ли бронь в один день. У записи на услугу да, у жилья нет.
  bool get _isSameDay =>
      widget.startsAt.year == widget.endsAt.year &&
      widget.startsAt.month == widget.endsAt.month &&
      widget.startsAt.day == widget.endsAt.day;

  String get _nightsLabel {
    final nights = DateTime(widget.endsAt.year, widget.endsAt.month, widget.endsAt.day)
        .difference(DateTime(
          widget.startsAt.year,
          widget.startsAt.month,
          widget.startsAt.day,
        ))
        .inDays;

    final last = nights % 10;
    final lastTwo = nights % 100;

    if (last == 1 && lastTwo != 11) return '$nights ночь';
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
      return '$nights ночи';
    }
    return '$nights ночей';
  }

  String _time(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _humanDate(DateTime date) {
    const months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${date.day} ${months[(date.month - 1).clamp(0, 11)]}';
  }
}
