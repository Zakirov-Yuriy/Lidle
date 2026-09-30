// ============================================================
//  Витрина заведения для предзаказа (29.09.2026)
// ============================================================
//
// Путь гостя по макетам заказчика:
//
//   карточка стола → «Добавить меню» → эта витрина: полоса групп сверху,
//   сетка позиций, у каждой «Заказать». Нажал — кнопка превращается в
//   счётчик минус/число/плюс, а в шапке растёт корзина.
//   Тап по карточке открывает саму позицию.
//   «Добавить к брони» возвращает к столу, где набранное уже показано.
//
// Корзина живёт на сервере: экран ничего не копит у себя и после каждого
// действия показывает то, что вернул сервер.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/pages/bookings/preorder_cart_screen.dart';
import 'package:lidle/pages/bookings/preorder_item_screen.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

/// Как разложены позиции на витрине.
enum PreorderSort { newest, oldest, expensive, cheap }

const Map<PreorderSort, String> _sortTitles = {
  PreorderSort.newest: 'Новые',
  PreorderSort.oldest: 'Старое',
  PreorderSort.expensive: 'Дорогие',
  PreorderSort.cheap: 'Дешевые',
};

class PreorderCatalogScreen extends StatefulWidget {
  const PreorderCatalogScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.kind,
    required this.blocks,
    this.hallId,
    this.tableKey,
    this.isTakeaway = false,
  });

  final int advertId;
  final String advertTitle;

  /// menu | product | service | delivery
  final String kind;

  /// Экраны этого рода: у заведения их может быть несколько.
  final List<PreorderBlock> blocks;

  /// Нужны, чтобы в счёте считался депозит выбранного стола.
  final int? hallId;
  final String? tableKey;

  /// Заказ навынос (29.09.2026): то же меню, другие слова на кнопке.
  final bool isTakeaway;

  @override
  State<PreorderCatalogScreen> createState() => _PreorderCatalogScreenState();
}

/// Группа вместе с экраном, которому она принадлежит: ключи групп уникальны
/// только внутри своего экрана.
class _Tab {
  const _Tab({required this.block, required this.group});

  final PreorderBlock block;
  final PreorderGroup group;

  String get id => '${block.blockItemId}:${group.key}';
}

class _PreorderCatalogScreenState extends State<PreorderCatalogScreen> {
  late final List<_Tab> _tabs = [
    for (final block in widget.blocks)
      for (final group in block.groups) _Tab(block: block, group: group),
  ];

  int _tab = 0;
  PreorderSort _sort = PreorderSort.oldest;
  bool _busy = false;

