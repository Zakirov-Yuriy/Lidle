// ============================================================
// "Виджет: Экран выбора доставки службой"
// ============================================================
//
// Задача 53, этап 5, 19.11.2026.
//
// Покупатель выбирает город, видит цены и сроки служб, которые подключил
// продавец, и выбирает пункт выдачи. Выбор возвращается на экран оформления.
//
// ПОРЯДОК ШАГОВ ДИКТУЮТ САМИ СЛУЖБЫ: город, потом способ, потом пункт
// выдачи, и только потом цена.
//
// Так приходится делать из-за Яндекса: он считает цену ТОЛЬКО когда уже
// известен конкретный пункт выдачи, а СДЭК считает по городу. Если сначала
// показывать цены, как напрашивается, Яндекс не посчитает никогда и просто
// не появится в списке. Поймано на проверке 19.11.2026.
//
// Для доставки до двери пункт не нужен, там после адреса сразу цены.
//
// ЦЕНА ЗДЕСЬ ДЛЯ ПОКАЗА. При оформлении сервер спросит службу заново: цена
// могла измениться, пока человек выбирал.
//
// ПУСТОТА ОБЪЯСНЯЕТСЯ СЛОВАМИ. Продавец мог не подключить службы, а служба
// может не возить в этот город. Молчаливый пустой список выглядит поломкой.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lidle/services/delivery_quotes_service.dart';
import 'package:lidle/widgets/components/header.dart';

/// Что человек выбрал: служба, тариф, куда везти и сколько это стоит.
class DeliveryServiceChoice {
  const DeliveryServiceChoice({
    required this.quote,
    required this.cityCode,
    required this.cityName,
    this.point,
    this.address,
  });

  final DeliveryQuote quote;
  final String cityCode;
  final String cityName;

  /// Пункт выдачи. Пусто, когда везут до двери.
  final DeliveryPoint? point;

  /// Адрес, когда везут до двери.
  final String? address;

  double get price => quote.price;

  /// Строка для экрана оформления: куда именно повезут.
  String get whereTitle {
    if (point != null) {
      return '${point!.providerTitle}, пункт выдачи: ${point!.address}';
    }

    if ((address ?? '').isNotEmpty) return 'По адресу: $address';

    return cityName;
  }
}

class DeliveryServiceScreen extends StatefulWidget {
  const DeliveryServiceScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.weight = 1000,
    this.initial,
  });

  final int shopId;
  final String shopName;

  /// Вес посылки в граммах. Пока килограмм по умолчанию: габариты товаров
  /// заполняют единицы продавцов, а требовать их от всех значит убить
  /// расчёт совсем.
  final int weight;

  /// Прежний выбор, если человек вернулся поправить.
  final DeliveryServiceChoice? initial;

  @override
  State<DeliveryServiceScreen> createState() => _DeliveryServiceScreenState();
}

