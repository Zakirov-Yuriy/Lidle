// ============================================================
//  "Экран: поставить метку на карте"
// ============================================================

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/map_point.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/map_service.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

/// Человек ставит метку сам (задача 71, 27.11.2026).
///
/// ЗАЧЕМ. Адрес из справочника попадает в точку не всегда: дома может не
/// быть на карте, в селе улиц в справочнике нет вовсе, а у частного дома
/// въезд бывает с другой улицы. Человек, который там живёт, знает лучше
/// любого справочника, поэтому ему дают поставить метку рукой.
///
/// ДВИГАЕТСЯ КАРТА, А НЕ МЕТКА. Метка нарисована ровно посередине экрана и
/// не шевелится, а человек подводит под неё нужное место. Так делают в
/// такси и в доставках, и так проще: палец не закрывает то самое место,
/// куда целишься.
///
/// АДРЕС ПОКАЗЫВАЕМ СРАЗУ. Как только карта остановилась, спрашиваем у
/// сервера, что в этой точке, и пишем внизу. Человек должен видеть, что он
/// выбрал, а не гадать по картинке.
class PickPointScreen extends StatefulWidget {
  const PickPointScreen({super.key, required this.start});

  /// С чего начинаем: точка по выбранному адресу, если она есть.
  final MapPoint start;

  @override
  State<PickPointScreen> createState() => _PickPointScreenState();
}

class _PickPointScreenState extends State<PickPointScreen> {
  ymk.Map? _map;

  /// Слушатель движения камеры. Держим ссылку на него полем нарочно:
  /// карта хранит слушателей слабыми ссылками, и местная переменная была бы
  /// собрана сборщиком мусора вместе с подпиской.
  late final _CameraWatch _watch = _CameraWatch(_onCameraStopped);

  String _address = '';
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    MapService.mapShown();
  }

  @override
  void dispose() {
    _map?.removeCameraListener(_watch);
    MapService.mapHidden();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: YandexMap(
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: _onMapCreated,
            ),
          ),

          // Метка ровно по центру. Чуть выше середины на половину своей
          // высоты, чтобы на точку смотрело остриё, а не середина картинки.
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Image.asset(
                  'assets/home_page/map_pin.png',
                  width: 30,
                  height: 40,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _round(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),

          // Подсказка сверху: короткая, чтобы не закрывать карту.
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Двигайте карту, метка стоит на месте',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),

          // Низ: что получилось и кнопка подтверждения.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: formBackground,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _asking
                          ? 'Смотрим, что здесь...'
                          : (_address.isEmpty ? 'Выбранное место' : _address),
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 47,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeIconColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _done,
                        child: const Text('Поставить метку здесь'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _round({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  void _onMapCreated(ymk.MapWindow window) {
    final map = window.map;
    _map = map;

    map.nightModeEnabled = true;

    map.move(
      ymk.CameraPosition(
        ymk.Point(latitude: widget.start.lat, longitude: widget.start.lon),
        // Ставить метку на доме с городского масштаба невозможно, поэтому
        // подводим камеру близко независимо от точности исходной точки.
        zoom: widget.start.isExact ? 17.0 : 15.0,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );

    map.addCameraListener(_watch);

    _askAddress();
  }

  /// Камера остановилась: спрашиваем, какой адрес под меткой.
  void _onCameraStopped() {
    if (!mounted) return;

    _askAddress();
  }

  Future<void> _askAddress() async {
    final at = _map?.cameraPosition.target;

    if (at == null) return;

    setState(() => _asking = true);

    final found = await ApiService.geoReverse(at.latitude, at.longitude);

    if (!mounted) return;

    setState(() {
      _asking = false;
      _address = (found?['display'] ?? '').toString();
    });
  }

  void _done() {
    final at = _map?.cameraPosition.target;

    if (at == null) {
      Navigator.of(context).maybePop();

      return;
    }

    // Метка человека всегда точная: он показал конкретное место, круг
    // рисовать незачем.
    Navigator.of(context).pop(
      MapPoint(
        lat: at.latitude,
        lon: at.longitude,
        precision: 'building',
        radius: 0,
      ),
    );
  }
}

/// Слушатель движения камеры.
///
/// Нас интересует только момент, когда движение закончилось: спрашивать
/// адрес на каждом кадре значит засыпать сервер карт запросами и упереться
/// в его ограничение частоты.
class _CameraWatch extends ymk.MapCameraListener {
  _CameraWatch(this.onStopped);

  final VoidCallback onStopped;

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition cameraPosition,
    ymk.CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    if (finished) {
      onStopped();
    }
  }
}