  String get _title => widget.isTakeaway
      ? 'Самовывоз'
      : (widget.blocks.isEmpty ? 'Предзаказ' : widget.blocks.first.title);

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return Scaffold(
        backgroundColor: primaryBackground,
        body: SafeArea(
          child: Column(
            children: [
              const Header(),
              _topRow(),
              const Expanded(
                child: Center(
                  child: Text(
                    'Заведение пока ничего сюда не добавило.',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tab = _tabs[_tab];
    final items = _sorted(tab.block.ofGroup(tab.group.key));

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            _topRow(),
            _groupStrip(),
            _heading(tab),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'В этой группе пока пусто.',
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 12,
                        // Фото, две строки названия, цена, вес и кнопка.
                        childAspectRatio: 0.62,
                      ),
                      itemCount: items.length,
                      itemBuilder: (_, index) => _PositionCard(
                        block: tab.block,
                        position: items[index],
                        busy: _busy,
                        onOpen: () => _openItem(tab.block, items[index]),
                        onOrder: () => _order(tab.block, items[index], 1),
                        onChange: (quantity) => _change(tab.block, items[index], quantity),
                      ),
                    ),
            ),
            _bottomButton(),
          ],
        ),
      ),
    );
  }

  /// «Назад» и корзина со счётчиком.
  Widget _topRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
          ValueListenableBuilder<PreorderCart>(
            valueListenable: PreorderService.cart,
            builder: (_, cart, __) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openCart,
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: activeIconColor, size: 22),
                  const SizedBox(width: 4),
                  Text(
                    ': ${cart.totals.itemsCount}',
                    style: const TextStyle(color: activeIconColor, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Полоса групп: картинка и подпись, выбранная обведена.
  Widget _groupStrip() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, index) {
          final tab = _tabs[index];
          final selected = index == _tab;

          return GestureDetector(
            onTap: () => setState(() => _tab = index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 78,
                  height: 62,
                  decoration: BoxDecoration(
                    color: secondaryBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? activeIconColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: tab.group.imageUrl == null
                      ? const Icon(Icons.image_outlined, color: textMuted, size: 22)
                      : Image.network(
                          tab.group.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_outlined, color: textMuted, size: 22),
                        ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 78,
                  child: Text(
                    tab.group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heading(_Tab tab) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$_title: ${tab.group.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickSort,
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.swap_vert, color: textPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton() {
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
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            widget.isTakeaway ? 'Добавить к самовывозу' : 'Добавить к брони',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  List<PreorderPosition> _sorted(List<PreorderPosition> items) {
    final sorted = [...items];

    // «Новые» и «старое» считаем по порядку, который задало заведение: даты у
    // позиции нет, а порядок как раз и говорит, что добавлено позже.
    if (_sort == PreorderSort.newest) {
      sorted.sort((a, b) => b.position.compareTo(a.position));
    } else if (_sort == PreorderSort.oldest) {
      sorted.sort((a, b) => a.position.compareTo(b.position));
    } else if (_sort == PreorderSort.expensive) {
      sorted.sort((a, b) => b.price.compareTo(a.price));
    } else {
      sorted.sort((a, b) => a.price.compareTo(b.price));
    }

    return sorted;
  }

  Future<void> _pickSort() async {
    final picked = await showDialog<PreorderSort>(
      context: context,
      builder: (_) => Dialog(
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
                      'Сортировать блюда',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              for (final entry in _sortTitles.entries)
                InkWell(
                  onTap: () => Navigator.of(context).pop(entry.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(color: textPrimary, fontSize: 15),
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: entry.key == _sort ? activeIconColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );

    if (picked != null && mounted) setState(() => _sort = picked);
  }

  Future<void> _order(PreorderBlock block, PreorderPosition position, int quantity) async {
    if (_busy) return;

    setState(() => _busy = true);

    final error = await PreorderService.add(
      widget.advertId,
      blockItemId: block.blockItemId,
      itemKey: position.key,
      quantity: quantity,
      hallId: widget.hallId,
      tableKey: widget.tableKey,
    );

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) SnackBarHelper.showWarning(context, error);
  }

  /// Минус и плюс у уже добавленной позиции.
  Future<void> _change(PreorderBlock block, PreorderPosition position, int quantity) async {
    if (_busy) return;

    final line = PreorderService.cart.value.items.where(
      (i) => i.blockItemId == block.blockItemId && i.itemKey == position.key,
    );

    if (line.isEmpty) {
      await _order(block, position, quantity);

      return;
    }

    setState(() => _busy = true);

    final error = await PreorderService.setQuantity(
      widget.advertId,
      lineId: line.first.id,
      quantity: quantity,
      hallId: widget.hallId,
      tableKey: widget.tableKey,
    );

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) SnackBarHelper.showWarning(context, error);
  }

  Future<void> _openItem(PreorderBlock block, PreorderPosition position) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreorderItemScreen(
          advertId: widget.advertId,
          advertTitle: widget.advertTitle,
          block: block,
          position: position,
          hallId: widget.hallId,
          tableKey: widget.tableKey,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreorderCartScreen(
          advertId: widget.advertId,
          hallId: widget.hallId,
          tableKey: widget.tableKey,
        ),
      ),
    );

    if (mounted) setState(() {});
  }
}

/// Карточка позиции: фото, название, цена, вес и кнопка заказа.
class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.block,
    required this.position,
    required this.busy,
    required this.onOpen,
    required this.onOrder,
    required this.onChange,
  });

  final PreorderBlock block;
  final PreorderPosition position;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onOrder;
  final void Function(int quantity) onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onOpen,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: position.imageUrl == null
                  ? Container(
                      width: double.infinity,
                      color: secondaryBackground,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: textMuted, size: 30),
                    )
                  : Image.network(
                      position.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: secondaryBackground,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: textMuted, size: 30),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: onOpen,
          child: Text(
            position.name,
            // Одна строка с многоточием (30.09.2026): длинное название
            // раздвигало карточку, и соседние фотографии оказывались разной
            // высоты. Полное название человек видит, открыв позицию.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.25),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Цена: ${_money(position.price)}₽',
          style: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        if (position.weight > 0)
          Text(
            'Вес: ${position.weight}г',
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        const SizedBox(height: 8),
        ValueListenableBuilder<PreorderCart>(
          valueListenable: PreorderService.cart,
          builder: (_, cart, __) {
            final quantity = cart.quantityOf(block.blockItemId, position.key);

            if (quantity <= 0) {
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: activeIconColor),
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: busy ? null : onOrder,
                  child: const Text(
                    'Заказать',
                    style: TextStyle(color: activeIconColor, fontSize: 15),
                  ),
                ),
              );
            }

            return Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: activeIconColor),
              ),
              child: Row(
                children: [
                  _step(Icons.remove, busy ? null : () => onChange(quantity - 1)),
                  Expanded(
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                  _step(Icons.add, busy ? null : () => onChange(quantity + 1)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 38,
        height: 38,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: onTap == null ? textMuted : activeIconColor, size: 18),
          onPressed: onTap,
        ),
      );
}

/// Цена без лишних нулей: 755, а не 755.00.
String _money(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();

  return value.toStringAsFixed(2);
}
