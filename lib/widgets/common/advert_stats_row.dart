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
/// ЗНАЧКИ СТОЯТ ВСЕГДА, А НОЛЬ НЕ ПИШЕТСЯ (правка заказчика 25.11.2026).
/// Сначала нулевые показатели прятались целиком, и у свежего объявления ряд
/// получался рваный: сегодня один значок, завтра три, послезавтра пять, и
/// каждый раз на новом месте. Теперь набор постоянный, а число появляется
/// рядом со значком, когда ему есть что показать. Пустой значок при этом
/// приглушён, чтобы ряд читался с одного взгляда: где число, там и было
/// событие.
///
/// ПЯТЬ ЗНАЧКОВ ВЕЗДЕ, и в ленте тоже: заказчик 25.11.2026 посмотрел на
/// живом экране и сказал, что помещаются. В ленте они просто мельче.
/// ОДИН РЯД НА ОБЪЯВЛЕНИЯ И ТОВАРЫ (25.11.2026). Поэтому виджет принимает
/// числа, а не модель: у товара и объявления они лежат в разных классах, а
/// выглядеть ряд должен одинаково. Для карточки из ленты есть короткий
/// способ, `AdvertStatsRow.listing(...)`.
class AdvertStatsRow extends StatelessWidget {
  const AdvertStatsRow({
    super.key,
    this.views = 0,
    this.clicks = 0,
    this.favorites = 0,
    this.comments = 0,
    this.shares = 0,
    this.compact = false,
    this.scale = 1.0,
  });

  /// Ряд по карточке ленты: объявление или товар, у них общая модель.
  AdvertStatsRow.listing(
    Listing listing, {
    super.key,
    this.compact = false,
    this.scale = 1.0,
  })  : views = listing.viewsCount,
        clicks = listing.clickCount,
        favorites = listing.favoritesCount,
        comments = listing.commentsCount,
        shares = listing.shareCount;

  final int views;
  final int clicks;
  final int favorites;
  final int comments;
  final int shares;

  /// Мелкий вид для ленты: тот же набор значков, но меньше размером и по
  /// левому краю, как остальные строки карточки.
  final bool compact;

  /// Множитель размеров, как у остальной карточки в ленте.
  final double scale;

  @override
  Widget build(BuildContext context) {
    const items = <_Stat>[
      _Stat('assets/product_card/stat_eye.svg', _Kind.views),
      _Stat('assets/product_card/stat_click.svg', _Kind.clicks),
      _Stat('assets/product_card/stat_heart.svg', _Kind.favorites),
      _Stat('assets/product_card/stat_comment.svg', _Kind.comments),
      // Самолётик, а не три точки с линиями (правка заказчика
      // 26.11.2026). Та же иконка, что на синей кнопке «Поделиться» в ряду
      // действий: одно действие должно выглядеть одинаково везде, а
      // прежний значок с этой кнопкой не перекликался никак.
      _Stat('assets/product_card/stat_send.svg', _Kind.shares),
    ];

    final iconSize = (compact ? 12.0 : 17.0) * scale;
    final fontSize = (compact ? 10.0 : 13.0) * scale;
    final gap = (compact ? 6.0 : 16.0) * scale;

    if (compact) {
      /*
       * В ЛЕНТЕ РЯД ПО СЕРЕДИНЕ КАРТОЧКИ И ВСЕГДА В ОДНУ СТРОКУ (правка
       * заказчика 25.11.2026).
       *
       * Карточка в сетке идёт впритык по высоте: со строкой звёзд она
       * однажды уже начала обрезать дату снизу, 28.09.2026. Перенос значков
       * на вторую строку отнял бы место у цены и даты, поэтому его тут нет
       * совсем.
       *
       * ЧТО ПРОИСХОДИТ, КОГДА ЧИСЛА РАСТУТ. Пока их немного, ряд стоит
       * посередине в своём обычном размере. Когда чисел становится больше,
       * он раздаётся вширь до краёв карточки, а дальше `FittedBox` начинает
       * сжимать его целиком, вместе со значками и цифрами. Так ряд никогда
       * не вылезает за карточку и не прячет хвост.
       */
      return SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _cell(items[i], _value(items[i].kind), iconSize, fontSize),
              ],
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: gap,
      runSpacing: 4 * scale,
      // По середине ширины (правка заказчика 25.11.2026): под рядом широкая
      // фотография, и прижатый к левому краю ряд выглядел обрезком.
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items
          .map((item) => _cell(item, _value(item.kind), iconSize, fontSize))
          .toList(),
    );
  }

  int _value(_Kind kind) {
    return switch (kind) {
      _Kind.views => views,
      _Kind.clicks => clicks,
      _Kind.favorites => favorites,
      _Kind.comments => comments,
      _Kind.shares => shares,
    };
  }

  Widget _cell(_Stat item, int value, double iconSize, double fontSize) {
    // Пустой показатель: значок на месте, но тусклее и без числа. Так ряд
    // не прыгает от карточки к карточке, а взгляд всё равно цепляется за
    // то, где события были.
    final color = value > 0 ? textSecondary : textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          item.asset,
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        if (value > 0) ...[
          SizedBox(width: 3 * scale),
          Text(
            _short(value),
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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

enum _Kind { views, clicks, favorites, comments, shares }

class _Stat {
  const _Stat(this.asset, this.kind);

  final String asset;
  final _Kind kind;
}
