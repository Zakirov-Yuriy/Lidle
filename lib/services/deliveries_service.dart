// Справочник доставки человека (23.09.2026).
//
// Группы и курьеры у человека одни на все категории: завёл в товарах — видно
// в ресторане, завёл в ресторане — видно в товарах. Своя у места только цена,
// и она уезжает вместе с объявлением (content блока), потому что до
// сохранения объявления экрана ещё не существует.
//
//   GET    /v1/me/deliveries?place_type=block_item&place_id=8
//   POST   /v1/me/deliveries/groups            | /options
//   PUT    /v1/me/deliveries/groups/{id}       | /options/{id}
//   DELETE /v1/me/deliveries/groups/{id}       | /options/{id}
//   POST   /v1/me/deliveries/groups/{id}/image | /options/{id}/image

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lidle/models/menu_content.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class DeliveriesService {
  static Map<String, String> get _headers => {
        ...ApiService.defaultHeaders,
        if ((TokenService.currentToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${TokenService.currentToken}',
      };

  static String _url(String path) => '${ApiService.baseUrl}/me/deliveries$path';

  /// Ключ группы и позиции на экране блока: по ним сервер узнаёт, чью цену
  /// сохранять.
  static String groupKey(int id) => 'g$id';

  static String optionKey(int id) => 'o$id';

  /// Весь справочник с ценами этого экрана.
  ///
  /// Возвращает `null`, если справочник не приехал: пустой список и обрыв
  /// связи это разные вещи, и экран не должен подменять своё содержимое
  /// пустотой (25.09.2026).
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

        for (final option in (row['options'] as List? ?? []).whereType<Map>()) {
          final parsed = _option(option, key, content.ofGroup(key).length + 1);
          if (parsed != null) content.items.add(parsed);
        }
      }

      final loose = (data['ungrouped'] as List? ?? []).whereType<Map>().toList();
      final ungrouped = <MenuItem>[];

      for (var i = 0; i < loose.length; i++) {
        final parsed = _option(loose[i], groupKey(0), ungrouped.length + 1);
        if (parsed != null) ungrouped.add(parsed);
      }

      if (ungrouped.isNotEmpty) {
        content.groups.add(MenuGroup(key: groupKey(0), name: 'Доставка', position: ++position));
        content.items.addAll(ungrouped);
      }

      return content;
    } catch (_) {
      // Справочник не приехал: экран оставит то, что у него уже есть
      // (25.09.2026).
      return null;
    }
  }

  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static MenuItem? _option(Map row, String group, int position) {
    final id = _int(row['id']);

    if (id <= 0) return null;

    final price = row['price_from'];

    return MenuItem(
      key: optionKey(id),
      group: group,
      name: '${row['name'] ?? ''}',
      description: '${row['description'] ?? ''}',
      price: price is num ? price.round() : 0,
      position: position,
      imageUrl: row['image']?.toString(),
    );
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

  /// Создать способ доставки. Цена здесь не нужна: она своя у каждого места.
  static Future<int?> createOption({
    required String name,
    required String description,
    int? groupId,
    String? imagePath,
  }) async {
    final id = await _send('POST', '/options', {
      'name': name,
      'description': description,
      if (groupId != null) 'group_id': groupId,
    });

    if (id != null && imagePath != null) await uploadImage('options', id, imagePath);

    return id;
  }

  static Future<bool> updateOption({
    required int id,
    required String name,
    required String description,
    int? groupId,
    String? imagePath,
  }) async {
    final ok = await _send('PUT', '/options/$id', {
          'name': name,
          'description': description,
          if (groupId != null) 'group_id': groupId,
        }) !=
        null;

    if (ok && imagePath != null) await uploadImage('options', id, imagePath);

    return ok;
  }

  static Future<bool> deleteOption(int id) async {
    final response = await http.delete(Uri.parse(_url('/options/$id')), headers: _headers);

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
