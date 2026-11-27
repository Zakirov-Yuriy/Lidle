// ============================================================
//  "Поле формы: местоположение на карте"
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/map_point.dart';
import 'package:lidle/pages/map/pick_point_screen.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/map_service.dart';
import 'package:lidle/widgets/common/location_map_card.dart';

/// Карта с меткой прямо в форме подачи (задача 71, 27.11.2026).
///
/// ЗАЧЕМ. Раньше человек заполнял область, город, улицу и дом вслепую: верно
/// ли он выбрал, становилось понятно только после публикации, да и то если
/// кто-то проверил. Теперь метка встаёт сразу, как выбран адрес, и ошибка
/// видна на месте.
///
/// И ВТОРОЕ, РАДИ ЧЕГО ВСЁ ЗАТЕВАЛОСЬ. Адрес из справочника попадает в точку
/// не всегда: дома может не быть на карте, в сёлах улиц в справочнике нет
/// вовсе. Поэтому метку можно подвинуть пальцем, и тогда она считается
/// главнее справочника: её не трогает ни пересчёт, ни ночной прогон.
///
/// САМ ХОДИТ ЗА ТОЧКОЙ. Виджету отдают выбранные в форме номера справочника,
/// остальное он делает сам: спрашивает сервер, рисует карту, открывает экран
/// выбора. Форма подачи и без того на шесть тысяч строк.
class AdvertPointField extends StatefulWidget {
  const AdvertPointField({
    super.key,
    this.regionId,
    this.cityId,
    this.districtId,
    this.streetId,
    this.buildingId,
    this.pin,
    required this.onPinChanged,
  });

  final int? regionId;
  final int? cityId;
  final int? districtId;
  final int? streetId;
  final int? buildingId;

  /// Метка, которую человек уже поставил: при правке объявления она
  /// приходит с сервера, и сбрасывать её нельзя.
  final MapPoint? pin;

  /// Метку поставили или сняли. Пусто означает «считай по адресу».
  final ValueChanged<MapPoint?> onPinChanged;

  @override
  State<AdvertPointField> createState() => _AdvertPointFieldState();
}

class _AdvertPointFieldState extends State<AdvertPointField> {
  /// Точка, посчитанная сервером по выбранному адресу.
  MapPoint? _byAddress;

  bool _loading = false;

  /// По какому набору номеров мы последний раз спрашивали сервер. Без этой
  /// памяти виджет спрашивал бы заново на каждую перерисовку формы, а
  /// перерисовывается она от любой буквы в любом поле.
  String _asked = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(AdvertPointField old) {
    super.didUpdateWidget(old);
    _refresh();
  }

  /// Метка человека главнее посчитанной.
  MapPoint? get _shown => widget.pin ?? _byAddress;

  Future<void> _refresh() async {
    if (!MapService.ready) return;

    final key = '${widget.regionId}/${widget.cityId}/${widget.districtId}'
        '/${widget.streetId}/${widget.buildingId}';

    if (key == _asked) return;

    _asked = key;

    if (widget.cityId == null && widget.regionId == null) {
      setState(() => _byAddress = null);

      return;
    }

    setState(() => _loading = true);

    final point = await ApiService.geoResolve(
      regionId: widget.regionId,
      cityId: widget.cityId,
      districtId: widget.districtId,
      streetId: widget.streetId,
      buildingId: widget.buildingId,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      _byAddress = point;
    });
  }

  Future<void> _pick() async {
    final start = _shown;

    if (start == null) return;

    final chosen = await Navigator.of(context).push<MapPoint>(
      MaterialPageRoute(builder: (_) => PickPointScreen(start: start)),
    );

    if (chosen == null || !mounted) return;

    widget.onPinChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    if (!MapService.ready) return const SizedBox.shrink();

    final point = _shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 9),
        const Text(
          'Местоположение на карте',
          style: TextStyle(color: textPrimary, fontSize: 14),
        ),
        const SizedBox(height: 9),

        if (_loading && point == null)
          _hint('Ищем место по адресу...')
        else if (point == null)
          _hint('Выберите населённый пункт, и место появится на карте')
        else ...[
          // Карта без своего заголовка: он стоит строкой выше.
          LocationMapCard(point: point, showTitle: false),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: activeIconColor,
                    side: const BorderSide(color: activeIconColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _pick,
                  child: Text(
                    widget.pin == null
                        ? 'Указать точнее на карте'
                        : 'Передвинуть метку',
                  ),
                ),
              ),
              if (widget.pin != null) ...[
                const SizedBox(width: 8),
                // Вернуться к посчитанной точке. Нужна, если человек
                // промахнулся и хочет начать заново.
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textSecondary,
                    side: const BorderSide(color: textMuted),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => widget.onPinChanged(null),
                  child: const Text('Сбросить'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.pin != null
                ? 'Метку поставили вы, она важнее адреса из справочника'
                : 'Место определено по адресу. Если неточно, поправьте на карте',
            style: const TextStyle(color: textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _hint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(color: textMuted, fontSize: 13),
      ),
    );
  }
}
