// Сценарии бизнеса объявления (22.09.2026).
//
//   GET /v1/adverts/{advert}/scenarios
//   PUT /v1/adverts/{advert}/scenarios   {"scenarios": [{"name", "items": {"<блок>": [<экран>, …]}}]}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lidle/models/block_item.dart';
import 'package:lidle/models/scenario.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class ScenariosService {
  static Map<String, String> get _headers => {
        ...ApiService.defaultHeaders,
        'Content-Type': 'application/json',
        if ((TokenService.currentToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${TokenService.currentToken}',
      };

  static Uri _url(int advertId) => Uri.parse('${ApiService.baseUrl}/adverts/$advertId/scenarios');

  /// Сценарии объявления. Номера экранов переводятся в уже загруженные
  /// экраны блоков ([items] по номеру блока).
  static Future<List<ScenarioDraft>> list(
    int advertId,
    Map<int, List<BlockItemDraft>> items,
  ) async {
    final response = await http.get(_url(advertId), headers: _headers);
    if (response.statusCode != 200) return [];

    final data = (jsonDecode(response.body) as Map)['data'];
    if (data is! List) return [];

    // Все экраны объявления по номеру: залы и сотрудники в `tables`.
    final byId = <int, BlockItemDraft>{
      for (final list in items.values)
        for (final i in list)
          if (i.serverId != null) i.serverId!: i,
    };

    return data.whereType<Map>().map((row) {
      final selected = <int, List<BlockItemDraft>>{};
      final raw = row['items'];

      if (raw is Map) {
        raw.forEach((blockKey, ids) {
          final blockId = int.tryParse('$blockKey');
          if (blockId == null || ids is! List) return;
          final wanted = ids.map((e) => (e as num).toInt()).toSet();
          selected[blockId] = (items[blockId] ?? const [])
              .where((i) => i.serverId != null && wanted.contains(i.serverId))
              .toList();
        });
      }

      // Персонал столов (22.09.2026).
      final tables = <BlockItemDraft, Map<String, TableStaff>>{};
      final rawTables = row['tables'];

      if (rawTables is Map) {
        rawTables.forEach((hallKey, hallTables) {
          final hall = byId[int.tryParse('$hallKey')];
          if (hall == null || hallTables is! Map) return;

          hallTables.forEach((tableKey, staff) {
            if (staff is! Map) return;
            BlockItemDraft? pick(dynamic id) => id is num ? byId[id.toInt()] : null;
            final entry = TableStaff(waiter: pick(staff['waiter_id']), admin: pick(staff['admin_id']));
            if (!entry.isEmpty) tables.putIfAbsent(hall, () => {})['$tableKey'] = entry;
          });
        });
      }

      return ScenarioDraft(
        serverId: (row['id'] as num?)?.toInt(),
        name: '${row['name'] ?? ''}',
        selected: selected,
        tables: tables,
      );
    }).toList();
  }

  /// Заменить весь список. Экраны без номера на сервере (не отправились)
  /// пропускаются. Возвращает текст ошибки или null.
  static Future<String?> save(int advertId, List<ScenarioDraft> scenarios) async {
    final body = {
      'scenarios': [
        for (final s in scenarios)
          {
            'name': s.name,
            'items': {
              for (final e in s.selected.entries)
                '${e.key}': e.value.where((i) => i.serverId != null).map((i) => i.serverId).toList(),
            },
            'tables': {
              for (final hall in s.tables.entries)
                if (hall.key.serverId != null)
                  '${hall.key.serverId}': {
                    for (final t in hall.value.entries)
                      if (!t.value.isEmpty)
                        t.key: {
                          'waiter_id': t.value.waiter?.serverId,
                          'admin_id': t.value.admin?.serverId,
                        },
                  },
            },
          },
      ],
    };

    final response = await http.put(_url(advertId), headers: _headers, body: jsonEncode(body));

    if (response.statusCode == 200) return null;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) return '${decoded['message']}';
    } catch (_) {}

    return 'Ошибка ${response.statusCode}';
  }
}
