import 'package:lidle/core/logger.dart';
import 'package:lidle/models/bookings/booking_availability.dart';
import 'package:lidle/models/bookings/booking_item.dart';
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
  ///
  /// И отправляем ровно те строки, которые прислал сервер, вместе с их
  /// смещением. Ничего не пересчитываем: любая арифметика с часовыми
  /// поясами на клиенте это будущая ошибка на три часа.
  static Future<BookingResult> create({
    required int advertId,
    required String startsAt,
    required String endsAt,
    int? guestsCount,
    String? comment,
    String? contactName,
    String? contactPhone,
  }) async {
    final body = <String, dynamic>{
      'starts_at': startsAt,
      'ends_at': endsAt,
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

  /// Мои брони как гостя.
  ///
  /// `scope`: upcoming (по умолчанию), past или all.
  static Future<List<BookingItem>> myBookings({
    String scope = 'upcoming',
  }) async {
    return _list('/me/bookings?scope=$scope');
  }

  /// Заявки на мои объявления.
  static Future<List<BookingItem>> incoming({
    String scope = 'upcoming',
  }) async {
    return _list('/me/bookings/incoming?scope=$scope');
  }

  static Future<List<BookingItem>> _list(String endpoint) async {
    final response = await ApiService.get(endpoint);

    final data = response['data'];
    if (data is! List) return const [];

    final items = <BookingItem>[];
    for (final row in data) {
      final item = BookingItem.tryParse(row);
      if (item != null) items.add(item);
    }

    return items;
  }

  /// Владелец подтверждает заявку.
  static Future<BookingResult> confirm(int bookingId) =>
      _act('/me/bookings/$bookingId/confirm', 'Бронь подтверждена');

  /// Владелец отклоняет заявку.
  static Future<BookingResult> reject(int bookingId, {String? reason}) =>
      _act('/me/bookings/$bookingId/reject', 'Заявка отклонена', reason: reason);

  /// Отмена. Доступна обеим сторонам, но гостя ограничивает срок из настроек
  /// объявления. Проверять срок здесь не нужно: сервер уже прислал
  /// `can_cancel`, а если нажать в последнюю секунду, придёт понятный отказ.
  static Future<BookingResult> cancel(int bookingId, {String? reason}) =>
      _act('/me/bookings/$bookingId/cancel', 'Бронь отменена', reason: reason);

  static Future<BookingResult> _act(
    String endpoint,
    String fallbackMessage, {
    String? reason,
  }) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      body['reason'] = reason.trim();
    }

    try {
      final response = await ApiService.post(endpoint, body);

      if (response['success'] == true) {
        final data = response['data'];
        return BookingResult(
          kind: BookingResultKind.created,
          message: '${response['message'] ?? fallbackMessage}',
          status: data is Map ? data['status']?.toString() : null,
        );
      }

      return BookingResult(
        kind: BookingResultKind.rejected,
        message: '${response['message'] ?? 'Не получилось'}',
      );
    } catch (e) {
      log.e('Ошибка действия над бронью: $e');
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
