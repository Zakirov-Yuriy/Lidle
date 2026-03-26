import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/offer_model.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_accepted_page.dart';
import 'package:lidle/pages/profile_dashboard/offers/price_offers_list_page.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';

class OfferCard extends StatefulWidget {
  final Offer offer;

  /// Каллбэк: вызывается когда все предложения по этому объявлению обработаны,
  /// чтобы родительский экран мог обновить список
  final VoidCallback? onRefreshNeeded;

  /// Для режима выделения (selection mode)
  final bool isChecked;
  final bool isSelectionMode;
  final VoidCallback? onChanged;
  final VoidCallback? onLongPress;

  const OfferCard({
    super.key,
    required this.offer,
    this.onRefreshNeeded,
    this.isChecked = false,
    this.isSelectionMode = false,
    this.onChanged,
    this.onLongPress,
  });

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  bool _isTitleExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isOfferToMe = widget.offer.offeredPricesCount != null;

    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode) {
          widget.onChanged?.call();
        }
      },
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
        padding: const EdgeInsets.only(
          top: 16,
          left: 10,
          right: 10,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          children: [
            // ───── Image and details ─────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───── Checkbox в режиме выделения ─────
                if (widget.isSelectionMode)
                  CustomCheckbox(
                    value: widget.isChecked,
                    onChanged: (value) => widget.onChanged?.call(),
                  ),
                if (widget.isSelectionMode) const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  // Показываем изображение только если URL не пустой.
                  // При отсутствии thumbnail — серый прямоугольник без заглушки.
                  child: widget.offer.imageUrl.isEmpty
                      ? Container(
                          width: 105,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white24,
                            size: 30,
                          ),
                        )
                      : widget.offer.imageUrl.startsWith('http')
                      ? Image.network(
                          widget.offer.imageUrl,
                          width: 105,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 105,
                              height: 74,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Image.asset(
                          widget.offer.imageUrl,
                          width: 105,
                          height: 74,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '№ ${widget.offer.advertisementId ?? widget.offer.id}',
                            style: const TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (!isOfferToMe)
                            Builder(
                              builder: (_) {
                                // Считаем просмотренным если: явно прочитано (read_at != null)
                                // ИЛИ статус уже обработан (принято/отклонено)
                                final isViewed =
                                    widget.offer.viewed ||
                                    widget.offer.status != OfferStatus.pending;
                                return Text(
                                  isViewed ? 'Просмотрено' : 'Не просмотрено',
                                  style: TextStyle(
                                    color: isViewed ? textMuted : textSecondary,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _isTitleExpanded = !_isTitleExpanded;
                          });
                        },
                        child: Text(
                          widget.offer.title,
                          maxLines: _isTitleExpanded ? null : 1,
                          overflow: _isTitleExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.offer.originalPrice} ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF474747), height: 12),

            // ───── Middle section (Offered prices or Your price) ─────
            if (isOfferToMe)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFFE8FF00),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Предложенных цен: ${widget.offer.offeredPricesCount}',
                      style: const TextStyle(
                        color: Color(0xFFE8FF00),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ваша цена: ${widget.offer.yourPrice}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _buildStatusWidget(widget.offer.status),
                ],
              ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF474747), height: 9),
            // ───── View button ─────
            if (!widget.isSelectionMode)
              GestureDetector(
                onTap: () async {
                  if (isOfferToMe) {
                    // Всегда переходим на список предложений цен,
                    // независимо от того, приняты ли все офферы
                    final result = await Navigator.pushNamed(
                      context,
                      PriceOffersListPage.routeName,
                      arguments: widget.offer,
                    );
                    if (result == true) {
                      widget.onRefreshNeeded?.call();
                    }
                  } else {
                    final result = await Navigator.pushNamed(
                      context,
                      PriceAcceptedPage.routeName,
                      arguments: widget.offer,
                    );
                    // Если предложение было удалено/обновлено — обновляем список
                    // через callback, не закрывая price_offers_empty_page
                    if (result == true) {
                      widget.onRefreshNeeded?.call();
                    }
                  }
                },
                child: Text(
                  'Просмотреть',
                  style: TextStyle(color: activeIconColor, fontSize: 15),
                ),
              ),
            if (widget.isSelectionMode) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(OfferStatus status) {
    switch (status) {
      case OfferStatus.accepted:
        return const Text(
          'Цена принята',
          style: TextStyle(
            color: Color(0xFF00B7FF),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        );
      case OfferStatus.rejected:
        return const Text(
          'Отказ от цены',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        );
      case OfferStatus.pending:
        return const SizedBox.shrink(); // No status displayed for pending
    }
  }
}
