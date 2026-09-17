// ============================================================
// "Панель фильтра витрины продавца"
// ============================================================
//
// Открывается значком внутри поля поиска по магазину (17.09.2026).
//
// Блоки рисуются по ответу сервера: что у продавца есть, то и показываем.
// Пустой блок не рисуем вовсе. Из-за этого панель у продавца одежды и у
// продавца еды выглядит по-разному, и это правильно: выбор размера там, где
// размеров не бывает, только сбивает с толку.
//
// Порядок блоков закреплён и повторяет макет заказчика: магазины, тип одежды,
// цена, бренды, «С принтом», размер, оценка, цвет, доставка. Характеристики,
// которых в этом списке нет, идут следом обычными кнопками: у продавца техники
// там окажется «Разрешение экрана», и прятать её было бы неправильно.
//
// Выбор возвращается экрану целиком и только по кнопке «Принять». Применять на
// каждое касание значило бы перезапрашивать витрину по десять раз, пока человек
// размышляет.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/products/store_filters.dart';

class StoreFilterSheet extends StatefulWidget {
  final StoreFilterOptions options;
  final StoreFilterSelection selection;

  /// Перезапросить состав панели под выбранный раздел: характеристики зависят
  /// от него. Возвращает новый состав или null, если не получилось.
  final Future<StoreFilterOptions?> Function(int? categoryId) onCategoryChanged;

  const StoreFilterSheet({
    super.key,
    required this.options,
    required this.selection,
    required this.onCategoryChanged,
  });

  @override
  State<StoreFilterSheet> createState() => _StoreFilterSheetState();
}

class _StoreFilterSheetState extends State<StoreFilterSheet> {
  late StoreFilterOptions _options;
  late StoreFilterSelection _selection;

  final _priceFromController = TextEditingController();
  final _priceToController = TextEditingController();
  final _brandSearchController = TextEditingController();

  /// Развёрнутые списки и разделы: магазины, типы и бренды бывают длинными, и
  /// показывать их целиком значит утопить в них всё остальное.
  final Set<String> _expanded = <String>{};

  bool _reloading = false;

  static const int _shortListLength = 5;

  /// Потолок ползунка цены. Вилка продавца бывает бессмысленной из-за одной
  /// пробной карточки за миллиард, и тогда ползунок нельзя было бы сдвинуть.
  static const double _priceCeiling = 1000000;

  late double _priceFrom;
  late double _priceTo;

  @override
  void initState() {
    super.initState();

    _options = widget.options;
    _selection = widget.selection;

    _priceFrom = (_selection.priceMin ?? 0).clamp(0, _priceCeiling).toDouble();
    _priceTo =
        (_selection.priceMax ?? _priceCeiling).clamp(0, _priceCeiling).toDouble();

    if (_selection.priceMin != null) {
      _priceFromController.text = _money(_selection.priceMin!);
    }

    if (_selection.priceMax != null) {
      _priceToController.text = _money(_selection.priceMax!);
    }
  }

  @override
  void dispose() {
    _priceFromController.dispose();
    _priceToController.dispose();
    _brandSearchController.dispose();
    super.dispose();
  }

