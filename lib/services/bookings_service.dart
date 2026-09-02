import 'package:lidle/core/logger.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/services/api_service.dart';

/// Результат попытки забронировать.
///
/// Три исхода вместо булевого «получилось или нет», потому что вести себя
/// в них надо по-разному:
///
/// * успех — показать подтверждение и увести с экрана;
/// * время заняли (409) — данные верные, надо перечитать календарь и дать
///   выбрать заново; ругаться на пользователя не за что;
/// * отказ (422) — забронировать это время нельзя в принципе, повтор с теми
///   же данными не поможет, показываем текст сервера.
enum BookingResultKind { created, conflict, rejected }

class BookingResult {
  final BookingResultKind kind;
  final String message;

  /// Статус созданной брони: `confirmed` при мгновенной броне,
  /// `pending`, если у объявления включено подтверждение владельцем.
  final String? status;

  const BookingResult({
    required this.kind,
    required this.message,
    this.status,
  });

  bool get isCreated => kind == BookingResultKind.created;
  bool get needsOwnerAnswer => status == 'pending';
}

/// Работа с бронированием: календарь занятости и создание брони.
class BookingsService {
  /// Свободное время объявления за промежуток.
  ///
  /// Возвращает null, если бронь у объявления не подключена: сервер отвечает
  /// на это 404, и для карточки это не ошибка, а обычное «блок не показываем».
  /// Промежуток сервер сам приводит к разрешённому, поэтому просить больше
  /// горизонта безопасно.
  static Future<BookingAvailability?> availability(
    int advertId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final endpoint = '/adverts/$advertId/availability'
        '?from=${_ymd(from)}&to=${_ymd(to)}';

    try {
      final response = await ApiService.get(endpoint);

      final data = response['data'];
      if (data is! Map<String, dynamic>) return null;

      return BookingAvailability.fromJson(data);
    } catch (e) {
      // 404 = бронь не подключена или выключена. Остальное тоже гасим:
      // сломанный календарь не повод ломать всю карточку объявления.
      log.d('Календарь занятости недоступен для объявления $advertId: $e');
      return null;
    }
  }

  /// Создать бронь.
  ///
  /// Границы отправляем целиком, началом и концом, а не «начало плюс
  /// длительность»: у жилья конец приходится на другой день, и считать его
  /// на клиенте значит однажды ошибиться.
  static Future<BookingResult> create({
    required int advertId,
    required DateTime startsAt,
    required DateTime endsAt,
    int? guestsCount,
    String? comment,
    String? contactName,
    String? contactPhone,
  }) async {
    final body = <String, dynamic>{
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
    };

    if (guestsCount != null) body['guests_count'] = guestsCount;
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }
    if (contactName != null && contactName.trim().isNotEmpty) {
      body['contact_name'] = contactName.trim();
    }
    if (contactPhone != null && contactPhone.trim().isNotEmpty) {
      body['contact_phone'] = contactPhone.trim();
    }

    try {
      final response = await ApiService.post('/adverts/$advertId/bookings', body);

      if (response['success'] == true) {
        final data = response['data'];
        return BookingResult(
          kind: BookingResultKind.created,
          message: '${response['message'] ?? 'Время забронировано'}',
          status: data is Map ? data['status']?.toString() : null,
        );
      }

      // Сюда попадают 422 и 409: ApiService возвращает их телом, а не
      // исключением, чтобы вызывающий код мог их различить.
      final message = '${response['message'] ?? 'Не получилось забронировать'}';

      if (response['status_code'] == 409) {
        return BookingResult(
          kind: BookingResultKind.conflict,
          message: message,
        );
      }

      return BookingResult(kind: BookingResultKind.rejected, message: message);
    } catch (e) {
      log.e('Ошибка бронирования объявления $advertId: $e');
      return BookingResult(
        kind: BookingResultKind.rejected,
        message: 'Не получилось связаться с сервером. Попробуйте ещё раз.',
      );
    }
  }

  static String _ymd(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
