// ============================================================
// "Панель фильтра витрины продавца"
// ============================================================
//
// Открывается значком рядом с поиском по магазину (17.09.2026).
//
// Блоки рисуются по ответу сервера: что у продавца есть, то и показываем.
// Пустой блок не рисуем вовсе. Из-за этого панель у продавца одежды и у
// продавца еды выглядит по-разному, и это правильно: выбор размера там, где
// размеров не бывает, только сбивает с толку.
//
// Выбор возвращается экрану целиком, одним объектом, и только по кнопке
// «Принять». Применять на каждое касание значило бы перезапрашивать витрину
// по десять раз, пока человек размышляет.

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

  /// Развёрнутые списки: магазины, разделы и бренды бывают длинными, и
  /// показывать их целиком значит утопить в них всё остальное.
  final Set<String> _expanded = <String>{};

  bool _reloading = false;

  static const int _shortListLength = 5;

  @override
  void initState() {
    super.initState();

    _options = widget.options;
    _selection = widget.selection;

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
    final selection = _selection.copyWith(
      priceMin: _parsePrice(_priceFromController.text),
      priceMax: _parsePrice(_priceToController.text),
      clearPriceMin: _parsePrice(_priceFromController.text) == null,
      clearPriceMax: _parsePrice(_priceToController.text) == null,
    );

    Navigator.of(context).pop(selection);
  }

  void _reset() {
    setState(() {
      _selection = const StoreFilterSelection();
      _priceFromController.clear();
      _priceToController.clear();
      _brandSearchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brands = _visibleBrands();

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
                        onChanged: (ids) =>
                            setState(() => _selection = _selection.copyWith(shopIds: ids)),
                      ),
                    if (_options.categories.isNotEmpty) _categoriesSection(),
                    _priceSection(),
                    if (_options.brands.isNotEmpty) _brandsSection(brands),
                    for (final attribute in _options.attributes)
                      _attributeSection(attribute),
                    if (_options.ratings.isNotEmpty) _ratingSection(),
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
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
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
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
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

  /// Список с галочками и кнопкой «Показать ещё».
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
        if (options.length > _shortListLength)
          TextButton(
            onPressed: () => setState(() {
              if (!_expanded.remove(key)) _expanded.add(key);
            }),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              expanded ? 'Скрыть' : 'Показать ещё',
              style: const TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
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
      child: checked
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }

  /// Раздел выбирается один: характеристики зависят от него, и два раздела
  /// сразу означали бы два разных набора размеров на одном экране.
  Widget _categoriesSection() {
    const key = 'categories';
    final expanded = _expanded.contains(key);
    final options = _options.categories;
    final visible =
        expanded ? options : options.take(_shortListLength).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Тип товара'),
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
        if (options.length > _shortListLength)
          TextButton(
            onPressed: () => setState(() {
              if (!_expanded.remove(key)) _expanded.add(key);
            }),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              expanded ? 'Скрыть' : 'Показать ещё',
              style: const TextStyle(color: activeIconColor, fontSize: 14),
            ),
          ),
      ],
    );
  }

  Widget _priceSection() {
    final hint = _options.priceMin == null || _options.priceMax == null
        ? null
        : 'от ${_money(_options.priceMin!)} до ${_money(_options.priceMax!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Цена'),
        Row(
          children: [
            Expanded(child: _priceField(_priceFromController, 'От')),
            const SizedBox(width: 10),
            Expanded(child: _priceField(_priceToController, 'До')),
          ],
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'У этого продавца $hint',
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _priceField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 15),
        filled: true,
        fillColor: secondaryBackground,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  /// Характеристика: размер, цвет, принт. Значения выбираются кнопками, как в
  /// макете, потому что их коротко и много.
  Widget _attributeSection(StoreAttribute attribute) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(attribute.title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in attribute.values)
              _chip(
                label: value.value,
                selected: _selection.attributeValueIds.contains(value.id),
                onTap: () {
                  final next = Set<int>.from(_selection.attributeValueIds);

                  if (!next.remove(value.id)) next.add(value.id);

                  setState(
                    () => _selection =
                        _selection.copyWith(attributeValueIds: next),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _ratingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Оценка товара'),
        Wrap(
          spacing: 8,
          children: [
            for (final rating in _options.ratings)
              _chip(
                label: rating.title,
                selected: _selection.ratingMin == rating.value,
                onTap: () => setState(
                  () => _selection = _selection.ratingMin == rating.value
                      ? _selection.copyWith(clearRating: true)
                      : _selection.copyWith(ratingMin: rating.value),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _deliverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Доставка'),
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
      child: Row(
        children: [
          if (_selection.isNotEmpty) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF474747)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Сбросить',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeIconColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
        ],
      ),
    );
  }
}
