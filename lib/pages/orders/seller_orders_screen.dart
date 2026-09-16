// ============================================================
// "Экран: Заказы ко мне (продавец)"
// ============================================================
//
// Заказы на товары, которые покупатели сделали у этого продавца. Раньше
// попасть сюда можно было только по пушу или через «Мои покупки», а пункт в
// кабинете был закомментирован, потому что вёл в никуда (16.09.2026).
//
// Вкладки названы как на макете заказчика: Новые, Исполняемые, Выполняемые,
// Отклонённые. За ними стоят статусы сервера: исполняемые это принятые и
// готовые к выдаче, отклонённые это отмены обеих сторон.
//
// Бронирование объявлений сюда не попадает: это другая ветка и другой экран
// («Заявки ко мне»).

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/order_item.dart';
import 'package:lidle/pages/orders/order_accept_screen.dart';
import 'package:lidle/services/orders_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class SellerOrdersScreen extends StatefulWidget {
  static const routeName = '/seller-orders';

  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

/// Вкладка экрана: ключ для сервера и подпись для человека.
class _Tab {
  final String key;
  final String title;

  /// Показывать ли фильтр по году и месяцу. Нужен там, где заказы копятся.
  final bool withPeriod;

  const _Tab(this.key, this.title, {this.withPeriod = false});
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const List<_Tab> _tabs = [
    _Tab('new', 'Новые'),
    _Tab('in_work', 'Исполняемые'),
    _Tab('done', 'Выполняемые', withPeriod: true),
    _Tab('rejected', 'Отклонённые', withPeriod: true),
  ];

  int _tabIndex = 0;

  List<OrderModel> _orders = const [];
  OrderCounts _counts = const OrderCounts();

  bool _isLoading = true;

  /// Раскрытые карточки. Раскрытие показывает телефон, адрес и код заказа.
  final Set<int> _expanded = {};

  int? _year;
  int? _month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  _Tab get _tab => _tabs[_tabIndex];

  Future<void> _load() async {
    setState(() => _isLoading = true);

    // Числа на вкладках и список тянем параллельно: числа нужны сразу на всех
    // вкладках, а список только на текущей.
    final results = await Future.wait([
      OrdersService.incoming(
        tab: _tab.key,
        all: true,
        year: _tab.withPeriod ? _year : null,
        month: _tab.withPeriod ? _month : null,
      ),
      OrdersService.counts(),
    ]);

    if (!mounted) return;

    setState(() {
      _orders = results[0] as List<OrderModel>;
      _counts = results[1] as OrderCounts;
      _isLoading = false;
    });
  }

