// ============================================================
// Экран «Добавить товар»: группы и позиции внутри них.
// ============================================================
//
// Второй экран макета от 09.09.2026. Сверху лента групп с обложками
// («Куртки зима», «Куртки осень-весна») и плитка «плюс» для новой группы,
// ниже содержимое выбранной группы: позиции и плитка «Добавить позицию».
//
// Группа это папка при заведении. Покупателю групп не показывают: на витрине
// он видит каждую позицию отдельной карточкой с кнопкой «в корзину».

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_position_screen.dart';
import 'package:lidle/services/api/products_cabinet_api.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductGroupsScreen extends StatefulWidget {
  const ProductGroupsScreen({super.key, required this.publication});

  final ProductPublication publication;

  @override
  State<ProductGroupsScreen> createState() => _ProductGroupsScreenState();
}

class _ProductGroupsScreenState extends State<ProductGroupsScreen> {
  late ProductPublication _publication = widget.publication;

  /// Какая группа раскрыта. Номер, а не объект: после обновления с сервера
  /// объекты новые, а выбор человека должен остаться прежним.
  int? _openGroupId;

  bool _isLoading = true;

  final TextEditingController _groupName = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final fresh = await ProductsCabinetApi.publication(_publication.id);

      if (!mounted) return;

      setState(() {
        _publication = fresh;
        _isLoading = false;

        // Если раскрытая группа исчезла, раскрываем первую: пустой экран без
        // объяснения выглядит поломкой.
        final ids = fresh.groups.map((g) => g.id).toSet();

        if (_openGroupId == null || !ids.contains(_openGroupId)) {
          _openGroupId = fresh.groups.isEmpty ? null : fresh.groups.first.id;
        }

        _groupName.text = _openGroup?.name ?? '';
      });
    } catch (e) {
      log.e('Не удалось загрузить публикацию: $e');

      if (mounted) setState(() => _isLoading = false);
    }
  }

  ProductGroup? get _openGroup {
    for (final group in _publication.groups) {
      if (group.id == _openGroupId) return group;
    }

    return null;
  }

  Future<void> _createGroup() async {
    final name = await _askName('Новая группа', '');

    if (name == null || name.trim().isEmpty) return;

    try {
      final group = await ProductsCabinetApi.createGroup(
        publicationId: _publication.id,
        name: name.trim(),
      );

      if (!mounted) return;

      setState(() => _openGroupId = group.id);

      await _reload();
    } catch (e) {
      log.e('Группа не завелась: $e');
      _say('Не получилось добавить группу.');
    }
  }

  Future<void> _renameGroup() async {
    final group = _openGroup;

    if (group == null) return;

    final name = await _askName('Название группы', group.name);

    if (name == null || name.trim().isEmpty) return;

    try {
      await ProductsCabinetApi.renameGroup(group.id, name.trim());
      await _reload();
    } catch (e) {
      log.e('Группа не переименовалась: $e');
      _say('Не получилось сохранить название.');
    }
  }

  Future<void> _deleteGroup(ProductGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: const Text('Удалить группу?',
            style: TextStyle(color: textPrimary, fontSize: 17)),

        // Прямо говорим, что будет с товарами: человек боится потерять
        // заведённое, и это законный страх.
        content: Text(
          group.productsCount == 0
              ? 'Группа пустая, удаляем.'
              : 'Позиции останутся в публикации, исчезнет только папка.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ProductsCabinetApi.deleteGroup(group.id);

      if (mounted) setState(() => _openGroupId = null);

      await _reload();
    } catch (e) {
      log.e('Группа не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  Future<String?> _askName(String title, String initial) {
    final controller = TextEditingController(text: initial);

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(title, style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: textPrimary),
          decoration: const InputDecoration(
            hintText: 'Например, Куртки зима',
            hintStyle: TextStyle(color: textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Сохранить', style: TextStyle(color: activeIconColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _addPosition() async {
    final group = _openGroup;

    if (group == null) {
      _say('Сначала добавьте группу: позиция кладётся в неё.');

      return;
    }

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPositionScreen(
          publication: _publication,
          group: group,
          nextPosition: group.productsCount + 1,
        ),
      ),
    );

    if (saved == true) await _reload();
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: activeIconColor))
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final group = _openGroup;

    return Column(
      children: [
        const Header(),
        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios,
                    color: textPrimary, size: 18),
              ),
              const Text(
                'Добавить товар',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text('Отмена',
                    style: TextStyle(color: activeIconColor, fontSize: 16)),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              defaultPadding,
              16,
              defaultPadding,
              24,
            ),
            children: [
              _hintLink('Как это работает?'),
              _hintLink('Что такое группы?'),

              const SizedBox(height: 12),
              const Text('Название группы',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: group == null ? null : _renameGroup,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group?.name ?? 'Группы пока нет',
                    style: TextStyle(
                      color: group == null ? textMuted : textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _groupsStrip(),

              const SizedBox(height: 20),
              Text(
                group == null
                    ? 'Содержимое группы'
                    : 'Содержимое группы: ${group.name}',
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _positionsGrid(group),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            0,
            defaultPadding,
            16,
          ),
          child: GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeIconColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hintLink(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(color: activeIconColor, fontSize: 14),
        ),
      );

  /// Лента групп с обложками и плиткой «плюс».
  Widget _groupsStrip() {
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _publication.groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == _publication.groups.length) {
            return GestureDetector(
              onTap: _createGroup,
              child: Container(
                width: 116,
                height: 88,
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_circle_outline,
                    color: textSecondary, size: 28),
              ),
            );
          }

          final group = _publication.groups[index];
          final isOpen = group.id == _openGroupId;

          return GestureDetector(
            onTap: () => setState(() => _openGroupId = group.id),
            onLongPress: () => _deleteGroup(group),
            child: SizedBox(
              width: 116,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: formBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOpen ? activeIconColor : Colors.transparent,
                        width: 2,
                      ),
                      image: group.image == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(group.image!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: group.image != null
                        ? null
                        : const Icon(Icons.photo_outlined,
                            color: textMuted, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOpen ? textPrimary : textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _positionsGrid(ProductGroup? group) {
    final positions = group?.products ?? const <ProductPosition>[];

    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        ...positions.map(_positionCard),
        GestureDetector(
          onTap: _addPosition,
          child: Container(
            width: 150,
            height: 180,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: textSecondary, size: 28),
                SizedBox(height: 8),
                Text('Добавить позицию',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _positionCard(ProductPosition position) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
              image: position.image == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(position.image!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: position.image != null
                ? null
                : const Icon(Icons.photo_outlined, color: textMuted, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            position.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            '${position.price} ₽',
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
