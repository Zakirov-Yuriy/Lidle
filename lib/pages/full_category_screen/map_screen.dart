// ============================================================
//  "Экран карты выдачи"
// ============================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/home_models.dart' as home;
import 'package:lidle/models/map_item.dart';
import 'package:lidle/pages/full_category_screen/mini_property_details_screen.dart';
import 'package:lidle/pages/products/product_details_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/map_service.dart';
import 'package:lidle/services/selected_city_service.dart';
import 'package:yandex_maps_mapkit_lite/image.dart' as ymk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' as ymk;
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

/// Карта со всеми объявлениями и товарами (задача 71, 27.11.2026).
///
/// ЧТО БЫЛО ДО. На этом месте лежал снимок карты картинкой, `map.png`, два
/// мегабайта. Нажатие на него открывало одно и то же объявление, заведённое
/// в коде. Заглушка стояла с тех времён, когда координат в системе не было
/// вовсе.
///
/// ГРУЗИМ ТОЛЬКО ТО, ЧТО ВИДНО. Карта спрашивает точки по прямоугольнику
/// кадра и делает это, когда движение закончилось: на каждом кадре это
/// означало бы десятки запросов на одно движение пальца.
///
/// МЕТКИ СЛИПАЮТСЯ В ГРУППЫ. В городе в кадр попадают сотни объявлений, и
/// без этого карта превращается в сплошное пятно из меток. Группа
/// показывает, сколько внутри, и разваливается при приближении.
class MapScreen extends StatefulWidget {
  static const String routeName = '/map';

  const MapScreen({
    super.key,
    this.categoryId,
    this.query,
    this.kind = 'all',
    this.title = 'На карте',
  });

  /// Та же категория, что в выдаче, если на карту пришли из неё.
  final int? categoryId;

  /// Тот же поисковый запрос, что в выдаче.
  final String? query;

  /// `adverts`, `products` или `all`.
  final String kind;

  final String title;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  ymk.Map? _map;
  ymk.ClusterizedPlacemarkCollection? _points;

  /// Слушатели карта держит слабыми ссылками, поэтому они живут полями.
  late final _MapWatch _watch = _MapWatch(_onCameraStopped);
  late final _Clusters _clusters = _Clusters(_clusterIcon);
  late final _ItemTap _itemTap = _ItemTap(_openItem);

  Timer? _debounce;
  bool _loading = false;

  /// Первая загрузка на этом экране: после неё камера один раз подъезжает
  /// к найденным объявлениям.
  bool _firstLoad = true;

  /// Сколько точек нашлось в последний раз. По нему показываем, что здесь
  /// пусто, вместо молчаливой карты.
  int _found = 0;

  /// Что сейчас показано на карте. По нажатию на метку ищем здесь.
  final Map<int, MapItem> _shown = {};

  @override
  void initState() {
    super.initState();
    MapService.mapShown();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _map?.removeCameraListener(_watch);
    MapService.mapHidden();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MapService.ready) {
      return Scaffold(
        backgroundColor: primaryBackground,
        appBar: AppBar(
          backgroundColor: formBackground,
          foregroundColor: textPrimary,
          title: Text(widget.title, style: const TextStyle(fontSize: 17)),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Карта сейчас недоступна',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ),
        ),
      );
    }

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

