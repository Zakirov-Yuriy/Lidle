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
    this.catalogId,
    this.query,
    this.kind = 'all',
    this.title = 'На карте',
  });

  /// Та же категория, что в выдаче, если на карту пришли из неё.
  final int? categoryId;

  /// Каталог целиком: на экране разделов в руках именно он, а номера
  /// категории там нет. Без этого на карту уходила вся площадка.
  final int? catalogId;

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
  late final _Clusters _clusters = _Clusters(_clusterIcon, _onClusterTap);
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

          // Сколько объявлений в кадре. Без этой строки непонятно, пусто
          // тут или карта просто не доехала.
          if (!_loading && _found > 0)
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
                  child: Text(
                    'В этой области: $_found',
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
      catalogId: widget.catalogId,
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

      /*
       * Повторную загрузку НЕ зовём руками. Камера доезжает не мгновенно, и
       * сразу после движения карта ещё отдаёт прежнюю видимую область:
       * запрос уходил бы по старому кадру и привозил не то. Движение
       * камеры само разбудит слушателя, и точки подгрузятся по новому
       * кадру.
       */
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
    /*
     * СКЛЕИВАЕМ ПОСКУПЕЕ (правка 27.11.2026).
     *
     * Было 60 и 15, и на городском масштабе восемь объявлений с разных
     * улиц Аксая превращались в один синий кружок: понять по такой карте
     * ничего нельзя. Теперь метки слипаются, только если стоят почти
     * вплотную, и начиная с масштаба города каждая стоит сама по себе.
     *
     * Группы остаются там, где они по делу: несколько квартир в одном
     * доме или десяток товаров одного магазина.
     */
    points.clusterPlacemarks(clusterRadius: 24, minZoom: 12);

    setState(() {
      _loading = false;
      _found = items.length;
    });
  }



  /// Куда смотреть при открытии карты.
  ///
  /// ПРАВИЛО ПРОСТОЕ, и оно же то, о чём просил заказчик 27.11.2026:
  ///
  /// - город у человека выбран: показываем ЕГО ГОРОД ЦЕЛИКОМ, со всеми
  ///   объявлениями, которые в нём есть;
  /// - город не выбран: показываем всё, что нашлось, так, чтобы основная
  ///   масса объявлений была видна.
  ///
  /// ПОЧЕМУ НЕ ПРОСТО «КАМЕРА В ЦЕНТР ГОРОДА». Так и было, и в кадр
  /// попадала половина: в Мариуполе одиннадцать объявлений недвижимости, а
  /// на экране оставалось шесть, остальные за краем. Масштаб нельзя
  /// задавать наугад, его надо считать по самим объявлениям.
  Future<void> _startView(ymk.Map map, List<MapItem> items) async {
    final cityId = SelectedCityService().cityId;

    if (cityId != null) {
      final city = await ApiService.geoResolve(cityId: cityId);

      if (city != null && mounted) {
        // Объявления этого города: всё, что в пределах примерно полусотни
        // километров от его середины. Точной границы города у нас нет, да
        // она и не нужна: соседнее село на карте не помешает.
        final near = items.where((i) =>
            (i.lat - city.lat).abs() < 0.45 &&
            (i.lon - city.lon).abs() < 0.65).toList();

        if (near.isNotEmpty) {
          _fit(map, near, fallback: ymk.Point(latitude: city.lat, longitude: city.lon));

          return;
        }

        // В городе человека объявлений этой категории нет совсем. Показываем
        // его город, чтобы он это увидел сам, а не гадал.
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

    // Города нет: берём самое большое скопление, чтобы не показывать
    // половину страны из-за одного объявления на краю.
    const double cell = 0.5;

    final groups = <String, List<MapItem>>{};

    for (final item in items) {
      final key = '${(item.lat / cell).floor()}:${(item.lon / cell).floor()}';

      groups.putIfAbsent(key, () => []).add(item);
    }

    var best = <MapItem>[];

    for (final group in groups.values) {
      if (group.length > best.length) best = group;
    }

    _fit(map, best.isEmpty ? items : best);
  }

  /// Подводит камеру так, чтобы все переданные объявления попали в кадр.
  ///
  /// Масштаб считаем из ширины и высоты их облака: на весь мир приходится
  /// 360 градусов долготы, и каждое удвоение масштаба делит их пополам.
  /// Запас в полградуса даёт поля по краям, чтобы метки не липли к рамке.
  void _fit(ymk.Map map, List<MapItem> items, {ymk.Point? fallback}) {
    if (items.isEmpty) {
      if (fallback != null) {
        map.move(
          ymk.CameraPosition(fallback, zoom: 11.5, azimuth: 0.0, tilt: 0.0),
        );
      }

      return;
    }

    final lats = items.map((i) => i.lat).toList();
    final lons = items.map((i) => i.lon).toList();

    final north = lats.reduce(math.max);
    final south = lats.reduce(math.min);
    final east = lons.reduce(math.max);
    final west = lons.reduce(math.min);

    // Высоту переводим в доли ширины: экран телефона вытянут, и по
    // вертикали в него влезает примерно вдвое больше градусов.
    final span = math.max(east - west, (north - south) / 1.8);

    final zoom = span <= 0.004
        ? 15.5
        : (math.log(360 / (span * 1.6)) / math.ln2).clamp(4.0, 16.0);

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

  /// Нажали на группу.
  ///
  /// ПОЧЕМУ НЕ ПРОСТО ПРИБЛИЗИТЬ. Обычно группа при приближении распадается
  /// на отдельные метки, и этого достаточно. Но бывает, что объявления
  /// стоят ровно в одной точке и не разъедутся никогда: у тринадцати
  /// аксайских объявлений в адресе нет улицы либо стоит гаражный
  /// кооператив, которого на карте нет, поэтому все они получили середину
  /// города. Приближать такую группу бессмысленно, человек будет жать и
  /// злиться. Ей показываем список.
  void _onClusterTap(ymk.Cluster cluster) {
    if (!mounted) return;

    final items = cluster.placemarks
        .map((p) => p.userData is int ? _shown[p.userData as int] : null)
        .whereType<MapItem>()
        .toList();

    if (items.isEmpty) return;

    final lats = items.map((i) => i.lat);
    final lons = items.map((i) => i.lon);

    final spread = (lats.reduce(math.max) - lats.reduce(math.min)).abs() +
        (lons.reduce(math.max) - lons.reduce(math.min)).abs();

    // Примерно сто метров. Меньше этого считаем «в одной точке».
    if (spread > 0.001) {
      final map = _map;

      if (map != null) {
        map.move(
          ymk.CameraPosition(
            ymk.Point(
              latitude: lats.reduce((a, b) => a + b) / items.length,
              longitude: lons.reduce((a, b) => a + b) / items.length,
            ),
            zoom: map.cameraPosition.zoom + 2,
            azimuth: 0.0,
            tilt: 0.0,
          ),
        );
      }

      return;
    }

    _showList(items);
  }

  /// Список объявлений, стоящих в одной точке.
  void _showList(List<MapItem> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: formBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Здесь объявлений: ${items.length}',
                    style: const TextStyle(color: textPrimary, fontSize: 16),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Точный адрес у них не указан, поэтому все стоят в середине '
                'населённого пункта',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Colors.white12,
                ),
                itemBuilder: (_, i) {
                  final item = items[i];

                  return ListTile(
                    title: Text(
                      item.name.isEmpty ? 'Без названия' : item.name,
                      style: const TextStyle(color: textPrimary, fontSize: 14),
                    ),
                    subtitle: Text(
                      item.price.isEmpty ? '' : '${item.price} ₽',
                      style: const TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goTo(item);
                    },
                  );
                },
              ),
            ),
          ],
        ),
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

  /// Картинка группы: такая же красная капля, только с крупной головкой
  /// (правка заказчика 27.11.2026).
  ///
  /// Раньше группа была синим кружком, и на карте получались два разных
  /// языка: красные капли у одиночных объявлений и синие кружки у
  /// остальных. Теперь всё одним знаком, а число пишется внутри головки.
  ///
  /// Число рисуется подписью, а не картинкой: чисел заранее не знает
  /// никто, и готовить файл под каждое пришлось бы на все случаи.
  ymk_image.ImageProvider? _cluster;

  ymk_image.ImageProvider _clusterIcon() {
    return _cluster ??= ymk_image.ImageProvider.fromImageProvider(
      const AssetImage('assets/home_page/map_pin_group.png'),
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
  _Clusters(this.icon, this.onTap);

  final ymk_image.ImageProvider Function() icon;

  final void Function(ymk.Cluster cluster) onTap;

  /// Слушатели нажатия карта держит слабыми ссылками, поэтому храним их
  /// сами: без этого группа через мгновение перестаёт нажиматься.
  final List<_ClusterTap> _taps = [];

  @override
  void onClusterAdded(ymk.Cluster cluster) {
    cluster.appearance.setIconWithStyle(
      icon(),
      // Остриё капли стоит на месте, как у одиночной метки.
      const ymk.IconStyle(anchor: math.Point(0.5, 1.0), scale: 0.5),
    );

    /*
     * Сколько объявлений внутри, прямо в головке капли.
     *
     * Подпись по умолчанию ставится в середину картинки, а картинка
     * нарисована так, что её середина приходится на головку. Обводка
     * тёмная: белые цифры на красном без неё читаются хуже.
     */
    cluster.appearance.setTextWithStyle(
      const ymk.TextStyle(
        size: 11,
        color: Color(0xFFFFFFFF),
        outlineColor: Color(0x66000000),
        outlineWidth: 1,
        placement: ymk.TextStylePlacement.Center,
      ),
      text: cluster.size > 99 ? '99+' : '${cluster.size}',
    );

    final tap = _ClusterTap(onTap);

    _taps.add(tap);
    cluster.addClusterTapListener(tap);
  }
}

/// Нажатие по группе.
class _ClusterTap extends ymk.ClusterTapListener {
  _ClusterTap(this.onTap);

  final void Function(ymk.Cluster cluster) onTap;

  @override
  bool onClusterTap(ymk.Cluster cluster) {
    onTap(cluster);

    return true;
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
