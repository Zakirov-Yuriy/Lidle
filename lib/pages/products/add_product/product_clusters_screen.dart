// ============================================================
// Экран «Кластеры» (14.09.2026).
// ============================================================
//
// ЧТО ТАКОЕ КЛАСТЕР. Это группа позиций: «Куртки зима», «Куртки осень-весна».
// До 14.09.2026 слово с макета было без смысла, и экран жил заглушкой со
// счётчиками штук, которая ничего не сохраняла. Заказчик назвал смысл, и
// экран переписан целиком.
//
// Что здесь можно: увидеть ВСЕ свои кластеры этого конечного раздела и
// перенести позиции из одного в другой — одну, несколько или все сразу.
//
// Почему все кластеры раздела, а не одной витрины: у продавца в разделе
// бывает несколько витрин, по одной на бренд, и человек думает не витринами,
// а «куда положить куртку». Чужих кластеров здесь не бывает — сервер отбирает
// только свои.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductClustersScreen extends StatefulWidget {
  const ProductClustersScreen({
    super.key,
    required this.categoryId,
    this.positionName,
    this.highlightProductId,
  });

  /// Конечный раздел: его кластеры и показываем.
  final int categoryId;

  /// Название позиции, из карточки которой открыли экран. Только для подписи.
  final String? positionName;

  /// Позиция, ради которой пришли: её подсвечиваем и отмечаем сразу.
  final int? highlightProductId;

  @override
  State<ProductClustersScreen> createState() => _ProductClustersScreenState();
}

class _ProductClustersScreenState extends State<ProductClustersScreen> {
  List<ProductCluster> _clusters = const [];
  bool _isLoading = true;
  bool _isMoving = false;

  /// Что перенести: номера отмеченных позиций.
  final Set<int> _picked = <int>{};

  /// Из какого кластера отмечали.
  ///
  /// Переносим за раз из ОДНОГО кластера: «перенести из двух папок в третью»
  /// человек всё равно делает в два приёма, а список «откуда» сделал бы экран
  /// вдвое сложнее ради редкого случая.
  int? _sourceCluster;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    try {
      final clusters = await ProductsCabinetApi.clusters(widget.categoryId);

      if (!mounted) return;

      setState(() {
        _clusters = clusters;
        _isLoading = false;

        // Позицию, ради которой пришли, отмечаем сразу: человек открыл экран
        // из её карточки, и первым делом он хочет перенести именно её.
        final highlight = widget.highlightProductId;

        if (highlight != null && _picked.isEmpty) {
          for (final cluster in clusters) {
            if (cluster.products.any((item) => item.id == highlight)) {
              _picked.add(highlight);
              _sourceCluster = cluster.id;

              break;
            }
          }
        }
      });
    } catch (e) {
      log.e('Кластеры не загрузились: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);
      _say('Не получилось загрузить кластеры');
    }
  }

  void _toggle(ProductCluster cluster, ProductPosition position) {
    setState(() {
      // Сменили кластер — прежний выбор снимаем. Иначе человек отметил бы
      // позиции в двух папках и не понял, почему переносится только часть.
      if (_sourceCluster != null && _sourceCluster != cluster.id) {
        _picked.clear();
      }

      _sourceCluster = cluster.id;

      if (!_picked.remove(position.id)) _picked.add(position.id);

      if (_picked.isEmpty) _sourceCluster = null;
    });
  }

  void _toggleWholeCluster(ProductCluster cluster) {
    setState(() {
      final ids = cluster.products.map((item) => item.id).toSet();
      final allPicked = _sourceCluster == cluster.id &&
          ids.isNotEmpty &&
          _picked.containsAll(ids);

      _picked.clear();

      if (allPicked) {
        _sourceCluster = null;
      } else {
        _picked.addAll(ids);
        _sourceCluster = cluster.id;
      }
    });
  }

