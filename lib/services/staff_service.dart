// Справочник сотрудников человека (25.09.2026).
//
// Сотрудники и группы у человека одни на все категории: завёл официанта в
// ресторане — он же виден в товарах и может стать курьером заказа. Своё у
// места только одно: работает ли там этот человек. Галочка уезжает вместе с
// объявлением (content блока), потому что до сохранения объявления экрана ещё
// не существует, — так же, как цена у доставки.
//
//   GET    /v1/me/staff?place_type=block_item&place_id=8
//   POST   /v1/me/staff/groups              | /members
//   PUT    /v1/me/staff/groups/{id}         | /members/{id}
//   DELETE /v1/me/staff/groups/{id}         | /members/{id}
//   POST   /v1/me/staff/groups/{id}/image   | /members/{id}/image
//   PUT    /v1/me/staff/members/{id}/place  работает ли здесь
//
// Устроено как DeliveriesService и по той же причине: у ресторана публикации
// нет, поэтому место передаётся парой place_type + place_id.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lidle/models/menu_content.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class StaffService {
  static Map<String, String> get _headers => {
        ...ApiService.defaultHeaders,
        if ((TokenService.currentToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${TokenService.currentToken}',
      };

  static String _url(String path) => '${ApiService.baseUrl}/me/staff$path';

  /// Ключ группы и человека на экране блока: по ним сервер узнаёт, чью
  /// галочку сохранять.
  static String groupKey(int id) => 'g$id';

  static String memberKey(int id) => 's$id';

  /// Весь справочник с галочками этого экрана.
  ///
  /// [blockItemId] — экран блока «Добавить сотрудника». Пока объявление не
  /// сохранено, его ещё нет: тогда справочник приезжает без галочек, и они
  /// живут только в приложении.
  /// Возвращает `null`, если справочник не приехал: пустой список и обрыв
  /// связи это разные вещи, и экран не должен их путать (25.09.2026).
  static Future<MenuContent?> load(int? blockItemId) async {
    final query = blockItemId == null || blockItemId <= 0
        ? ''
        : '?place_type=block_item&place_id=$blockItemId';

    try {
      final response = await http.get(Uri.parse(_url(query)), headers: _headers);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;

      if (data is! Map) return null;

      final content = MenuContent();
      var position = 0;

      for (final row in (data['groups'] as List? ?? []).whereType<Map>()) {
        final id = _int(row['id']);
        if (id <= 0) continue;

        final key = groupKey(id);

        content.groups.add(MenuGroup(
          key: key,
          name: '${row['name'] ?? ''}',
          position: ++position,
          imageUrl: row['image']?.toString(),
        ));

        for (final member in (row['members'] as List? ?? []).whereType<Map>()) {
          final parsed = _member(member, key, content.ofGroup(key).length + 1);
          if (parsed != null) content.items.add(parsed);
        }
      }

      final loose = (data['ungrouped'] as List? ?? []).whereType<Map>().toList();
      final ungrouped = <MenuItem>[];

      for (var i = 0; i < loose.length; i++) {
        final parsed = _member(loose[i], groupKey(0), ungrouped.length + 1);
        if (parsed != null) ungrouped.add(parsed);
      }

      if (ungrouped.isNotEmpty) {
        // Папка для тех, кого в группы не положили. Называется так же, как на
        // экране сотрудников в товарах: место одно и то же (25.09.2026).
        // Гостю в карточке заведения сервер подписывает её «Сотрудники»:
        // «Без группы» это слово для хозяина, а не для покупателя.
        content.groups.add(MenuGroup(key: groupKey(0), name: 'Без группы', position: ++position));
        content.items.addAll(ungrouped);
      }

      return content;
    } catch (_) {
      // Справочник не приехал: экран оставит то, что у него уже есть, а не
      // подменит пустотой (25.09.2026).
      return null;
    }
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static MenuItem? _member(Map row, String group, int position) {
    final id = _int(row['id']);

    if (id <= 0) return null;

    return MenuItem(
      key: memberKey(id),
      group: group,
      name: '${row['name'] ?? ''}',
      description: '${row['description'] ?? ''}',
      role: '${row['position'] ?? ''}',

      // Место могли не спрашивать: тогда поля нет вовсе, и галочка снята.
      selected: row['works_here'] == true,
      position: position,
      imageUrl: row['image']?.toString(),
    );
  }

  /// Справочник целиком в том же виде, в каком его читает экран сотрудников
  /// товаров (25.09.2026).
  ///
  /// Нужен полной карточке сотрудника: там зарплата, график, доступы и
  /// контакты, а `load` отдаёт только то, что видно на экране блока.
  static Future<PublicationStaff?> directory({int? blockItemId}) async {
    final query = blockItemId == null || blockItemId <= 0
        ? ''
        : '?place_type=block_item&place_id=$blockItemId';

    try {
      final response = await http.get(Uri.parse(_url(query)), headers: _headers);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;

      if (data is! Map) return null;

      return PublicationStaff.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }

  /// Завести сотрудника со всей карточкой: зарплата, график, доступы,
  /// контакты (25.09.2026).
  ///
  /// Тело то же, что у товарной ручки, только без публикации: справочник
  /// общий, а место отмечается отдельно.
  static Future<StaffMember> createFullMember({
    required String name,
    String? position,
    int? number,
    num? salary,
    List<String>? venueAccess,
    List<String>? accountAccess,
    StaffSchedule? schedule,
    String? description,
    StaffContacts? contacts,
    int? groupId,
  }) async {
    final response = await ApiService.post('/me/staff/members', {
      'name': name,
      if (position != null) 'position': position,
      if (number != null) 'number': number,
      if (salary != null) 'salary': salary,
      if (venueAccess != null) 'venue_access': venueAccess,
      if (accountAccess != null) 'account_access': accountAccess,
      if (schedule != null) 'schedule': schedule.toJson(),
      if (description != null) 'description': description,
      if (contacts != null) ...contacts.toJson(),
      if (groupId != null) 'group_id': groupId,
    });

    // Сознательно без мягкой обработки: ответ без `data` это отказ сервера
    // (например, 422), и он должен долететь до экрана ошибкой, а не тихим
    // «сохранено» (25.09.2026).
    return StaffMember.fromJson(
      Map<String, dynamic>.from(response['data'] as Map),
    );
  }

  /// Должности одним списком на все категории (25.09.2026).
  ///
  /// Ведёт его администратор, поэтому список приезжает с сервера, а не лежит
  /// в приложении: «Официант» и «Администратор» должны писаться одинаково, по
  /// ним настройка столов и находит людей.
  static Future<List<String>> positions() async {
    final response = await http.get(Uri.parse(_url('/positions')), headers: _headers);

    if (response.statusCode != 200) return const [];

    try {
      final data = (jsonDecode(response.body) as Map)['data'];

      return data is List ? [for (final v in data) '$v'] : const [];
    } catch (_) {
      return const [];
    }
  }

  /// Создать группу. Возвращает её номер на сервере или null.
  static Future<int?> createGroup(String name, {String? imagePath}) async {
    final id = await _send('POST', '/groups', {'name': name});

    if (id != null && imagePath != null) await uploadImage('groups', id, imagePath);

    return id;
  }

  static Future<bool> updateGroup(int id, String name, {String? imagePath}) async {
    final ok = await _send('PUT', '/groups/$id', {'name': name}) != null;

    if (ok && imagePath != null) await uploadImage('groups', id, imagePath);

    return ok;
  }

  static Future<bool> deleteGroup(int id) async {
    final response = await http.delete(Uri.parse(_url('/groups/$id')), headers: _headers);

    return response.statusCode == 200;
  }

  /// Завести сотрудника. Остальное (график, зарплата, доступы, контакты)
  /// правится на своём экране в товарах: справочник один и тот же.
  static Future<int?> createMember({
    required String name,
    required String role,
    required String description,
    int? groupId,
    String? imagePath,
  }) async {
    final id = await _send('POST', '/members', {
      'name': name,
      'position': role,
      'description': description,
      if (groupId != null) 'group_id': groupId,
    });

    if (id != null && imagePath != null) await uploadImage('members', id, imagePath);

    return id;
  }

  static Future<bool> updateMember({
    required int id,
    required String name,
    required String role,
    required String description,
    int? groupId,
    String? imagePath,
  }) async {
    final ok = await _send('PUT', '/members/$id', {
          'name': name,
          'position': role,
          'description': description,
          if (groupId != null) 'group_id': groupId,
        }) !=
        null;

    if (ok && imagePath != null) await uploadImage('members', id, imagePath);

    return ok;
  }

  static Future<bool> deleteMember(int id) async {
    final response = await http.delete(Uri.parse(_url('/members/$id')), headers: _headers);

    return response.statusCode == 200;
  }

  /// Отметить или снять место у уже сохранённого экрана или публикации.
  ///
  /// Экраны объявления галочки так не ставят: они уезжают полем `content`
  /// вместе с объявлением. Ручка нужна публикации товаров, где место есть
  /// сразу.
  static Future<bool> setPlace({
    required int memberId,
    required String placeType,
    required int placeId,
    required bool works,
  }) async {
    final uri = Uri.parse(_url('/members/$memberId/place'));

    final response = await http.put(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'place_type': placeType,
        'place_id': placeId,
        'works': works,
      }),
    );

    return response.statusCode == 200;
  }

  static Future<void> uploadImage(String what, int id, String path) async {
    if (!await File(path).exists()) return;

    final request = http.MultipartRequest('POST', Uri.parse(_url('/$what/$id/image')));
    request.headers.addAll(_headers);
    request.files.add(await http.MultipartFile.fromPath('image', path));

    await request.send();
  }

  /// Общий кусок: отправить и вытащить номер строки из ответа.
  static Future<int?> _send(String method, String path, Map<String, dynamic> body) async {
    final uri = Uri.parse(_url(path));
    final headers = {..._headers, 'Content-Type': 'application/json'};
    final encoded = jsonEncode(body);

    final response = method == 'POST'
        ? await http.post(uri, headers: headers, body: encoded)
        : await http.put(uri, headers: headers, body: encoded);

    if (response.statusCode != 200 && response.statusCode != 201) return null;

    try {
      final data = (jsonDecode(response.body) as Map)['data'];

      return data is Map ? (data['id'] as num?)?.toInt() : null;
    } catch (_) {
      return null;
    }
  }
}