          // Возврат тем же значком, что и на карте объявления.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
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
                      Icons.arrow_back,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (!_loading && _found == 0)
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
                    'Здесь объявлений нет, подвиньте карту',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),

          if (_loading)
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
                    'Ищем, что рядом...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
    _map = map;

    map.nightModeEnabled = true;

    // Коллекция, которая умеет слипать метки в группы.
    _points = map.mapObjects.addClusterizedPlacemarkCollection(_clusters);

    map.addCameraListener(_watch);

    // Первая загрузка: камера уже где-то стоит, слушатель сработает не
    // сразу, а показать что-то надо.
    _load();
  }

  void _onCameraStopped() {
    // Ждём, пока человек перестанет возить пальцем. Без этой паузы одно
    // движение карты даёт десяток запросов подряд.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    final map = _map;
    final points = _points;

    if (map == null || points == null || !mounted) return;

    final region = map.visibleRegion;

    final lats = [
      region.topLeft.latitude,
      region.topRight.latitude,
      region.bottomLeft.latitude,
      region.bottomRight.latitude,
    ];
    final lons = [
      region.topLeft.longitude,
      region.topRight.longitude,
      region.bottomLeft.longitude,
      region.bottomRight.longitude,
    ];

    setState(() => _loading = true);

    /*
     * ЗАЖИМАЕМ ГРАНИЦЫ. На самом дальнем масштабе в кадр попадает весь шар,
     * и карта честно отдаёт широты и долготы за пределами возможного:
     * например, долготу 200 или широту 90 с хвостиком. Сервер такие числа
     * не принимает и отвечает отказом, а человек видит пустую карту и не
     * понимает, почему.
     */
    final north = lats.reduce(math.max).clamp(-85.0, 85.0);
    final south = lats.reduce(math.min).clamp(-85.0, 85.0);
    final east = lons.reduce(math.max).clamp(-180.0, 180.0);
    final west = lons.reduce(math.min).clamp(-180.0, 180.0);

    final items = await ApiService.mapPoints(
      north: north,
      south: south,
      east: east,
      west: west,
      kind: widget.kind,
      categoryId: widget.categoryId,
      query: widget.query,
    );

    if (!mounted) return;

    /*
     * ПЕРВОЕ ОТКРЫТИЕ: ПОДЪЕЗЖАЕМ ТУДА, ГДЕ ЕСТЬ ОБЪЯВЛЕНИЯ.
     *
     * Карта открывается на весь шар, и объявления на ней выглядят как
     * ничего: Мариуполь с такого расстояния меньше точки. Поэтому в первый
     * раз сами подводим камеру так, чтобы в кадр попали все найденные
     * объявления. Дальше человек двигает карту сам, и больше мы в это не
     * вмешиваемся.
     */
    if (_firstLoad && items.isNotEmpty) {
      _firstLoad = false;

      await _startView(map, items);

      // Камера уехала, значит в кадре теперь другое. Спросим точки заново
      // и на этом успокоимся: дальше карту двигает человек.
      if (mounted) _load();

      return;
    }

    _firstLoad = false;

    points.clear();
    _shown.clear();

    final icon = _pinIcon();

    for (final item in items) {
      final mark = points.addPlacemarkWithImage(
        ymk.Point(latitude: item.lat, longitude: item.lon),
        icon,
      );

      mark.setIconStyle(
        const ymk.IconStyle(anchor: math.Point(0.5, 1.0), scale: 0.45),
      );

      // Чем метка является, храним у себя по её коду: класть сюда саму
      // карточку нельзя, карта держит объекты по-своему.
      _shown[identityHashCode(mark)] = item;
      mark.userData = identityHashCode(mark);
      mark.addTapListener(_itemTap);
    }

    // Без этого вызова ни метки, ни группы не нарисуются: так устроена
    // коллекция с группировкой.
    points.clusterPlacemarks(clusterRadius: 60, minZoom: 15);

    setState(() {
      _loading = false;
      _found = items.length;
    });
  }



  /// Куда смотреть при открытии карты.
  ///
  /// СНАЧАЛА ГОРОД ЧЕЛОВЕКА. Объявления разбросаны по всей стране: в выдаче
  /// есть и Мариуполь, и Москва, и Сибирь. Если показать их все разом,
  /// карта открывается видом на половину Евразии, и это бесполезно: своего
  /// города на ней не разглядеть.
  ///
  /// Поэтому, если человек выбрал город в приложении, карта открывается на
  /// нём. Координаты города спрашиваем у той же ручки, что и форма подачи:
  /// держать их список в приложении незачем.
  ///
  /// ЕСЛИ ГОРОД НЕ ВЫБРАН, показываем все найденные объявления разом: это
  /// хотя бы честно отвечает на вопрос «а где они вообще есть».
  Future<void> _startView(ymk.Map map, List<MapItem> items) async {
    final cityId = SelectedCityService().cityId;

    if (cityId != null) {
      final city = await ApiService.geoResolve(cityId: cityId);

      if (city != null) {
        map.move(
          ymk.CameraPosition(
            ymk.Point(latitude: city.lat, longitude: city.lon),
            zoom: 11.5,
            azimuth: 0.0,
            tilt: 0.0,
          ),
        );

        return;
      }
    }

    _fitAll(map, items);
  }

  /// Подводит камеру так, чтобы в кадр попали все найденные объявления.
  ///
  /// ПОЧЕМУ НЕ К ПЕРВОЙ ТОЧКЕ. Сначала так и было, и выходило глупо: с
  /// глобуса первой оказывалась случайная точка где-нибудь в степи, карта
  /// прыгала туда, и человек видел одно объявление посреди поля вместо
  /// города, полного меток.
  ///
  /// Масштаб считаем из ширины облака точек: на весь мир приходится 360
  /// градусов долготы, и каждое удвоение масштаба делит их пополам. Это
  /// грубо, зато не требует от карты ничего, чего она может не уметь.
  void _fitAll(ymk.Map map, List<MapItem> items) {
    final lats = items.map((i) => i.lat).toList();
    final lons = items.map((i) => i.lon).toList();

    final north = lats.reduce(math.max);
    final south = lats.reduce(math.min);
    final east = lons.reduce(math.max);
    final west = lons.reduce(math.min);

    // Когда объявление одно, облака нет: берём близкий масштаб улицы.
    final span = math.max(east - west, (north - south) * 1.6);

    final zoom = span <= 0.005
        ? 15.0
        : (math.log(360 / span) / math.ln2 - 0.4).clamp(3.0, 16.0);

    map.move(
      ymk.CameraPosition(
        ymk.Point(
          latitude: (north + south) / 2,
          longitude: (east + west) / 2,
        ),
        zoom: zoom.toDouble(),
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );
  }

  /// Нажали на метку: показываем, что это, и предлагаем открыть.
  bool _openItem(Object? userData) {
    final item = userData is int ? _shown[userData] : null;

    if (item == null || !mounted) return false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: formBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name.isEmpty ? 'Без названия' : item.name,
                style: const TextStyle(color: textPrimary, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                item.price.isEmpty ? '' : '${item.price} ₽',
                style: const TextStyle(color: textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 14),
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
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _goTo(item);
                  },
                  child: Text(item.isProduct ? 'Открыть товар' : 'Открыть объявление'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return true;
  }

  void _goTo(MapItem item) {
    /*
     * Открываем теми же экранами, что и выдача. Товар принимает номер, а
     * объявление требует карточку: тогда отдаём ему заготовку с номером,
     * названием и ценой, а остальное экран дочитает с сервера сам. Так же
     * сделано в чате, когда объявление открывают из переписки.
     */
    if (item.isProduct) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(productId: item.id),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniPropertyDetailsScreen(
          listing: home.Listing(
            id: item.id.toString(),
            imagePath: '',
            images: const [],
            title: item.name,
            price: item.price,
            location: '',
            date: '',
          ),
        ),
      ),
    );
  }

  /// Картинка метки. Читается с диска один раз на экран.
  ymk_image.ImageProvider? _pin;

  ymk_image.ImageProvider _pinIcon() {
    return _pin ??= ymk_image.ImageProvider.fromImageProvider(
      const AssetImage('assets/home_page/map_pin.png'),
    );
  }

  /// Картинка группы: белый кружок с синей серединой.
  ///
  /// Число внутри рисуется не картинкой, а подписью к метке: иначе под
  /// каждое возможное число пришлось бы готовить свой файл, а числа
  /// заранее неизвестны.
  ymk_image.ImageProvider? _cluster;

  ymk_image.ImageProvider _clusterIcon() {
    return _cluster ??= ymk_image.ImageProvider.fromImageProvider(
      const AssetImage('assets/home_page/map_cluster.png'),
    );
  }
}

