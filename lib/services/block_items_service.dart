// Содержимое блоков «Добавить …» объявления (22.09.2026): залы ресторана.
//
//   GET    /v1/adverts/{advert}/blocks
//   POST   /v1/adverts/{advert}/blocks          multipart: attribute_id, values (JSON), file
//   POST   /v1/adverts/{advert}/blocks/{item}   multipart: values, file, remove_file
//   DELETE /v1/adverts/{advert}/blocks/{item}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:lidle/models/block_item.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/services/token_service.dart';

class BlockItemsService {
  static Map<String, String> get _headers => {
        ...ApiService.defaultHeaders,
        if ((TokenService.currentToken ?? '').isNotEmpty)
          'Authorization': 'Bearer ${TokenService.currentToken}',
      };

  static String _url(int advertId, [int? itemId]) =>
      '${ApiService.baseUrl}/adverts/$advertId/blocks${itemId == null ? '' : '/$itemId'}';

  /// Все заполненные экраны объявления, по номеру блока.
  static Future<Map<int, List<BlockItemDraft>>> list(int advertId) async {
    final response = await http.get(Uri.parse(_url(advertId)), headers: _headers);

    if (response.statusCode != 200) return {};

    final body = jsonDecode(response.body);
    final data = body is Map ? body['data'] : null;
    final result = <int, List<BlockItemDraft>>{};

    if (data is List) {
      for (final row in data.whereType<Map<String, dynamic>>()) {
        final blockId = (row['attribute_id'] as num?)?.toInt();
        if (blockId == null) continue;
        result.putIfAbsent(blockId, () => []).add(BlockItemDraft.fromServer(row));
      }
    }

    return result;
  }

  /// Отправить зал: новый создаётся, изменённый обновляется. Возвращает
  /// текст ошибки или null.
  static Future<String?> save(int advertId, int blockId, BlockItemDraft item) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_url(advertId, item.serverId)),
    );

    request.headers.addAll(_headers);
    request.fields['attribute_id'] = '$blockId';
    request.fields['values'] = jsonEncode(item.values);
    // Столы на плане зала (22.09.2026). У других блоков пустой список.
    request.fields['layout'] = jsonEncode(item.layout.map((t) => t.toJson()).toList());

    final path = item.localFilePath;
    if (path != null && await File(path).exists()) {
      request.files.add(await http.MultipartFile.fromPath('file', path));
    } else if (item.removeFile) {
      request.fields['remove_file'] = '1';
    }

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        final data = (jsonDecode(response.body) as Map)['data'];
        if (data is Map<String, dynamic>) {
          final saved = BlockItemDraft.fromServer(data);
          item
            ..serverId = saved.serverId
            ..remoteFileUrl = saved.remoteFileUrl
            ..fileKind = saved.fileKind
            ..localFilePath = null
            ..removeFile = false
            ..dirty = false;
        }
      } catch (_) {}

      return null;
    }

    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) return '${body['message']}';
    } catch (_) {}

    return 'Ошибка ${response.statusCode}';
  }

  static Future<bool> delete(int advertId, int itemId) async {
    final response = await http.delete(
      Uri.parse(_url(advertId, itemId)),
      headers: _headers,
    );

    return response.statusCode == 200;
  }
}
