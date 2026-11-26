// ============================================================
//  "Блок: Месторасположение"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/map_point.dart';
import 'package:lidle/pages/map/advert_map_screen.dart';
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
    this.showAddress = true,
  });

  /// Где объект. Пусто означает, что блок не рисуется совсем: пустая карта
  /// хуже её отсутствия.
  final MapPoint? point;

  /// Адрес строкой. Показывается под картой и уходит в шапку
  /// полноэкранной карты.
  final String address;

  /// Печатать ли адрес под картой. На экране объявления он уже стоит выше,
  /// в той же карточке, и второй раз не нужен. Но на полный экран его всё
  /// равно передаём, там он к месту.
  final bool showAddress;

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
        /*
         * НАЖАТИЕ ОТКРЫВАЕТ КАРТУ ВО ВЕСЬ ЭКРАН (правка заказчика
         * 26.11.2026). Здесь карта неподвижна, и это правильно: живая карта
         * посреди прокручиваемой карточки крадёт движение пальца. Но
         * посмотреть окрестности людям нужно, поэтому по нажатию
         * открывается отдельный экран, где карту можно двигать и приближать.
         */
        GestureDetector(
          /*
           * ЛОВИМ НАЖАТИЕ ПО ВСЕЙ ПЛОЩАДИ. Без этой строки нажатие не
           * срабатывало вовсе (26.11.2026): по умолчанию обёртка
           * откликается, только если нажали по «плотному» ребёнку, а карта
           * для нажатий нарочно прозрачная, значок в углу под
           * IgnorePointer, и ловить событие оказалось некому.
           */
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdvertMapScreen(point: p, address: address),
            ),
          ),
          child: ClipRRect(
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
                  // Значок в углу: без него человек не догадается, что по
                  // карте можно нажать, она же не шевелится.
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(child: _ExpandBadge()),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (address.isNotEmpty && showAddress) ...[
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

/// Значок «развернуть» в углу карты.
class _ExpandBadge extends StatelessWidget {
  const _ExpandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.open_in_full, size: 16, color: Colors.white),
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