  int _countFor(String key) => switch (key) {
        'new' => _counts.newOrders,
        'in_work' => _counts.inWork,
        'done' => _counts.done,
        'rejected' => _counts.rejected,
        _ => 0,
      };

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
            _tabsRow(),
            if (_tab.withPeriod) _periodRow(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _backRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          const Text(
            'Заказы',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabsRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final selected = index == _tabIndex;
          final count = _countFor(tab.key);

          return GestureDetector(
            onTap: selected
                ? null
                : () {
                    setState(() {
                      _tabIndex = index;
                      _expanded.clear();
                    });

                    _load();
                  },
            behavior: HitTestBehavior.opaque,
            // IntrinsicWidth задаёт колонке ширину самого широкого ребёнка, то
            // есть ширину текста вкладки. Подчёркивание растягивается на всю
            // эту ширину и меняется вместе с надписью: «Новые 6» шире, чем
            // «Новые», «Исполняемые» шире их обоих. Фиксированной ширины тут
            // быть не может, названия вкладок разной длины.
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    count > 0 ? '${tab.title} $count' : tab.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? activeIconColor : textMuted,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2,
                    color: selected ? activeIconColor : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Год и месяц. Без них человек листает всю историю разом.
  Widget _periodRow() {
    final now = DateTime.now();
    final years = [now.year - 1, now.year];

    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _chip('Все', _year == null, () {
                setState(() {
                  _year = null;
                  _month = null;
                });
                _load();
              }),
              const SizedBox(width: 16),
              ...years.map((year) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _chip('$year', _year == year, () {
                      setState(() => _year = year);
                      _load();
                    }),
                  )),
            ],
          ),
          if (_year != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: months.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _chip(
                  months[index],
                  _month == index + 1,
                  () {
                    setState(() => _month = _month == index + 1 ? null : index + 1);
                    _load();
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? activeIconColor : textMuted,
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: activeIconColor));
    }

    if (_orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            switch (_tab.key) {
              'new' => 'Новых заказов нет.',
              'in_work' => 'В работе сейчас ничего нет.',
              'done' => 'Выполненных заказов за этот период нет.',
              _ => 'Отклонённых заказов за этот период нет.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: textMuted, fontSize: 15),
          ),
        ),
      );
    }

    // Карточка на КАЖДЫЙ товар, а не на заказ (16.09.2026).
    //
    // Заказ собирается из корзины, и в нём легко оказывается два-три товара
    // одной точки. Одной кнопкой на весь заказ продавец либо обещал то, чего
    // у него нет, либо отказывал вместе с тем, что есть. Номер заказа и код
    // получения при этом общие: забирают всё за один поход.
    final cards = <Widget>[];

    for (final order in _orders) {
      for (final line in order.items) {
        cards.add(_card(order, line));
      }
    }

    return RefreshIndicator(
      color: activeIconColor,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(25, 12, 25, 24),
        children: cards,
      ),
    );
  }

  Widget _card(OrderModel order, OrderLine line) {
    final expanded = _expanded.contains(order.id);

    // Цвет заголовка говорит о состоянии: отклонённый красным, выполненный
    // зелёным, остальные обычным. Это с макета, и это единственное место, где
    // состояние видно без чтения.
    final titleColor = order.isCancelled
        ? const Color(0xFFE5484D)
        : order.status == 'completed'
            ? const Color(0xFF3BA55D)
            : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Заказ №${order.number}',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _date(order.createdAt),
                style: const TextStyle(color: textSecondary, fontSize: 14),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  expanded ? _expanded.remove(order.id) : _expanded.add(order.id);
                }),
                child: Icon(
                  expanded ? Icons.keyboard_arrow_down : Icons.arrow_back_ios,
                  color: Colors.white,
                  size: expanded ? 22 : 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _line('Заказчик:', order.contactName ?? '—'),
          _line('Доставка:', order.deliveryTitle ?? 'Самовывоз'),

          // Цену доставки показываем только там, где она есть. У самовывоза
          // это всегда ноль, и строка «Цена доставки: 0.00 ₽» ничего не
          // сообщает, зато добавляет в карточку ещё одно число.
          if (order.isCourier) _line('Цена доставки:', _rub(order.deliveryPrice)),
          _line('Оплата:', order.paymentMethodTitle ?? '—'),
          const SizedBox(height: 10),
          _item(line),
          if (line.isRejected)
            Text(
              line.rejectReason == null || line.rejectReason!.isEmpty
                  ? 'Товар отклонён и вернулся в продажу'
                  : 'Отклонён: ${line.rejectReason}',
              style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13),
            )
          else if (!line.isPending)
            Text(
              line.statusTitle,
              style: const TextStyle(color: Color(0xFF3BA55D), fontSize: 13),
            ),
          if (expanded) ..._details(order, line),

          // Решение по ЭТОМУ товару. Пока заказ живой и по товару ещё не
          // решали.
          if (order.isAlive && line.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _button(
                    'Отклонить',
                    const Color(0xFFE5484D),
                    () => _rejectItem(order, line),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _button(
                    'Принять',
                    activeIconColor,
                    () => _acceptItem(order, line),
                  ),
                ),
              ],
            ),
          ],
          if (order.isAlive && !line.isPending) ...[
            const SizedBox(height: 14),
            _button('Открыть заказ', activeIconColor, () => _openAccept(order)),
          ],
        ],
      ),
    );
  }

  /// Раскрытая часть карточки: то, что нужно при сборке и выдаче.
  ///
  /// Деньги здесь показываются по ЭТОМУ товару, а не по всему заказу. Карточка
  /// одна на позицию, и «Итого» от всего заказа под одним товаром читалось как
  /// его цена: под ветровкой за 9118 стояло 11118, потому что во втором
  /// товаре того же заказа лежало ещё 2000. Итог по заказу остался, но только
  /// когда товаров действительно несколько, и подписан числом товаров.
  List<Widget> _details(OrderModel order, OrderLine line) {
    final many = order.items.length > 1;

    return [
      const SizedBox(height: 10),
      const Divider(color: Colors.white12, height: 1),
      const SizedBox(height: 10),
      _line('Телефон:', order.contactPhone ?? '—'),
      if (order.isCourier) _line('Адрес:', order.deliveryAddress ?? '—'),
      if (order.isCourier && (order.deliveryComment ?? '').isNotEmpty)
        _line('Комментарий:', order.deliveryComment!),
      if (order.isCourier)
        _line('Курьер:', order.courierName ?? 'не назначен'),
      if ((order.comment ?? '').isNotEmpty) _line('От покупателя:', order.comment!),
      if ((order.cancelReason ?? '').isNotEmpty)
        _line('Причина отказа:', order.cancelReason!),
      const SizedBox(height: 10),
      _money('Сумма товара', _rub(line.sum), big: true),
      if (many) ...[
        const SizedBox(height: 6),
        _money(
          'Весь заказ, ${_goods(order.items.length)}',
          _rub(order.total),
        ),
      ],
      if (order.isCourier) ...[
        const SizedBox(height: 6),
        _money('С доставкой', _rub(_withDelivery(order))),
      ],
      if (order.isAlive && (order.pickupCode ?? '').isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Код заказа',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            Text(
              order.pickupCode!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _item(OrderLine line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: line.image == null
                ? Container(width: 64, height: 64, color: secondaryBackground)
                : Image.network(
                    line.image!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(width: 64, height: 64, color: secondaryBackground),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название в две строки с многоточием. Без ограничения оно
                // упиралось в цену справа и слипалось с ней: «Куртки осень,
                // Красный, Рост 86 см5000.0 ₽».
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if ((line.sku ?? '').isNotEmpty)
                  Text(
                    'Артикул: ${line.sku}',
                    style: const TextStyle(color: textMuted, fontSize: 12),
                  ),
                Text(
                  '${line.quantity} шт',
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _rub(line.sum),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Деньги одним видом во всей карточке: «5 000 ₽», а не «5000.0 ₽».
  ///
  /// Сервер присылает числа как есть, и в интерфейс они попадали сырыми:
  /// у товара «5000.0», у доставки «800.00». Копейки показываем только когда
  /// они не нулевые, иначе в списке рябит от нулей.
  String _rub(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}') ?? 0;

    final whole = number.truncate().abs();
    final kopeks = ((number.abs() - whole) * 100).round();

    final digits = whole.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final sign = number < 0 ? '-' : '';
    final tail = kopeks == 0
        ? ''
        : ',${kopeks.toString().padLeft(2, '0')}';

    return '$sign$buffer$tail ₽';
  }

  /// Строка с деньгами. Главная в карточке одна: сумма этого товара.
  Widget _money(String label, String value, {bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: big ? Colors.white : textSecondary,
            fontSize: big ? 16 : 14,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// «2 товара», «5 товаров». Без этого пришлось бы писать «товар(ов)».
  String _goods(int count) {
    final last = count % 10;
    final hundred = count % 100;

    if (hundred >= 11 && hundred <= 14) return '$count товаров';
    if (last == 1) return '$count товар';
    if (last >= 2 && last <= 4) return '$count товара';

    return '$count товаров';
  }

  /// Сумма заказа вместе с доставкой. Доставка в `total` не входит намеренно:
  /// товар могут снять с заказа, и тогда сумма товаров меняется, а везти всё
  /// равно надо. Складываем только для показа.
  String _withDelivery(OrderModel order) {
    final total = double.tryParse(order.total) ?? 0;
    final delivery = double.tryParse(order.deliveryPrice) ?? 0;
    final sum = total + delivery;

    return sum == sum.roundToDouble()
        ? sum.toStringAsFixed(0)
        : sum.toStringAsFixed(2);
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 15)),
      ),
    );
  }

  Future<void> _openAccept(OrderModel order) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => OrderAcceptScreen(order: order)),
    );

    if (changed == true) _load();
  }

  Future<void> _acceptItem(OrderModel order, OrderLine line) async {
    final result = await OrdersService.acceptItem(order.id, line.id);

    if (!mounted) return;

    if (result.isOk) {
      SnackBarHelper.showSuccess(context, result.message);
      _load();

      return;
    }

    SnackBarHelper.showError(context, result.message);
  }

  /// Отказ от ОДНОГО товара.
  ///
  /// На макете окно называется «Удаление заказа», но удаления здесь нет и
  /// быть не должно: товар возвращается в продажу и уходит из суммы заказа, а
  /// остальное продавец собирает. Заказ целиком отменяется только тогда,
  /// когда отклонили всё (16.09.2026).
  Future<void> _rejectItem(OrderModel order, OrderLine line) async {
    final last = order.items.where((item) => item.isPending).length == 1
        && order.items.where((item) => item.status == 'accepted').isEmpty;

    // Диалог возвращает причину: пустая строка это «отклонить без причины»,
    // null это отмена. Причину видит покупатель, и без неё отказ выглядит
    // молчаливым: товар исчез, объяснений нет.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(last: last),
    );

    if (reason == null || !mounted) return;

    final result = await OrdersService.rejectItem(
      order.id,
      line.id,
      reason: reason.isEmpty ? null : reason,
    );

    if (!mounted) return;

    if (result.isOk) {
      SnackBarHelper.showSuccess(context, result.message);
      _load();

      return;
    }

    SnackBarHelper.showError(context, result.message);
  }

  String _date(DateTime? value) {
    if (value == null) return '';

    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }
}

