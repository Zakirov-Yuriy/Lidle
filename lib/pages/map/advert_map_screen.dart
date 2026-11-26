// ============================================================
//  "Экран: карта объявления"
// ============================================================

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/map_point.dart';
import 'package:lidle/services/map_service.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

/// Карта объявления во весь экран (задача 71, 26.11.2026).
///
/// ЗАЧЕМ ОТДЕЛЬНЫЙ ЭКРАН. В карточке карта неподвижна нарочно: она стоит
/// посреди длинной прокручиваемой страницы, и если отдать ей жесты, человек
/// поведёт палец вниз читать дальше, а уедет карта. Но посмотреть
/// окрестности людям нужно: что рядом, далеко ли до моря, какой это район.
/// Поэтому по нажатию карта открывается во весь экран, и уже здесь её можно
/// двигать и приближать.
///
/// МЕТКА ТУТ НАСТОЯЩАЯ, объект карты, а не картинка поверх. В карточке
/// хватало картинки посередине, потому что карта там не двигается. Здесь
/// она двигается, и нарисованная поверх метка осталась бы висеть
/// посередине экрана, показывая не на дом, а в случайное место.
class AdvertMapScreen extends StatefulWidget {
  const AdvertMapScreen({
    super.key,
    required this.point,
    this.address = '',
  });

  final MapPoint point;

  /// Адрес строкой, показываем в шапке.
  final String address;

  @override
  State<AdvertMapScreen> createState() => _AdvertMapScreenState();
}

class _AdvertMapScreenState extends State<AdvertMapScreen> {
  @override
  void initState() {
    super.initState();
    MapService.mapShown();
  }

  @override
  void dispose() {
    MapService.mapHidden();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: formBackground,
        foregroundColor: textPrimary,
        title: const Text('Расположение', style: TextStyle(fontSize: 17)),
      ),
      body: Column(
        children: [
          if (widget.address.isNotEmpty)
            Container(
              width: double.infinity,
              color: formBackground,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.address,
                style: const TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          Expanded(
            child: YandexMap(
              // Здесь жесты нужны самой карте, иначе её не подвинуть:
              // Flutter иначе забирает их себе ещё до карты.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: _onMapCreated,
            ),
          ),
          if (!widget.point.isExact)
            Container(
              width: double.infinity,
              color: formBackground,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Text(
                widget.point.precision == 'street'
                    ? 'Точный дом продавец не указал, место показано в пределах улицы'
                    : 'Точный адрес продавец не указал, место показано примерно',
                style: const TextStyle(color: textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    final map = window.map;
    final p = widget.point;
    final at = ymk.Point(latitude: p.lat, longitude: p.lon);

    map.nightModeEnabled = true;

    map.move(
      ymk.CameraPosition(at, zoom: p.zoom, azimuth: 0.0, tilt: 0.0),
    );

    if (p.isExact) {
      final mark = map.mapObjects.addPlacemarkWithImage(
        at,
        ymk_image.ImageProvider.fromImageProvider(
          const AssetImage('assets/home_page/map_pin.png'),
        ),
      );

      // Остриё метки должно стоять на доме, а не её середина. Якорь
      // считается долями картинки: ноль с половиной по ширине это
      // середина, единица по высоте это низ.
      mark.setIconStyle(
        const ymk.IconStyle(anchor: math.Point(0.5, 1.0), scale: 0.5),
      );

      return;
    }

    // Точного дома нет: показываем круг той величины, которую знаем.
    final circle = map.mapObjects.addCircle(
      ymk.Circle(at, radius: p.radius.toDouble()),
    );

    circle.fillColor = const Color(0x3300B7FF);
    circle.strokeColor = const Color(0xAA00B7FF);
    circle.strokeWidth = 2.0;
  }
}
