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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/services/help_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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
                child: Text(
                  block.text,
                  style: const TextStyle(
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
                child: Text(
                  block.text,
                  style: const TextStyle(
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
          child: Text(
            block.text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
    }
  }
}
