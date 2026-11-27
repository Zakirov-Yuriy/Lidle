// ============================================================
// "Виджет: Раскрывашка с инструкцией"
// ============================================================
//
// Задача 94, 13.11.2026. Один и тот же вид на всех экранах подключений:
// CRM, автовыгрузка, обмен с 1С, ключи ИИ-агентов.
//
// ЗАКРЫТА ПО УМОЛЧАНИЮ. Тому, кто уже подключил, инструкция мешает: она
// длиннее самого экрана. Тому, кто пришёл первый раз, видно заголовок и
// строку под ним, и этого достаточно, чтобы нажать.
//
// ТЕКСТ С СЕРВЕРА, см. [HelpService]. Сюда приходят готовые блоки, виджет
// их только рисует. Если текста нет или сервер не ответил, виджет не
// показывает ничего: пустая раскрывашка хуже её отсутствия.
//
// Адреса и заголовки (блоки `code`) копируются нажатием: их вставляют в
// чужую программу, и перепечатывать их руками никто не должен.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/services/help_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpTile extends StatefulWidget {
  const HelpTile({super.key, required this.slug, this.margin});

  /// Тема инструкции: HelpService.mcp, .crm, .feeds, .oneC.
  final String slug;

  final EdgeInsets? margin;

  @override
  State<HelpTile> createState() => _HelpTileState();
}

class _HelpTileState extends State<HelpTile> {
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const textSecondary = Colors.white54;

  HelpArticle? _article;
  bool _loading = true;

  /*
   * ССЫЛКИ ВНУТРИ ТЕКСТА НАЖИМАЮТСЯ (правка заказчика 27.11.2026).
   *
   * В инструкциях по службам доставки адреса кабинетов и сайтов для
   * разработчиков написаны словами: «dev.dellin.ru», «войдите в личный
   * кабинет». Человек их видел, но нажать не мог, и перепечатывал руками в
   * браузере. Теперь любой адрес и любая почта в тексте инструкции
   * открываются нажатием.
   *
   * Ловим и адреса без «http», потому что в текстах они написаны именно
   * так, как их произносят: просто «dev.dellin.ru».
   */
  static final RegExp _linkRe = RegExp(
    r'([a-zA-Z0-9._%+-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+)'
    r'|((?:https?://)?(?:[a-zA-Z0-9-]+\.)+(?:ru|com|io|net|org|dev|su|by|kz|рф)(?:/[^\s,;"»)]*)?)',
    unicode: true,
  );

  /// Распознаватели нажатий держим по адресу: пересоздавать их на каждую
  /// перерисовку нельзя, они живут дольше кадра.
  final Map<String, TapGestureRecognizer> _taps = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final tap in _taps.values) {
      tap.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    final article = await HelpService.load(widget.slug);

    if (!mounted) return;

    setState(() {
      _article = article;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;

    // Пока грузим и когда текста нет, на экране ничего: место под инструкцию
    // не занимаем и мигающей пустой карточкой не отвлекаем.
    if (_loading || article == null || article.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          leading: const Icon(Icons.help_outline, color: accentColor, size: 22),
          title: Text(
            article.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: article.subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    article.subtitle!,
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
          children: [
            ...article.blocks.map(_block),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Текст, в котором адреса и почта нажимаются.
  ///
  /// Когда ссылок в строке нет, отдаём обычный текст: лишний `RichText`
  /// ничего не даёт.
  Widget _text(String text, TextStyle style) {
    final matches = _linkRe.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var at = 0;

    for (final match in matches) {
      if (match.start > at) {
        spans.add(TextSpan(text: text.substring(at, match.start)));
      }

      var found = match.group(0)!;

      // Точка или запятая в конце предложения к адресу не относятся.
      final tail = RegExp(r'[.,;:)»]+$').firstMatch(found)?.group(0) ?? '';

      if (tail.isNotEmpty) {
        found = found.substring(0, found.length - tail.length);
      }

      spans.add(TextSpan(
        text: found,
        style: const TextStyle(
          color: accentColor,
          decoration: TextDecoration.underline,
          decorationColor: accentColor,
        ),
        recognizer: _tap(found),
      ));

      if (tail.isNotEmpty) spans.add(TextSpan(text: tail));

      at = match.end;
    }

    if (at < text.length) {
      spans.add(TextSpan(text: text.substring(at)));
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }

  TapGestureRecognizer _tap(String found) {
    return _taps.putIfAbsent(
      found,
      () => TapGestureRecognizer()..onTap = () => _open(found),
    );
  }

  Future<void> _open(String found) async {
    // Почта открывается почтовой программой, адрес браузером. Схему
    // дописываем сами: в тексте инструкции её нет, там просто «dev.dellin.ru».
    final uri = Uri.parse(
      found.contains('@') && !found.contains('://')
          ? 'mailto:$found'
          : (found.startsWith('http') ? found : 'https://$found'),
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть ссылку')),
        );
      }
    }
  }

  Widget _block(HelpBlock block) {
    switch (block.type) {
      case 'step':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Номер кружком: шаги выполняют по порядку, и глазом надо
              // находить, на каком остановился.
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${block.number ?? 0}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _text(
                  block.text,
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'item':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 6, color: textSecondary),
              ),
              Expanded(
                child: _text(
                  block.text,
                  const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'code':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Clipboard.setData(ClipboardData(text: block.text));

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Скопировано')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      block.text,
                      style: const TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy, size: 16, color: textSecondary),
                ],
              ),
            ),
          ),
        );

      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _text(
            block.text,
            const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
    }
  }
}