class _DeliveryServiceScreenState extends State<DeliveryServiceScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  final TextEditingController _cityController = TextEditingController();

  /// Отложенный поиск города: человек печатает быстрее, чем отвечает служба,
  /// и запрос на каждую букву это и лишняя нагрузка, и мигающий список.
  Timer? _cityTimer;

  List<DeliveryCity> _cities = const [];
  bool _citiesLoading = false;

  DeliveryCity? _city;

  /// Способ: в пункт выдачи или до двери. Пусто, пока не выбран.
  bool? _toDoor;

  List<DeliveryQuote> _quotes = const [];
  String? _quotesMessage;
  bool _quotesLoading = false;

  DeliveryQuote? _quote;

  List<DeliveryPoint> _points = const [];
  bool _pointsLoading = false;

  DeliveryPoint? _point;

  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final was = widget.initial;

    if (was != null) {
      _city = DeliveryCity(code: was.cityCode, name: was.cityName);
      _cityController.text = was.cityName;
      _point = was.point;
      _toDoor = was.quote.toDoor;
      _addressController.text = was.address ?? '';

      if (was.quote.toDoor) {
        unawaited(_loadQuotes(keep: was.quote));
      } else {
        unawaited(_loadPoints().then((_) => _loadQuotes(keep: was.quote)));
      }
    }
  }

  @override
  void dispose() {
    _cityTimer?.cancel();
    _cityController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  // ── Данные ─────────────────────────────────────────────────────────

  void _onCityTyped(String value) {
    _cityTimer?.cancel();

    if (value.trim().length < 2) {
      setState(() => _cities = const []);

      return;
    }

    _cityTimer = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _citiesLoading = true);

      final found = await DeliveryQuotesService.cities(
        shopId: widget.shopId,
        query: value,
      );

      if (!mounted) return;

      setState(() {
        _cities = found;
        _citiesLoading = false;
      });
    });
  }

  Future<void> _pickCity(DeliveryCity city) async {
    setState(() {
      _city = city;
      _cityController.text = city.name;
      _cities = const [];

      // Город сменился, значит прежние цены и пункт уже не про этот заказ.
      _quote = null;
      _point = null;
      _points = const [];
      _quotes = const [];
      _quotesMessage = null;
    });

    if (_toDoor == true) {
      await _loadQuotes();
    } else if (_toDoor == false) {
      await _loadPoints();
    }
  }

  /// Выбрать способ: в пункт выдачи или до двери.
  Future<void> _pickWay(bool toDoor) async {
    setState(() {
      _toDoor = toDoor;
      _quote = null;
      _point = null;
      _quotes = const [];
      _quotesMessage = null;
    });

    if (toDoor) {
      await _loadQuotes();
    } else {
      await _loadPoints();
    }
  }

  Future<void> _loadQuotes({DeliveryQuote? keep}) async {
    final city = _city;

    if (city == null) return;

    setState(() {
      _quotesLoading = true;
      _quotesMessage = null;
    });

    final answer = await DeliveryQuotesService.quote(
      shopId: widget.shopId,
      cityCode: city.code,
      city: city.name,
      // Пункт выдачи передаём обязательно, если он уже выбран: Яндекс без
      // него цену не считает вовсе.
      pointCode: _point?.code,
      weight: widget.weight,
    );

    if (!mounted) return;

    // Оставляем только то, что подходит выбранному способу, и, если пункт
    // уже выбран, только службу этого пункта: везти в пункт Яндекса тарифом
    // СДЭК нельзя, а список из обеих служб выглядел бы так, будто можно.
    final podhodyashchie = answer.quotes.where((q) {
      if (_toDoor != null && q.toDoor != _toDoor) return false;

      final point = _point;

      if (point != null && q.provider != point.provider) return false;

      return true;
    }).toList();

    setState(() {
      _quotes = podhodyashchie;
      _quotesMessage = answer.message;
      _quotesLoading = false;

      // Возвращаем прежний выбор, если он ещё есть в списке. Если службы
      // его больше не дают, человек увидит пустой выбор и выберет заново:
      // подставлять похожий тариф молча нельзя.
      if (keep != null) {
        for (final quote in podhodyashchie) {
          if (quote.provider == keep.provider && quote.code == keep.code) {
            _quote = quote;

            break;
          }
        }
      }
    });

    if (_quote != null && !_quote!.toDoor) {
      await _loadPoints();
    }
  }

  void _pickQuote(DeliveryQuote quote) {
    setState(() => _quote = quote);
  }

  /// Выбрали пункт: теперь можно спросить цену. Для Яндекса это
  /// единственный момент, когда он вообще считает.
  Future<void> _pickPoint(DeliveryPoint point) async {
    setState(() {
      _point = point;
      _quote = null;
    });

    await _loadQuotes();
  }

  Future<void> _loadPoints() async {
    final city = _city;

    if (city == null) return;

    setState(() => _pointsLoading = true);

    // Пункты ВСЕХ служб продавца сразу: человек выбирает удобный адрес, а
    // не службу. Какая служба повезёт, выяснится из цены следующим шагом.
    final found = await DeliveryQuotesService.points(
      shopId: widget.shopId,
      cityCode: city.code,
      city: city.name,
    );

    if (!mounted) return;

    setState(() {
      _points = found;
      _pointsLoading = false;
    });
  }

  bool get _ready {
    final quote = _quote;

    if (_city == null || quote == null) return false;

    if (quote.toDoor) return _addressController.text.trim().isNotEmpty;

    return _point != null;
  }

  void _done() {
    final city = _city;
    final quote = _quote;

    if (city == null || quote == null) return;

    Navigator.pop(
      context,
      DeliveryServiceChoice(
        quote: quote,
        cityCode: city.code,
        cityName: city.name,
        point: quote.toDoor ? null : _point,
        address: quote.toDoor ? _addressController.text.trim() : null,
      ),
    );
  }

  // ── Экран ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20, right: 23),
              child: Row(children: [Header()]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Доставка',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 16, 25, 24),
                children: [
                  Text(
                    'Заказ из «${widget.shopName}» повезёт служба доставки. '
                    'Укажите город, и мы покажем цены и сроки.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _cityBlock(),
                  if (_city != null) ...[
                    const SizedBox(height: 20),
                    _wayBlock(),
                  ],
                  if (_toDoor == false) ...[
                    const SizedBox(height: 20),
                    _pointsBlock(),
                  ],
                  if (_toDoor == true) ...[
                    const SizedBox(height: 20),
                    _addressBlock(),
                  ],
                  // Цены показываем последними: Яндекс считает их только
                  // после выбора пункта выдачи.
                  if (_toDoor == true || _point != null) ...[
                    const SizedBox(height: 20),
                    _quotesBlock(),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready ? _done : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    disabledBackgroundColor: cardColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _ready ? 'Выбрать' : 'Выберите доставку',
                    style: TextStyle(
                      color: _ready ? Colors.white : textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cityBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Город доставки',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cityController,
            onChanged: _onCityTyped,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Начните вводить название',
              hintStyle: const TextStyle(color: textSecondary),
              filled: true,
              fillColor: bgColor,
              suffixIcon: _citiesLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accentColor,
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          for (final city in _cities)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                city.full,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () => _pickCity(city),
            ),
        ],
      ),
    );
  }

  /// Как получать: в пункте выдачи или дома.
  ///
  /// СПРАШИВАЕМ ДО ЦЕН, потому что Яндекс считает цену только для
  /// конкретного пункта. Заодно так понятнее человеку: он думает «заберу
  /// сам» или «пусть привезут», а не кодами тарифов.
  Widget _wayBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как получить',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 4),
          _radioRow(
            selected: _toDoor == false,
            title: 'В пункте выдачи',
            hint: 'Заберёте сами, обычно дешевле',
            onTap: () => _pickWay(false),
          ),
          _radioRow(
            selected: _toDoor == true,
            title: 'Курьером до двери',
            hint: 'Привезут по вашему адресу',
            onTap: () => _pickWay(true),
          ),
        ],
      ),
    );
  }

  Widget _quotesBlock() {
    if (_quotesLoading) return _loader('Спрашиваем службы доставки');

    if (_quotes.isEmpty) {
      return _card(
        child: Text(
          _quotesMessage ??
              (_point != null
                  ? 'Служба не посчитала доставку в этот пункт. Выберите '
                      'другой пункт выдачи.'
                  : 'Для этого города доставки нет. Попробуйте другой город '
                      'или выберите самовывоз.'),
          style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Цена и срок',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 4),
          for (final quote in _quotes)
            _radioRow(
              selected: _quote?.provider == quote.provider &&
                  _quote?.code == quote.code,
              title: '${quote.providerTitle}, ${quote.title}',
              hint: [
                '${quote.price.toStringAsFixed(0)} ₽',
                if (quote.daysTitle.isNotEmpty) quote.daysTitle,
                quote.toDoor ? 'до двери' : 'до пункта выдачи',
              ].join(' · '),
              onTap: () => _pickQuote(quote),
            ),
        ],
      ),
    );
  }

  Widget _pointsBlock() {
    if (_pointsLoading) return _loader('Загружаем пункты выдачи');

    if (_points.isEmpty) {
      return _card(
        child: const Text(
          'В этом городе у службы нет пунктов выдачи. Выберите другой способ '
          'доставки.',
          style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Пункт выдачи, всего ${_points.length}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 4),

          // Показываем первые двадцать: их бывают сотни, а карты у нас пока
          // нет. Остальные ищутся полем ниже.
          for (final point in _points.take(20))
            _radioRow(
              selected: _point?.code == point.code,
              title: point.address.isEmpty ? point.code : point.address,
              hint: [
                if (point.providerTitle.isNotEmpty) point.providerTitle,
                if (point.workTime.isNotEmpty) point.workTime,
                if (point.card) 'можно картой',
              ].join(' · '),
              onTap: () => _pickPoint(point),
            ),
          if (_points.length > 20)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Показаны первые 20 пунктов. Уточните город, если нужного нет.',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addressBlock() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Адрес доставки',
            style: TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Улица, дом, квартира',
              hintStyle: const TextStyle(color: textSecondary),
              filled: true,
              fillColor: bgColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Мелочи ─────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _loader(String text) {
    return _card(
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _radioRow({
    required bool selected,
    required String title,
    required String hint,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accentColor : textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: const TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