/// Диалог отказа от позиции с полем причины.
///
/// Отдельным виджетом, а не куском в `showDialog`, ровно по той же причине,
/// по которой мы чинили экран смены почты: контроллер поля должен принадлежать
/// состоянию самого диалога и умирать вместе с ним. Контроллер, заведённый
/// снаружи, переживает закрытие и однажды роняет экран.
class _RejectDialog extends StatefulWidget {
  /// Это последняя ждущая позиция: отказ отменит весь заказ.
  final bool last;

  const _RejectDialog({required this.last});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: formBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Отклонить товар',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.last
                ? 'Это последний товар в заказе. Если отклонить его, заказ '
                    'отменится целиком, товар вернётся в продажу, покупатель '
                    'получит уведомление.'
                : 'Товар вернётся в продажу и уйдёт из суммы заказа. Остальное '
                    'останется в работе, покупатель получит уведомление. '
                    'Отменить отказ будет нельзя.',
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Причина, например «нет на складе»',
              hintStyle: TextStyle(color: textMuted, fontSize: 14),
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: activeIconColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Причину увидит покупатель. Можно оставить пустой.',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена', style: TextStyle(color: textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text.trim()),
          child: const Text(
            'Отклонить',
            style: TextStyle(color: Color(0xFFE5484D)),
          ),
        ),
      ],
    );
  }
}
