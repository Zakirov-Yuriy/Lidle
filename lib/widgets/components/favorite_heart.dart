// ============================================================
// "Виджет: сердечко избранного с заливкой от центра"
// ============================================================
//
// Просьба Анны от 28.10.2026: при нажатии сердечко должно заливаться от
// середины к краям, а не просто менять цвет. Мгновенная смена читается как
// подмена картинки, а рост из центра как отклик на нажатие.
//
// КАК УСТРОЕНО. Контур лежит снизу и виден всегда. Поверх него растёт
// закрашенное сердце: от нуля до полного размера, с лёгким перелётом в
// конце. Снятие идёт тем же путём назад, но быстрее: убирать всегда
// хочется сразу.
//
// Цвет красный, как в ленте и в галерее фотографий: цвет избранного по
// всему приложению один.

import 'package:flutter/material.dart';

class FavoriteHeart extends StatefulWidget {
  const FavoriteHeart({
    super.key,
    required this.isFavorited,
    required this.onTap,
    this.size = 24,
    this.outlineColor = Colors.white,
    this.fillColor = Colors.red,
    this.padding = const EdgeInsets.all(8),
  });

  final bool isFavorited;
  final VoidCallback onTap;
  final double size;

  /// Цвет контура, когда объявление не в избранном.
  final Color outlineColor;

  final Color fillColor;

  /// Поле вокруг иконки. Нужно, чтобы по ней было удобно попадать пальцем,
  /// но оно меньше, чем у обычной кнопки: там иконки разъезжаются.
  final EdgeInsets padding;

  @override
  State<FavoriteHeart> createState() => _FavoriteHeartState();
}

class _FavoriteHeartState extends State<FavoriteHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fill;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      // Снятие быстрее: передумал, значит хочет убрать сразу.
      reverseDuration: const Duration(milliseconds: 160),
      // Уже в избранном: показываем залитым сразу, без проигрывания.
      value: widget.isFavorited ? 1 : 0,
    );

    _fill = CurvedAnimation(
      parent: _controller,
      // Лёгкий перелёт в конце: сердце чуть «вздыхает», и нажатие
      // чувствуется.
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didUpdateWidget(covariant FavoriteHeart oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isFavorited == oldWidget.isFavorited) {
      return;
    }

    _playTo(widget.isFavorited);
  }

  /// Проиграть заливку или снятие.
  ///
  /// Если нужное состояние уже показано, ничего не делаем: иначе при
  /// перестройке экрана анимация запускалась бы заново и дёргала глаз.
  void _playTo(bool filled) {
    if (filled && _controller.value < 1) {
      _controller.forward();
    } else if (!filled && _controller.value > 0) {
      _controller.reverse();
    }
  }

  /// Нажатие: СНАЧАЛА проигрываем, потом сообщаем наружу (28.10.2026).
  ///
  /// Родитель на нажатие перестраивает экран, и если ждать его ответа,
  /// виджет успевает собраться заново уже в конечном виде: человек видит
  /// готовое красное сердце и никакой заливки.
  void _handleTap() {
    _playTo(!_controller.isCompleted);

    widget.onTap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Padding(
        padding: widget.padding,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Контур виден всегда: закрашенное сердце растёт поверх него,
              // и без контура в начале роста была бы пустота.
              Icon(
                Icons.favorite_border,
                color: widget.outlineColor,
                size: widget.size,
              ),
              ScaleTransition(
                scale: _fill,
                child: Icon(
                  Icons.favorite,
                  color: widget.fillColor,
                  size: widget.size,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