  static String _money(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  double? _parsePrice(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');

    if (digits.isEmpty) return null;

    return double.tryParse(digits);
  }

  Future<void> _selectCategory(int? id) async {
    setState(() {
      _selection = id == null
          ? _selection.copyWith(clearCategory: true)
          : _selection.copyWith(categoryId: id);
      _reloading = true;
    });

    final fresh = await widget.onCategoryChanged(id);

    if (!mounted) return;

    setState(() {
      _reloading = false;

      if (fresh != null) {
        _options = fresh;

        // Значения прежнего раздела к новому не относятся: оставить их значит
        // искать красный сорок шестой там, где таких признаков нет.
        _selection = _selection.copyWith(attributeValueIds: <int>{});
      }
    });
  }

  void _apply() {
    final from = _parsePrice(_priceFromController.text);
    final to = _parsePrice(_priceToController.text);

    Navigator.of(context).pop(
      _selection.copyWith(
        priceMin: from,
        clearPriceMin: from == null,
        priceMax: to,
        clearPriceMax: to == null,
      ),
    );
  }

  void _reset() {
    setState(() {
      _selection = const StoreFilterSelection();
      _priceFromController.clear();
      _priceToController.clear();
      _brandSearchController.clear();
      _priceFrom = 0;
      _priceTo = _priceCeiling;
    });
  }

  // ── Характеристики по ролям ────────────────────────────────────────────
  //
  // Сервер отдаёт их общим списком, а макет ждёт каждую на своём месте.
  // Сопоставляем по названию: другого признака у характеристики нет, а
  // заводить его в справочнике ради порядка блоков это лишняя сущность.

  StoreAttribute? _attributeByTitle(List<String> titles) {
    for (final attribute in _options.attributes) {
      final title = attribute.title.toLowerCase();

      for (final wanted in titles) {
        if (title == wanted) return attribute;
      }
    }

    return null;
  }

  StoreAttribute? get _printAttribute => _attributeByTitle(['с принтом']);
  StoreAttribute? get _sizeAttribute => _attributeByTitle(['размер']);
  StoreAttribute? get _colorAttribute => _attributeByTitle(['цвет']);

  /// Характеристики, которым не нашлось своего места в макете.
  ///
  /// «Тип одежды» сюда не попадает намеренно: он повторяет блок с разделами,
  /// который стоит выше, и два одинаковых списка на одном экране это вопрос
  /// «а чем они отличаются», на который нет ответа.
  List<StoreAttribute> get _otherAttributes {
    final taken = <int?>{
      _printAttribute?.id,
      _sizeAttribute?.id,
      _colorAttribute?.id,
    };

    return _options.attributes
        .where((a) => !taken.contains(a.id))
        .where((a) => a.title.toLowerCase() != 'тип одежды')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final brands = _visibleBrands();
    final print = _printAttribute;
    final size = _sizeAttribute;
    final color = _colorAttribute;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_options.shops.isNotEmpty)
                      _checkboxSection(
                        key: 'shops',
                        title: 'Выберите магазин',
                        options: _options.shops,
                        selected: _selection.shopIds,
                        onChanged: (ids) => setState(
                          () => _selection = _selection.copyWith(shopIds: ids),
                        ),
                      ),
                    if (_options.categories.isNotEmpty) _categoriesSection(),
                    _priceSection(),
                    if (_options.brands.isNotEmpty) _brandsSection(brands),
                    if (print != null) _printSection(print),
                    if (size != null) _chipsSection('Размер', size),
                    _ratingSection(),
                    if (color != null) _colorSection(color),
                    for (final attribute in _otherAttributes)
                      _chipsSection(attribute.title, attribute),
                    if (_options.delivery.length > 1) _deliverySection(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          const Text(
            'Фильтры',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (_reloading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // «Сбросить» стоит рядом с крестиком, а не внизу: низ занят одной
          // кнопкой «Принять», и две кнопки там путали бы, какая из них
          // закрывает панель.
          TextButton(
            onPressed: _reset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Сбросить',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Закрыть',
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    if (title.isEmpty) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _moreButton(String key, int total) {
    if (total <= _shortListLength) return const SizedBox.shrink();

    final expanded = _expanded.contains(key);

    return TextButton(
      onPressed: () => setState(() {
        if (!_expanded.remove(key)) _expanded.add(key);
      }),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        expanded ? 'Скрыть' : 'Показать ещё',
        style: const TextStyle(color: activeIconColor, fontSize: 14),
      ),
    );
  }

  /// Список с галочками.
  Widget _checkboxSection({
    required String key,
    required String title,
    required List<StoreFilterOption> options,
    required Set<int> selected,
    required ValueChanged<Set<int>> onChanged,
  }) {
    final expanded = _expanded.contains(key);
    final visible = expanded ? options : options.take(_shortListLength).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        for (final option in visible)
          InkWell(
            onTap: () {
              final next = Set<int>.from(selected);

              if (!next.remove(option.id)) next.add(option.id);

              onChanged(next);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  _box(selected.contains(option.id)),
                ],
              ),
            ),
          ),
        _moreButton(key, options.length),
      ],
    );
  }

