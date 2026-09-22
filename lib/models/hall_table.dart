import 'dart:math';

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

  HallTable({
    required this.key,
    required this.x,
    required this.y,
    this.seats = 2,
    this.number = '',
  });

  static final Random _random = Random();

  /// Новый ключ: время и случайная добавка, чтобы два стола, поставленные в
  /// одну миллисекунду, не совпали.
  static String newKey() =>
      't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  HallTable copy() => HallTable(key: key, x: x, y: y, seats: seats, number: number);

  Map<String, dynamic> toJson() => {
        'key': key,
        'x': x,
        'y': y,
        'seats': seats,
        'number': number,
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
    );
  }
}
