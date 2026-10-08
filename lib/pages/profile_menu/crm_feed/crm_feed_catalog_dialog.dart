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
      // Отступы подобраны так, чтобы ячейка вышла той же ширины, что на
      // экране подачи объявления (там поля экрана 25). Иначе при одной и
      // той же пропорции картинки в окне выглядят крупнее и обрезаются
      // сильнее (07.10.2026).
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 20, 13, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите категорию автовыгрузки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Подключите CRM или XML файл',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Категории, доступные для загрузки или просмотра.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(child: _buildBody()),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Отмена',
                  style: TextStyle(
                    color: activeIconColor,
                    fontWeight: FontWeight.w600,
                  ),
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

    // Сетка один в один как на экране подачи объявления: те же отступы,
    // та же пропорция ячейки, то же скругление. Человек видит привычные
    // плитки, а не второй вариант того же списка (07.10.2026).
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 120 / 83,
      ),
      itemCount: _catalogs.length,
      itemBuilder: (context, index) => _buildTile(_catalogs[index]),
    );
  }

  /// Плитка раздела.
  ///
  /// Подписи под картинкой нет сознательно: название нарисовано на самой
  /// картинке, и вторая надпись снизу дублировала её и не помещалась в
  /// ячейку. Текст остаётся только в заглушке, когда картинки нет вовсе.
  Widget _buildTile(Catalog catalog) {
    final hasImage = catalog.thumbnail != null &&
        catalog.thumbnail!.isNotEmpty &&
        catalog.thumbnail!.startsWith('http');

    return GestureDetector(
      onTap: () => Navigator.pop(context, catalog),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          // Картинка занимает ячейку целиком, иначе не закругляются нижний
          // и правый углы (та же правка, что на экране подачи 22.09.2026).
          fit: StackFit.expand,
          children: [
            hasImage
                ? Image.network(
                    catalog.thumbnail!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(catalog),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(color: tileColor);
                    },
                  )
                : _placeholder(catalog),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Catalog catalog) {
    return Container(
      color: tileColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.category, color: Colors.white70, size: 24),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                catalog.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
