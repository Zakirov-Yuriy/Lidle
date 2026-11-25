// ============================================================
//  "Показатели карточки под фотографией"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart';

/// Ряд значков с числами под фотографией объявления (задача 94, 25.11.2026).
///
/// ЗАЧЕМ. Те же числа, что продавец видит в админке, наведя курсор на
/// объявление: сколько раз посмотрели, сколько раз перешли, сколько
/// оставили отзывов, сколько добавили в избранное и сколько раз поделились.
/// Человеку они говорят, насколько вещь ходовая, а продавцу, работает ли
/// его объявление.
///
/// ВМЕСТО СЛОВ ЗНАЧКИ, решение заказчика 25.11.2026. Пять подписей словами
/// под карточкой не помещаются ни на одном телефоне, а значок с числом
/// читается с одного взгляда.
///
/// НОЛЬ НЕ ПОКАЗЫВАЕМ. Ряд из нулей под свежим объявлением выглядит хуже
/// пустого места: он сообщает, что вещью никто не интересовался, хотя она
/// просто только что появилась. Если нулевые все пять, ряда нет совсем, и
/// карточка выглядит как раньше.
///
/// В ЛЕНТЕ ТРИ ЗНАЧКА, В КАРТОЧКЕ ПЯТЬ. В сетке по две карточки на ширину
/// телефона пять чисел с запасом не помещаются, и остаются те, что важнее
/// покупателю: просмотры, избранное и отзывы. Переходы и репосты это больше
/// про продвижение, их видно внутри объявления.
class AdvertStatsRow extends StatelessWidget {
  const AdvertStatsRow({
    super.key,
    required this.listing,
    this.compact = false,
    this.scale = 1.0,
  });

  final Listing listing;

  /// Короткий ряд для ленты: просмотры, избранное, отзывы.
  final bool compact;

  /// Множитель размеров, как у остальной карточки в ленте.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final items = <_Stat>[
      _Stat('assets/product_card/stat_eye.svg', listing.viewsCount),
      if (!compact) _Stat('assets/product_card/stat_click.svg', listing.clickCount),
      _Stat('assets/product_card/stat_heart.svg', listing.favoritesCount),
      _Stat('assets/product_card/stat_comment.svg', listing.commentsCount),
      if (!compact) _Stat('assets/product_card/stat_share.svg', listing.shareCount),
    ].where((item) => item.value > 0).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    final iconSize = (compact ? 12.0 : 16.0) * scale;
    final fontSize = (compact ? 10.0 : 13.0) * scale;
    final gap = (compact ? 8.0 : 14.0) * scale;

    return Wrap(
      spacing: gap,
      runSpacing: 4 * scale,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items
          .map((item) => _cell(item, iconSize, fontSize))
          .toList(),
    );
  }

  Widget _cell(_Stat item, double iconSize, double fontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          item.asset,
          width: iconSize,
          height: iconSize,
          colorFilter: const ColorFilter.mode(textSecondary, BlendMode.srcIn),
        ),
        SizedBox(width: 3 * scale),
        Text(
          _short(item.value),
          style: TextStyle(
            color: textSecondary,
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  /// Число коротко.
  ///
  /// ДЛИННЫЕ ЧИСЛА ЛОМАЮТ РЯД: у ходового объявления просмотров бывает за
  /// десять тысяч, и «12 480» рядом с четырьмя другими значками не
  /// помещается. Точность здесь не нужна, нужен порядок величины.
  static String _short(int value) {
    if (value < 1000) return value.toString();

    if (value < 1000000) {
      final thousands = value / 1000;

      return thousands >= 10
          ? '${thousands.round()} тыс.'
          : '${thousands.toStringAsFixed(1).replaceAll('.', ',')} тыс.';
    }

    final millions = value / 1000000;

    return millions >= 10
        ? '${millions.round()} млн'
        : '${millions.toStringAsFixed(1).replaceAll('.', ',')} млн';
  }
}

class _Stat {
  const _Stat(this.asset, this.value);

  final String asset;
  final int value;
}
