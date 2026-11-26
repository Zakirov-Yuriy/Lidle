// ============================================================
//  "Блок: Месторасположение"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/map_point.dart';
import 'package:lidle/services/map_service.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

/// Карта с местом объявления под его адресом (задача 71, 26.11.2026).
///
/// ЗАЧЕМ. Блок был в первом макете и назывался «Месторасположение», потом
/// его убрали: показывать на карте было нечего, координат у объявлений не
/// существовало. Теперь они есть, и блок возвращается. Человеку, который
/// смотрит квартиру, важнее всего не площадь, а где она стоит.
///
/// КАРТА ЗДЕСЬ НЕ ДВИГАЕТСЯ, и это нарочно. Блок живёт посреди длинной
/// прокручиваемой карточки. Живая карта внутри такой страницы перехватывает
/// движение пальца: человек ведёт вниз, чтобы читать дальше, а вместо этого
/// уезжает карта. Поэтому жесты ей не отдаются вовсе.
///
/// МЕТКА ИЛИ КРУГ. Точный дом по адресу находится не всегда. Когда известна
/// только улица или только населённый пункт, метка врала бы: человек читает
/// её как «вот этот подъезд». В таком случае вместо метки рисуется круг и
/// подпись, что место показано примерно.
class LocationMapCard extends StatelessWidget {
  const LocationMapCard({
    super.key,
    required this.point,
    this.address = '',
    this.height = 180,
    this.showTitle = true,
  });

  /// Где объект. Пусто означает, что блок не рисуется совсем: пустая карта
  /// хуже её отсутствия.
  final MapPoint? point;

  /// Адрес строкой, под картой. Та же строка, что в шапке карточки.
  final String address;

  final double height;

  /// Рисовать ли свой заголовок. На экране объявления блок встраивается в
  /// готовую карточку «Расположение», и второй заголовок там лишний.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final p = point;

    // Нет координат или карты выключены (ключ не задан): блока нет.
    if (p == null || !MapService.ready) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          const Text(
            'Месторасположение',
            style: TextStyle(color: textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 9),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _MapPreview(point: p),
                // Метку и круг рисуем поверх карты обычными средствами, а
                // не объектами карты: карта здесь стоит неподвижно, и
                // середина кадра это и есть наша точка.
                IgnorePointer(child: _Mark(point: p)),
              ],
            ),
          ),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            address,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
        if (!p.isExact) ...[
          const SizedBox(height: 4),
          Text(
            p.precision == 'street'
                ? 'Место показано примерно, в пределах улицы'
                : 'Место показано примерно, точный адрес не указан',
            style: const TextStyle(color: textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

/// Сама карта: неподвижный кадр вокруг точки.
class _MapPreview extends StatefulWidget {
  const _MapPreview({required this.point});

  final MapPoint point;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  @override
  void initState() {
    super.initState();

    // Карту нужно будить и усыплять, иначе она остаётся серым
    // прямоугольником. Счёт открытых карт ведёт служба.
    MapService.mapShown();
  }

  @override
  void dispose() {
    MapService.mapHidden();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(
      // Жесты уходят мимо карты, странице. Без этого карта внутри
      // прокручиваемой карточки крадёт движение пальца.
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      onMapCreated: _onMapCreated,
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    final map = window.map;

    // Приложение тёмное, и светлая карта в нём светится, как фонарь.
    map.nightModeEnabled = true;

    map.move(
      ymk.CameraPosition(
        ymk.Point(latitude: widget.point.lat, longitude: widget.point.lon),
        zoom: widget.point.zoom,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }
}

/// Метка при точном адресе, круг при неточном.
class _Mark extends StatelessWidget {
  const _Mark({required this.point});

  final MapPoint point;

  @override
  Widget build(BuildContext context) {
    if (point.isExact) {
      return const Icon(
        Icons.location_on,
        size: 40,
        color: Color(0xFFE5484D),
        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
      );
    }

    // Размер круга подобран под зум: при неточном адресе камера отводится
    // ровно настолько, чтобы известная область занимала середину кадра.
    final size = point.precision == 'street' ? 90.0 : 120.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accentColor.withValues(alpha: 0.18),
        border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 2),
      ),
    );
  }
}
