import 'dart:math';

/// Размер рамки стола по умолчанию, долями плана (30.09.2026). Столы,
/// расставленные раньше, своего размера не имеют, и так они остаются на
/// схеме там же, где были.
const double kTableMarkWidth = 0.12;
const double kTableMarkHeight = 0.10;

/// Границы размера. Снизу — чтобы в рамку можно было попасть пальцем,
/// сверху — чтобы один стол не закрыл весь зал.
const double kTableMarkMin = 0.06;
const double kTableMarkMax = 0.6;

/// Стол на плане зала (22.09.2026).
///
/// Ресторан сам ставит столы на свой план зала: нажимает на свободное место,
/// там появляется стол. Место хранится долями ширины и высоты плана (0..1),
/// чтобы стол стоял там же на любом экране.
///
/// Стол общий для всех сценариев: это мебель зала. Кто его обслуживает
/// (официант, администратор), своё в каждом сценарии, см. [TableStaff].
class HallTable {
  /// Постоянный ключ: по нему к столу привязан персонал в сценариях.
  final String key;
  double x;
  double y;
  int seats;
  String number;

  /// Депозит за этот стол, рубли (29.09.2026). Свой у каждого стола: у окна
  /// дороже, чем у прохода. Ноль значит «без депозита».
  int deposit;

  /// «Важно!» в карточке стола у гостя: с чем объединяется, чем отличается.
  String note;

  /// Размер стола долями плана и поворот в градусах (30.09.2026).
  ///
  /// Метка одного размера ложилась мимо настоящего стола: у одного зала
  /// длинный стол на восемь человек, у другого круглый на двоих, и стоят они
  /// под углом. Теперь рамку подгоняет под свой стол сам продавец.
  double w;
  double h;
  double angle;

  HallTable({
    required this.key,
    required this.x,
    required this.y,
    this.seats = 2,
    this.number = '',
    this.deposit = 0,
    this.note = '',
    this.w = kTableMarkWidth,
    this.h = kTableMarkHeight,
    this.angle = 0,
  });

  static final Random _random = Random();

  /// Новый ключ: время и случайная добавка, чтобы два стола, поставленные в
  /// одну миллисекунду, не совпали.
  static String newKey() =>
      't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  HallTable copy() => HallTable(
        key: key,
        x: x,
        y: y,
        seats: seats,
        number: number,
        deposit: deposit,
        note: note,
        w: w,
        h: h,
        angle: angle,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'x': x,
        'y': y,
        'seats': seats,
        'number': number,
        'deposit': deposit,
        'note': note,
        'w': w,
        'h': h,
        'angle': angle,
      };

  static HallTable? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = '${raw['key'] ?? ''}';
    if (key.isEmpty) return null;

    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

    return HallTable(
      key: key,
      x: d(raw['x']).clamp(0.0, 1.0),
      y: d(raw['y']).clamp(0.0, 1.0),
      seats: raw['seats'] is num ? (raw['seats'] as num).toInt() : int.tryParse('${raw['seats']}') ?? 2,
      number: '${raw['number'] ?? ''}',
      // Столы, расставленные до 29.09.2026, депозита не имеют: ноль и пустое
      // примечание, а не «поле пропало».
      deposit: raw['deposit'] is num
          ? (raw['deposit'] as num).toInt()
          : int.tryParse('${raw['deposit'] ?? ''}') ?? 0,
      note: '${raw['note'] ?? ''}',
      // Столы, расставленные до 30.09.2026, размера не имеют: берём прежний,
      // чтобы схема у продавца не переехала.
      w: raw['w'] is num
          ? (raw['w'] as num).toDouble().clamp(kTableMarkMin, kTableMarkMax)
          : kTableMarkWidth,
      h: raw['h'] is num
          ? (raw['h'] as num).toDouble().clamp(kTableMarkMin, kTableMarkMax)
          : kTableMarkHeight,
      angle: raw['angle'] is num ? (raw['angle'] as num).toDouble() % 360 : 0,
    );
  }
}
