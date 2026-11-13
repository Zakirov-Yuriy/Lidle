// Инструкции на экранах подключений (задача 94, 13.11.2026).
//
// Александр 13.11.2026: инструкция, как сделана в 1С, нужна и на остальных
// экранах подключений, потому что люди начали писать с вопросами, как это
// подключить.
//
// ТЕКСТ ЖИВЁТ НА СЕРВЕРЕ, а не здесь. Решение Анны 13.11.2026: его правят в
// админке, и правка видна сразу и в приложении, и на сайте. В коде
// приложения он означал бы новую сборку и новую версию в магазине ради
// абзаца, а сайт завёл бы себе второй текст, и через месяц они разошлись бы.
//
// РАЗБИРАЕТ ТЕКСТ ТОЖЕ СЕРВЕР: сюда приходят готовые блоки, приложение их
// только рисует. Иначе сайт и приложение разобрали бы разметку по-разному.
//
// Ручка: /v1/meta/help/{тема}. Ключ не нужен, это справка.

import 'package:lidle/core/logger.dart';
import 'package:lidle/services/api_service.dart';

/// Один кусок инструкции.
///
/// Вид: `text` абзац, `step` шаг по порядку, `item` пункт списка, `code`
/// адрес или заголовок, который копируют.
class HelpBlock {
  const HelpBlock({required this.type, required this.text, this.number});

  factory HelpBlock.fromJson(Map<String, dynamic> json) {
    return HelpBlock(
      type: (json['type'] as String?) ?? 'text',
      text: (json['text'] as String?) ?? '',
      number: (json['number'] as num?)?.toInt(),
    );
  }

  final String type;
  final String text;
  final int? number;
}

class HelpArticle {
  const HelpArticle({
    required this.slug,
    required this.title,
    this.subtitle,
    this.blocks = const [],
  });

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    final blocks = json['blocks'];

    return HelpArticle(
      slug: (json['slug'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Инструкция',
      subtitle: json['subtitle'] as String?,
      blocks: blocks is List
          ? blocks
              .whereType<Map<String, dynamic>>()
              .map(HelpBlock.fromJson)
              .toList()
          : const [],
    );
  }

  final String slug;
  final String title;
  final String? subtitle;
  final List<HelpBlock> blocks;

  bool get isEmpty => blocks.isEmpty;
}

class HelpService {
  /// Темы, они же ключи на сервере.
  static const String mcp = 'mcp';
  static const String crm = 'crm';
  static const String feeds = 'feeds';
  static const String oneC = 'one_c';

  /// Уже загруженные инструкции.
  ///
  /// Держим в памяти на время работы приложения: человек открывает экран
  /// подключения не один раз, а текст меняется в лучшем случае раз в неделю.
  static final Map<String, HelpArticle?> _cache = {};

  /// Инструкция по теме. Пусто означает, что её нет или сервер не ответил:
  /// в обоих случаях экран просто не покажет раскрывашку.
  static Future<HelpArticle?> load(String slug) async {
    if (_cache.containsKey(slug)) {
      return _cache[slug];
    }

    try {
      final response = await ApiService.get('/meta/help/$slug');
      final data = response['data'];

      final article = data is Map<String, dynamic>
          ? HelpArticle.fromJson(data)
          : null;

      _cache[slug] = article;

      return article;
    } catch (e) {
      // Справка не повод ломать рабочий экран: человек пришёл подключать
      // выгрузку, а не читать инструкцию.
      logger.w('HelpService: не загрузил инструкцию $slug: $e');

      _cache[slug] = null;

      return null;
    }
  }

  /// Забыть загруженное. Нужно, когда текст правят и хотят увидеть сразу.
  static void forget() => _cache.clear();
}