  Widget _box(bool checked) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? activeIconColor : Colors.transparent,
        border: Border.all(
          color: checked ? activeIconColor : const Color(0xFF767676),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child:
          checked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
    );
  }

  /// Раздел выбирается один: характеристики зависят от него, и два раздела
  /// сразу означали бы два разных набора размеров на одном экране.
  Widget _categoriesSection() {
    const key = 'categories';
    final expanded = _expanded.contains(key);
    final options = _options.categories;
    final visible = expanded ? options : options.take(_shortListLength).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Тип одежды'),
        for (final option in visible)
          InkWell(
            onTap: () => _selectCategory(
              _selection.categoryId == option.id ? null : option.id,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.name,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                  _box(_selection.categoryId == option.id),
                ],
              ),
            ),
          ),
        _moreButton(key, options.length),
      ],
    );
  }

  Widget _priceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Цена'),
        Row(
          children: [
            Expanded(
              child: _priceField(_priceFromController, 'От', isFrom: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _priceField(_priceToController, 'До', isFrom: false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Ползунок и поля показывают одно и то же: двигаешь ползунок, меняются
        // числа, пишешь числа, двигается ползунок.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: activeIconColor,
            inactiveTrackColor: const Color(0xFF474747),
            thumbColor: activeIconColor,
            overlayColor: activeIconColor.withValues(alpha: 0.15),
            trackHeight: 3,
          ),
          child: RangeSlider(
            min: 0,
            max: _priceCeiling,
            values: RangeValues(
              _priceFrom.clamp(0, _priceCeiling),
              _priceTo.clamp(0, _priceCeiling),
            ),
            onChanged: (values) {
              setState(() {
                _priceFrom = values.start;
                _priceTo = values.end;

                // Ноль слева и потолок справа означают «без ограничения»:
                // поле в этом случае оставляем пустым, чтобы не отправлять
                // на сервер условие, которого человек не ставил.
                _priceFromController.text =
                    values.start <= 0 ? '' : _money(values.start.roundToDouble());
                _priceToController.text = values.end >= _priceCeiling
                    ? ''
                    : _money(values.end.roundToDouble());
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _priceField(
    TextEditingController controller,
    String hint, {
    required bool isFrom,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final parsed = _parsePrice(value);

        setState(() {
          if (isFrom) {
            _priceFrom = (parsed ?? 0).clamp(0, _priceCeiling).toDouble();

            if (_priceFrom > _priceTo) _priceTo = _priceFrom;
          } else {
            _priceTo =
                (parsed ?? _priceCeiling).clamp(0, _priceCeiling).toDouble();

            if (_priceTo < _priceFrom) _priceFrom = _priceTo;
          }
        });
      },
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        filled: true,
        fillColor: secondaryBackground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  List<StoreFilterOption> _visibleBrands() {
    final query = _brandSearchController.text.trim().toLowerCase();

    if (query.isEmpty) return _options.brands;

    return _options.brands
        .where((b) => b.name.toLowerCase().contains(query))
        .toList();
  }

  Widget _brandsSection(List<StoreFilterOption> brands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Выберите бренд'),
        TextField(
          controller: _brandSearchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Поиск',
            hintStyle: const TextStyle(color: textMuted, fontSize: 15),
            prefixIcon: const Icon(Icons.search, color: textSecondary, size: 20),
            filled: true,
            fillColor: secondaryBackground,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (brands.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Ничего не нашлось',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          )
        else
          _checkboxSection(
            key: 'brands',
            title: '',
            options: brands,
            selected: _selection.brandIds,
            onChanged: (ids) =>
                setState(() => _selection = _selection.copyWith(brandIds: ids)),
          ),
      ],
    );
  }

  /// «С принтом»: две широкие кнопки во всю ширину, как в макете.
  Widget _printSection(StoreAttribute attribute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(attribute.title),
        Row(
          children: [
            for (var i = 0; i < attribute.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _wideButton(
                  label: attribute.values[i].value,
                  selected: _selection.attributeValueIds
                      .contains(attribute.values[i].id),
                  onTap: () => _toggleValue(attribute, attribute.values[i].id),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _wideButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? activeIconColor : Colors.transparent,
          border: Border.all(
            color: selected ? activeIconColor : const Color(0xFF474747),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// Одно значение внутри характеристики.
  ///
  /// У «С принтом» и «Размера» выбор одиночный: «да» и «нет» разом бессмысленны,
  /// а два размера сразу человек всё равно не носит. У остальных значения
  /// складываются.
  void _toggleValue(StoreAttribute attribute, int valueId) {
    final next = Set<int>.from(_selection.attributeValueIds);
    final single = !attribute.isMultiple;

    if (next.contains(valueId)) {
      next.remove(valueId);
    } else {
      if (single) {
        for (final value in attribute.values) {
          next.remove(value.id);
        }
      }

      next.add(valueId);
    }

    setState(() => _selection = _selection.copyWith(attributeValueIds: next));
  }

  Widget _chipsSection(String title, StoreAttribute attribute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in attribute.values)
              _chip(
                label: value.value,
                selected: _selection.attributeValueIds.contains(value.id),
                onTap: () => _toggleValue(attribute, value.id),
              ),
          ],
        ),
      ],
    );
  }

  /// Оценка звёздами: нажал на третью, значит «от трёх и выше».
  Widget _ratingSection() {
    final current = _selection.ratingMin ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Оценка товара'),
        Row(
          children: [
            for (var star = 1; star <= 5; star++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                  () => _selection = current == star
                      ? _selection.copyWith(clearRating: true)
                      : _selection.copyWith(ratingMin: star),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    star <= current ? Icons.star : Icons.star_border,
                    color: star <= current
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF767676),
                    size: 30,
                  ),
                ),
              ),
            if (current > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  'от $current и выше',
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Цвет: квадратики, как в макете. Название сопоставляем с краской, а
  /// незнакомое показываем кнопкой с подписью, чтобы значение не пропало.
  Widget _colorSection(StoreAttribute attribute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Цвет'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final value in attribute.values)
              if (_colorByName(value.value) != null)
                GestureDetector(
                  onTap: () => _toggleValue(attribute, value.id),
                  child: Container(
                    width: 42,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _colorByName(value.value),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selection.attributeValueIds.contains(value.id)
                            ? activeIconColor
                            : const Color(0xFF474747),
                        width: _selection.attributeValueIds.contains(value.id)
                            ? 3
                            : 1,
                      ),
                    ),
                  ),
                )
              else
                _chip(
                  label: value.value,
                  selected: _selection.attributeValueIds.contains(value.id),
                  onTap: () => _toggleValue(attribute, value.id),
                ),
          ],
        ),
      ],
    );
  }

  static Color? _colorByName(String name) {
    switch (name.toLowerCase().trim()) {
      case 'чёрный':
      case 'черный':
        return const Color(0xFF111111);
      case 'белый':
        return Colors.white;
      case 'серый':
        return const Color(0xFF8A8A8A);
      case 'синий':
        return const Color(0xFF1F4FD8);
      case 'голубой':
        return const Color(0xFF4FC3F7);
      case 'красный':
        return const Color(0xFFE53935);
      case 'зелёный':
      case 'зеленый':
        return const Color(0xFF18A558);
      case 'жёлтый':
      case 'желтый':
        return const Color(0xFFFFD600);
      case 'оранжевый':
        return const Color(0xFFFF8A00);
      case 'коричневый':
        return const Color(0xFF795548);
      case 'бежевый':
        return const Color(0xFFE3D5B8);
      case 'розовый':
        return const Color(0xFFFF80AB);
      case 'фиолетовый':
        return const Color(0xFF8E44AD);
      default:
        return null;
    }
  }

  /// Доставка: сворачивающийся блок, как в макете.
  Widget _deliverySection() {
    const key = 'delivery';
    final expanded = _expanded.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (!_expanded.remove(key)) _expanded.add(key);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Доставка',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Wrap(
            spacing: 8,
            children: [
              for (final option in _options.delivery)
                _chip(
                  label: option.title,
                  selected: _selection.delivery == option.key,
                  onTap: () => setState(
                    () => _selection = _selection.delivery == option.key
                        ? _selection.copyWith(clearDelivery: true)
                        : _selection.copyWith(delivery: option.key),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeIconColor : Colors.transparent,
          border: Border.all(
            color: selected ? activeIconColor : const Color(0xFF474747),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _apply,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: activeIconColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Принять',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
