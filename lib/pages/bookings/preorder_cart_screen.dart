// ============================================================
//  Корзина предзаказа (29.09.2026)
// ============================================================
//
// Открывается по значку корзины в шапке витрины. Галочки у позиций, «Выбрать
// все», «Удалить», счётчики и итог по отмеченному.
//
// «Добавить к брони» возвращает к столу. Позиции уже лежат на сервере, так что
// кнопка ничего не отправляет: она про то, что человек закончил набирать.
// Поэтому же она требует хотя бы одной отмеченной позиции — иначе непонятно,
// что человек имел в виду.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class PreorderCartScreen extends StatefulWidget {
  const PreorderCartScreen({
    super.key,
    required this.advertId,
    this.hallId,
    this.tableKey,
  });

  final int advertId;
  final int? hallId;
  final String? tableKey;

  @override
  State<PreorderCartScreen> createState() => _PreorderCartScreenState();
}

class _PreorderCartScreenState extends State<PreorderCartScreen> {
  final Set<int> _picked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    // Всё отмечено при открытии: человек пришёл сюда посмотреть на набранное,
    // а не выбирать из него заново.
    _picked.addAll(PreorderService.cart.value.items.map((i) => i.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: ValueListenableBuilder<PreorderCart>(
          valueListenable: PreorderService.cart,
          builder: (_, cart, __) {
            // Позиции могли исчезнуть, пока экран был открыт.
            _picked.removeWhere((id) => !cart.items.any((i) => i.id == id));

            final chosen = cart.items.where((i) => _picked.contains(i.id)).toList();
            final total = chosen.fold<double>(0, (sum, i) => sum + i.sum);

            return Column(
              children: [
                const Header(),
                _topRow(cart),
                const Divider(color: Color(0xFF2C3A48), height: 1),
                Expanded(
                  child: cart.isEmpty
                      ? const Center(
                          child: Text(
                            'В предзаказе пока пусто.',
                            style: TextStyle(color: textSecondary, fontSize: 14),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: cart.items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Color(0xFF2C3A48), height: 1),
                          itemBuilder: (_, index) => _line(cart.items[index]),
                        ),
                ),
                _footer(total),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topRow(PreorderCart cart) {
    final all = cart.items.isNotEmpty && _picked.length == cart.items.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back_ios, color: textPrimary, size: 15),
                    Text(
                      'Корзина',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: activeIconColor, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: cart.isEmpty
                    ? null
                    : () => setState(() {
                          if (all) {
                            _picked.clear();
                          } else {
                            _picked
                              ..clear()
                              ..addAll(cart.items.map((i) => i.id));
                          }
                        }),
                child: Row(
                  children: [
                    _box(all),
                    const SizedBox(width: 10),
                    Text(
                      all ? 'Снять выбор' : 'Выбрать все',
                      style: const TextStyle(color: textPrimary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _busy ? null : _removePicked,
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFFF4D4D), fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(PreorderLine line) {
    final picked = _picked.contains(line.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (picked) {
                _picked.remove(line.id);
              } else {
                _picked.add(line.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 10),
              child: _box(picked),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 52,
              height: 52,
              child: line.imageUrl == null
                  ? Container(
                      color: secondaryBackground,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, color: textMuted, size: 20),
                    )
                  : Image.network(
                      line.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: secondaryBackground,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, color: textMuted, size: 20),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 14, height: 1.25),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (line.weight > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          'Вес: ${line.weight}г',
                          style: const TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ),
                    Text(
                      'Цена: ${_money(line.sum)}₽',
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3A4757)),
            ),
            child: Row(
              children: [
                _step(Icons.remove, _busy ? null : () => _setQuantity(line, line.quantity - 1)),
                SizedBox(
                  width: 26,
                  child: Text(
                    '${line.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textPrimary, fontSize: 14),
                  ),
                ),
                _step(Icons.add, _busy ? null : () => _setQuantity(line, line.quantity + 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2C3A48))),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('Скидка', style: TextStyle(color: textSecondary, fontSize: 14)),
              ),
              Text('Нет', style: TextStyle(color: textSecondary, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'К оплате:',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_money(total)}₽',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3A4757)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Назад', style: TextStyle(color: textPrimary, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeIconColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _busy ? null : _confirm,
                    child: const Text(
                      'Добавить к броне',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box(bool checked) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: checked ? activeIconColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: checked ? activeIconColor : textMuted),
        ),
        child: checked ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
      );

  Widget _step(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: onTap == null ? textMuted : textPrimary, size: 16),
          onPressed: onTap,
        ),
      );

  Future<void> _setQuantity(PreorderLine line, int quantity) async {
    setState(() => _busy = true);

    final error = await PreorderService.setQuantity(
      widget.advertId,
      lineId: line.id,
      quantity: quantity,
      hallId: widget.hallId,
      tableKey: widget.tableKey,
    );

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) SnackBarHelper.showWarning(context, error);
  }

  Future<void> _removePicked() async {
    if (_picked.isEmpty) {
      await _needPositions('Вам нужно выбрать позицию, чтобы её удалить');

      return;
    }

    setState(() => _busy = true);

    final error = await PreorderService.remove(
      widget.advertId,
      ids: _picked.toList(),
      hallId: widget.hallId,
      tableKey: widget.tableKey,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      _picked.clear();
    });

    if (error != null) SnackBarHelper.showWarning(context, error);
  }

  Future<void> _confirm() async {
    if (_picked.isEmpty) {
      await _needPositions('Вам нужно выбрать позицию для добавления к бронированию');

      return;
    }

    // Отмеченное и так лежит на сервере; снятые галочки означают «это мне не
    // нужно», поэтому такие позиции убираем.
    final drop = PreorderService.cart.value.items
        .where((i) => !_picked.contains(i.id))
        .map((i) => i.id)
        .toList();

    if (drop.isNotEmpty) {
      setState(() => _busy = true);

      await PreorderService.remove(
        widget.advertId,
        ids: drop,
        hallId: widget.hallId,
        tableKey: widget.tableKey,
      );

      if (!mounted) return;

      setState(() => _busy = false);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  /// «Вы не выбрали позиции»: то же окно, что на макете заказчика.
  Future<void> _needPositions(String text) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: formBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Вы не выбрали позиции',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: activeIconColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Понятно',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();

  return value.toStringAsFixed(2);
}