/// Слушатель движения камеры: нас интересует только остановка.
class _MapWatch extends ymk.MapCameraListener {
  _MapWatch(this.onStopped);

  final VoidCallback onStopped;

  @override
  void onCameraPositionChanged(
    ymk.Map map,
    ymk.CameraPosition cameraPosition,
    ymk.CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    if (finished) onStopped();
  }
}

/// Оформление групп: кружок с числом вместо кучи меток.
class _Clusters extends ymk.ClusterListener {
  _Clusters(this.icon);

  final ymk_image.ImageProvider Function() icon;

  @override
  void onClusterAdded(ymk.Cluster cluster) {
    cluster.appearance.setIconWithStyle(
      icon(),
      const ymk.IconStyle(anchor: math.Point(0.5, 0.5), scale: 0.45),
    );

    // Сколько объявлений внутри. Подписью, а не картинкой: числа заранее
    // неизвестны, и готовить файл под каждое пришлось бы на все случаи.
    cluster.appearance.setText(cluster.size > 99 ? '99+' : '${cluster.size}');
  }
}

/// Нажатие по метке.
class _ItemTap extends ymk.MapObjectTapListener {
  _ItemTap(this.onTap);

  final bool Function(Object? userData) onTap;

  @override
  bool onMapObjectTap(ymk.MapObject mapObject, ymk.Point point) {
    return onTap(mapObject.userData);
  }
}