  Future<void> _moveTo(ProductCluster target) async {
    if (_picked.isEmpty || _isMoving) return;

    setState(() => _isMoving = true);

    try {
      await ProductsCabinetApi.moveToCluster(
        groupId: target.id,
        productIds: _picked.toList(),
      );

      if (!mounted) return;

      final moved = _picked.length;

      setState(() {
        _picked.clear();
        _sourceCluster = null;
        _isMoving = false;
      });

      _say('Перенесено: $moved ${_positions(moved)}');

      await _load();
    } catch (e) {
      log.e('Перенос не удался: $e');

      if (!mounted) return;

      setState(() => _isMoving = false);
      _say('$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(),
            const SizedBox(height: 12),
            _title(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: activeIconColor),
                    )
                  : _clusters.isEmpty
                      ? _empty()
                      : _list(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _picked.isEmpty ? null : _moveBar(),
    );
  }

  Widget _title() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: textPrimary, size: 18),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Кластеры',
              style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'В этом разделе у вас пока нет кластеров. Они появятся, когда вы '
          'заведёте группу товаров на экране позиций.',
          textAlign: TextAlign.center,
          style: TextStyle(color: textMuted, fontSize: 15),
        ),
      ),
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(defaultPadding, 12, defaultPadding, 24),
      children: [
        Text(
          _picked.isEmpty
              ? 'Отметьте позиции и выберите кластер, в который их перенести.'
              : 'Выбрано ${_picked.length} ${_positions(_picked.length)}. '
                  'Нажмите «Перенести сюда» у нужного кластера.',
          style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 14),
        ..._clusters.map(_clusterCard),
      ],
    );
  }

  Widget _clusterCard(ProductCluster cluster) {
    final isSource = _sourceCluster == cluster.id;
    final canReceive = _picked.isNotEmpty && !isSource;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
        // Кластер, откуда переносим, обведён: иначе в списке из шести папок
        // человек теряет, что именно он отметил.
        border: isSource
            ? Border.all(color: activeIconColor, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cover(cluster),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cluster.name.isEmpty ? 'Без названия' : cluster.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Бренд витрины: два кластера «Куртки» из разных витрин
                      // иначе не различить.
                      [
                        '${cluster.productsCount} ${_positions(cluster.productsCount)}',
                        if (cluster.brandName != null) cluster.brandName!,
                      ].join(' · '),
                      style: const TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (cluster.products.isNotEmpty)
                GestureDetector(
                  onTap: () => _toggleWholeCluster(cluster),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      isSource &&
                              _picked.containsAll(
                                cluster.products.map((item) => item.id),
                              )
                          ? 'Снять'
                          : 'Все',
                      style: const TextStyle(
                        color: activeIconColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          if (cluster.products.isEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Пусто. Сюда можно перенести позиции из других кластеров.',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ] else ...[
            const SizedBox(height: 6),
            ...cluster.products.map((item) => _positionRow(cluster, item)),
          ],

          if (canReceive) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: _isMoving ? null : () => _moveTo(cluster),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: activeIconColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _isMoving ? 'Переносим…' : 'Перенести сюда',
                  style: const TextStyle(
                    color: activeIconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cover(ProductCluster cluster) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 48,
        height: 48,
        child: cluster.image == null
            ? Container(
                color: secondaryBackground,
                child: const Icon(Icons.folder_outlined,
                    color: textMuted, size: 20),
              )
            : Image.network(
                cluster.image!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: secondaryBackground,
                  child: const Icon(Icons.folder_outlined,
                      color: textMuted, size: 20),
                ),
              ),
      ),
    );
  }

  Widget _positionRow(ProductCluster cluster, ProductPosition position) {
    final picked = _picked.contains(position.id);
    final isTarget = position.id == widget.highlightProductId;

    return GestureDetector(
      onTap: () => _toggle(cluster, position),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CustomCheckbox(
              value: picked,
              onChanged: (_) => _toggle(cluster, position),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 36,
                height: 36,
                child: position.image == null
                    ? Container(
                        color: secondaryBackground,
                        child: const Icon(Icons.image_outlined,
                            color: textMuted, size: 16),
                      )
                    : Image.network(
                        position.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: secondaryBackground,
                          child: const Icon(Icons.image_outlined,
                              color: textMuted, size: 16),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                position.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  // Позиция, из карточки которой пришли, названа синим: в
                  // длинном списке человек иначе ищет её глазами.
                  color: isTarget ? activeIconColor : Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Нижняя полоса: что выбрано и как это снять.
  Widget _moveBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(defaultPadding, 8, defaultPadding, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Выбрано ${_picked.length} ${_positions(_picked.length)}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _picked.clear();
                _sourceCluster = null;
              }),
              child: const Text(
                'Снять выбор',
                style: TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  /// «1 позиция», «2 позиции», «5 позиций».
  String _positions(int count) {
    final tens = count % 100;
    final ones = count % 10;

    if (tens >= 11 && tens <= 14) return 'позиций';
    if (ones == 1) return 'позиция';
    if (ones >= 2 && ones <= 4) return 'позиции';

    return 'позиций';
  }
}
