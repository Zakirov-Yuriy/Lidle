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
  const AdvertMapScreen({super.key, required this.point});

  final MapPoint point;

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
    /*
     * НИКАКОЙ ШАПКИ (правка заказчика 27.11.2026).
     *
     * Полоса с кнопкой «назад», словом «Расположение» и адресом съедала
     * верх экрана и ничего не добавляла: человек только что нажал на карту
     * в карточке и прекрасно помнит, куда попал, а адрес он там же и
     * прочитал. Карта занимает экран целиком.
     *
     * ВОЗВРАТ ЗНАЧКОМ В ТОМ ЖЕ УГЛУ, что и значок «развернуть» в карточке,
     * только стрелки смотрят внутрь. Получается одна и та же кнопка в одном
     * и том же месте: нажал, развернулось, нажал ещё раз, свернулось
     * обратно. Кнопка «назад» на телефоне и жест от края работают как
     * обычно, значок их не отменяет.
     */
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Positioned.fill(
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
          // Значок «свернуть». В безопасной зоне, чтобы не залезть под
          // часы и вырез камеры.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_fullscreen,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Предупреждение о неточном месте: плашкой поверх карты, а не
          // полосой снизу, иначе карта перестаёт быть во весь экран.
          if (!widget.point.isExact)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.point.precision == 'street'
                        ? 'Точный дом продавец не указал, место показано в пределах улицы'
                        : 'Точный адрес продавец не указал, место показано примерно',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
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
