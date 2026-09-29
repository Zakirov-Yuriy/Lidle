// ============================================================
//  Позиция предзаказа: блюдо, товар, услуга (29.09.2026)
// ============================================================
//
// Открывается тапом по карточке на витрине. Фотография, название, цена, вес,
// описание и «Похожие предложения» — остальные позиции той же группы.
//
// «Заказать» работает так же, как на витрине: превращается в счётчик, и то же
// самое видно в карточке на витрине, потому что корзина одна и живёт на
// сервере.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/bookings/preorder.dart';
import 'package:lidle/services/preorder_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class PreorderItemScreen extends StatefulWidget {
  const PreorderItemScreen({
    super.key,
    required this.advertId,
    required this.advertTitle,
    required this.block,
    required this.position,
    this.hallId,
    this.tableKey,
  });

  final int advertId;
  final String advertTitle;
  final PreorderBlock block;
  final PreorderPosition position;
  final int? hallId;
  final String? tableKey;

  @override
  State<PreorderItemScreen> createState() => _PreorderItemScreenState();
}

class _PreorderItemScreenState extends State<PreorderItemScreen> {
  late PreorderPosition _position = widget.position;
  bool _fullDescription = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final similar = widget.block
        .ofGroup(_position.group)
        .where((i) => i.key != _position.key)
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _photo(),
                  const SizedBox(height: 14),
                  _card(),
                  if (_position.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _description(),
                  ],
                  if (similar.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Похожие предложения',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _similar(similar),
                  ],
                ],
              ),
            ),
            _orderButton(),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: _position.imageUrl == null
            ? Container(
                color: secondaryBackground,
                alignment: Alignment.center,
                child: const Icon(Icons.image_outlined, color: textMuted, size: 40),
              )
            : Image.network(
                _position.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: secondaryBackground,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_outlined, color: textMuted, size: 40),
                ),
              ),
      ),
    );
  }

  Widget _card() {
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
            _position.name,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money(_position.price)}₽',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_position.weight > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Вес: ${_position.weight}г',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _description() {
    final long = _position.description.length > 220;

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
          const Text(
            'Описание',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _position.description,
            maxLines: _fullDescription || !long ? null : 4,
            overflow: _fullDescription || !long ? null : TextOverflow.ellipsis,
            style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          ),
          if (long) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _fullDescription = !_fullDescription),
              child: Text(
                _fullDescription ? 'Свернуть' : 'Всё описание',
                style: const TextStyle(color: activeIconColor, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _similar(List<PreorderPosition> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];

        return GestureDetector(
          // Соседняя позиция открывается на этом же экране: так человек
          // листает меню, а не отращивает стопку одинаковых экранов.
          onTap: () => setState(() {
            _position = item;
            _fullDescription = false;
          }),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl == null
                      ? Container(
                          width: double.infinity,
                          color: secondaryBackground,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, color: textMuted, size: 26),
                        )
                      : Image.network(
                          item.imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: secondaryBackground,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined, color: textMuted, size: 26),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: textPrimary, fontSize: 13, height: 1.25),
              ),
              Text(
                'Цена: ${_money(item.price)}₽',
                style: const TextStyle(color: textSecondary, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orderButton() {
    return ValueListenableBuilder<PreorderCart>(
      valueListenable: PreorderService.cart,
      builder: (_, cart, __) {
        final quantity = cart.quantityOf(widget.block.blockItemId, _position.key);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: quantity <= 0
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF34A853),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _busy ? null : () => _change(1),
                    child: const Text(
                      'Заказать',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: activeIconColor),
                    ),
                    child: Row(
                      children: [
                        _step(Icons.remove, _busy ? null : () => _change(quantity - 1)),
                        Expanded(
                          child: Text(
                            'В предзаказе: $quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: activeIconColor, fontSize: 16),
                          ),
                        ),
                        _step(Icons.add, _busy ? null : () => _change(quantity + 1)),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 50,
        child: IconButton(
          icon: Icon(icon, color: onTap == null ? textMuted : activeIconColor, size: 20),
          onPressed: onTap,
        ),
      );

  Future<void> _change(int quantity) async {
    if (_busy) return;

    setState(() => _busy = true);

    final line = PreorderService.cart.value.items.where(
      (i) => i.blockItemId == widget.block.blockItemId && i.itemKey == _position.key,
    );

    final error = line.isEmpty
        ? await PreorderService.add(
            widget.advertId,
            blockItemId: widget.block.blockItemId,
            itemKey: _position.key,
            quantity: quantity,
            hallId: widget.hallId,
            tableKey: widget.tableKey,
          )
        : await PreorderService.setQuantity(
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
}

String _money(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();

  return value.toStringAsFixed(2);
}
