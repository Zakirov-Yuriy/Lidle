// ============================================================
// "Виджет: выбор раздела перед автовыгрузкой через CRM"
// ============================================================
//
// Показывается ПЕРЕД экраном фида (07.10.2026). Человек сначала говорит,
// какой раздел он грузит или смотрит, и только потом видит плашку про
// незавершённые объявления и сам экран подключения.
//
// Зачем так. Раньше экран фида сразу считал все незавершённые объявления
// скопом: человек, который пришёл загрузить транспорт, упирался в
// неразобранную недвижимость и не понимал, при чём тут она.
//
// Разделы берём те же, что на экране подачи объявления, вместе с их
// картинками: это один и тот же справочник, и держать второй список
// руками означало бы, что рано или поздно они разойдутся.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/catalog_model.dart';
import 'package:lidle/services/api_service.dart';
import 'package:lidle/core/logger.dart';

class CrmFeedCatalogDialog extends StatefulWidget {
  const CrmFeedCatalogDialog({super.key});

  /// Открыть окно и дождаться выбора.
  ///
  /// Возвращает выбранный раздел или null, если человек закрыл окно. На
  /// null вызывающая сторона ничего не делает: это осознанный отказ, а не
  /// ошибка.
  static Future<Catalog?> show(BuildContext context) {
    return showDialog<Catalog>(
      context: context,
      builder: (_) => const CrmFeedCatalogDialog(),
    );
  }

  @override
  State<CrmFeedCatalogDialog> createState() => _CrmFeedCatalogDialogState();
}

class _CrmFeedCatalogDialogState extends State<CrmFeedCatalogDialog> {
  static const Color bgColor = Color(0xFF1F2C3A);
  static const Color tileColor = Color(0xFF2A3A4F);

  List<Catalog> _catalogs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await ApiService.getCatalogs();

      if (!mounted) return;

      setState(() {
        _catalogs = response.data;
        _loading = false;
      });
    } catch (e) {
      log.d('Не удалось загрузить разделы для выбора фида: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить разделы';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bgColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите раздел',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Из какого раздела объявления вы загружаете или хотите посмотреть',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(child: _buildBody()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: Text(
                'Повторить',
                style: TextStyle(color: activeIconColor),
              ),
            ),
          ],
        ),
      );
    }

    if (_catalogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Text(
          'Разделы пока недоступны',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        // Выше, чем ячейка на экране подачи: здесь под картинкой ещё и
        // подпись, иначе названия обрезаются.
        childAspectRatio: 100 / 100,
      ),
      itemCount: _catalogs.length,
      itemBuilder: (context, index) => _buildTile(_catalogs[index]),
    );
  }

  Widget _buildTile(Catalog catalog) {
    final hasImage = catalog.thumbnail != null &&
        catalog.thumbnail!.isNotEmpty &&
        catalog.thumbnail!.startsWith('http');

    return GestureDetector(
      onTap: () => Navigator.pop(context, catalog),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: hasImage
                  ? Image.network(
                      catalog.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(color: tileColor);
                      },
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            catalog.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: tileColor,
      child: const Center(
        child: Icon(Icons.category, color: Colors.white70, size: 22),
      ),
    );
  }
}
