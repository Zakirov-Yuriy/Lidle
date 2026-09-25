// ============================================================
// Экран «Добавить сотрудников» (макет 10.09.2026).
// ============================================================
//
// Третий экран того же вида, что товар и доставка: лента групп с обложками
// («Администраторы», «Повара»), ниже карточки людей с фотографией, именем и
// ролью.
//
// Карточка сотрудника это памятка продавца, а не учётная запись: сотрудник в
// приложение не входит, и отмеченные доступы пока ничего не открывают.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/models/products/product_staff.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/group_dialog.dart';
import 'package:lidle/pages/products/add_product/product_staff_member_screen.dart';
import 'package:lidle/pages/products/add_product/product_review_screen.dart';
import 'package:lidle/pages/products/add_product/tile_grid.dart';
import 'package:lidle/services/api/products_staff_api.dart';
import 'package:lidle/services/staff_service.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductStaffScreen extends StatefulWidget {
  const ProductStaffScreen({
    super.key,
    required this.publication,
    this.openReview = true,
  });

  final ProductPublication publication;

  /// Куда ведёт «Сохранить»: на сводку публикации или назад.
  ///
  /// Со сводки сюда и приходят, и открывать её второй раз поверх себя же
  /// значит уложить в стопку две одинаковые страницы: кнопка «назад» потом
  /// проведёт человека по ним обеим.
  final bool openReview;

  @override
  State<ProductStaffScreen> createState() => _ProductStaffScreenState();
}

class _ProductStaffScreenState extends State<ProductStaffScreen> {
  PublicationStaff _staff = const PublicationStaff();

  /// Какая группа раскрыта. Номер, а не объект: после обновления с сервера
  /// объекты новые, а выбор человека должен остаться прежним.
  int? _openGroupId;

  /// Раскрыты сотрудники без группы (18.09.2026).
  ///
  /// Отдельным значением, а не `null`: `null` здесь означает «групп нет
  /// вовсе», и различать эти два случая нужно, иначе сотрудник, заведённый
  /// без группы, пропадает с экрана, как только появилась первая группа.
  static const int _ungrouped = -1;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final fresh = await ProductsStaffApi.load(widget.publication.id);

      if (!mounted) return;

      setState(() {
        _staff = fresh;
        _isLoading = false;

        final ids = fresh.groups.map((group) => group.id).toSet();

        // Выбор «Без группы» держится, пока там кто-то есть: человек ушёл
        // править сотрудника и вернулся, и экран должен остаться там же.
        final keepUngrouped =
            _openGroupId == _ungrouped && fresh.ungrouped.isNotEmpty;

        if (!keepUngrouped && (_openGroupId == null || !ids.contains(_openGroupId))) {
          _openGroupId = fresh.groups.isEmpty ? null : fresh.groups.first.id;
        }
      });
    } catch (e) {
      log.e('Сотрудники не загрузились: $e');

      if (mounted) setState(() => _isLoading = false);
    }
  }

  StaffGroup? get _openGroup {
    for (final group in _staff.groups) {
      if (group.id == _openGroupId) return group;
    }

    return null;
  }

  /// Что показывать в содержимом: сотрудники открытой группы, а если открыта
  /// плитка «Без группы» или групп нет вовсе — те, что лежат без группы.
  List<StaffMember> get _visibleMembers {
    if (_openGroupId == _ungrouped) return _staff.ungrouped;

    return _openGroup?.members ?? _staff.ungrouped;
  }

  /// Заголовок над карточками: человек должен понимать, что именно он видит.
  String get _contentTitle {
    final group = _openGroup;

    if (group != null) return 'Содержимое группы: ${group.name}';

    return _staff.groups.isEmpty ? 'Сотрудники' : 'Сотрудники без группы';
  }

  // ── Группы ──────────────────────────────────────────────────────

  /// Завести группу: название и обложка одним диалогом.
  Future<void> _createGroup() async {
    final form = await showGroupDialog(context);

    if (form == null) return;

    try {
      final group = await ProductsStaffApi.createGroup(
        publicationId: widget.publication.id,
        name: form.name,
      );

      // Обложку грузим вторым запросом: у новой группы её некуда было
      // грузить, пока группы не было.
      if (form.photoPath != null) {
        await ProductsStaffApi.uploadGroupImage(group.id, form.photoPath!);
      }

      if (mounted) setState(() => _openGroupId = group.id);

      await _reload();
    } catch (e) {
      log.e('Группа сотрудников не завелась: $e');
      _say('Не получилось добавить группу.');
    }
  }

  /// Правка группы: тот же диалог с заполненными полями.
  ///
  /// Сюда ведут и строка названия, и значок фотоаппарата на обложке.
  Future<void> _editGroup(StaffGroup group) async {
    final form = await showGroupDialog(
      context,
      title: 'Изменить группу',
      initialName: group.name,
      imageUrl: group.image,
    );

    if (form == null) return;

    try {
      if (form.name != group.name) {
        await ProductsStaffApi.renameGroup(group.id, form.name);
      }

      if (form.photoPath != null) {
        await ProductsStaffApi.uploadGroupImage(group.id, form.photoPath!);
      }

      await _reload();
    } catch (e) {
      log.e('Группа не сохранилась: $e');
      _say('Не получилось сохранить группу.');
    }
  }

  Future<void> _deleteGroup(StaffGroup group) async {
    final confirmed = await _confirm(
      'Удалить группу?',
      group.members.isEmpty
          ? 'Группа пустая, удаляем.'
          : 'Сотрудники останутся, исчезнет только папка.',
    );

    if (!confirmed) return;

    try {
      await ProductsStaffApi.deleteGroup(group.id);

      if (mounted) setState(() => _openGroupId = null);

      await _reload();
    } catch (e) {
      log.e('Группа не удалилась: $e');
      _say('Не получилось удалить группу.');
    }
  }

  // ── Сотрудники ──────────────────────────────────────────────────

  /// Завести сотрудника: отдельным экраном, как позицию товара.
  Future<void> _addMember() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffMemberScreen(
          publicationId: widget.publication.id,
          categoryId: widget.publication.categoryId,
          groups: _staff.groups,

          // Из плитки «Без группы» заводим тоже без группы, а не в первую
          // попавшуюся: человек смотрит именно на тех, кто вне групп.
          groupId: _openGroupId == _ungrouped ? null : _openGroupId,
        ),
      ),
    );

    await _reload();
  }

  /// Правка сотрудника: тот же экран с заполненной формой.
  ///
  /// Сюда же ведут и карандаш, и значок фотоаппарата на карточке: картинка
  /// меняется там же, где остальное, а не отдельным жестом.
  Future<void> _editMember(StaffMember member) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductStaffMemberScreen(
          publicationId: widget.publication.id,
          categoryId: widget.publication.categoryId,
          groups: _staff.groups,
          existing: member,
        ),
      ),
    );

    await _reload();
  }

  /// Галочка «работает здесь» (25.09.2026).
  ///
  /// Список сотрудников у человека один на все его товары и объявления, а
  /// работает человек не везде: в этой публикации его показывает галочка.
  /// Снятая галочка сотрудника не удаляет — он остаётся в списке и в других
  /// местах.
  Future<void> _togglePlace(StaffMember member) async {
    final ok = await StaffService.setPlace(
      memberId: member.id,
      placeType: 'publication',
      placeId: widget.publication.id,
      works: !member.worksHere,
    );

    if (!ok) {
      _say('Не получилось сохранить.');

      return;
    }

    await _reload();
  }

  Future<void> _deleteMember(StaffMember member) async {
    final confirmed = await _confirm(
      'Удалить сотрудника?',
      '${member.name}\n\nСписок сотрудников у вас один на все товары и '
          'объявления: человек пропадёт везде. Чтобы убрать его только отсюда, '
          'снимите галочку «Работает здесь».',
    );

    if (!confirmed) return;

    try {
      await ProductsStaffApi.deleteMember(member.id);

      await _reload();
    } catch (e) {
      log.e('Сотрудник не удалился: $e');
      _say('Не получилось удалить сотрудника.');
    }
  }

  /// «Сохранить»: к сводке публикации.
  ///
  /// Сохранять здесь нечего — группы и карточки уходят на сервер сразу, как их
  /// завели. Кнопка означает «я закончил с сотрудниками».
  Future<void> _onSave() async {
    if (!widget.openReview) {
      Navigator.pop(context, true);

      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductReviewScreen(publication: widget.publication),
      ),
    );

    if (mounted) await _reload();
  }

  // ── Диалоги ─────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String text) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: secondaryBackground,
        title: Text(title,
            style: const TextStyle(color: textPrimary, fontSize: 17)),
        content: Text(text,
            style: const TextStyle(color: textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: Color(0xFFE05B5B))),
          ),
        ],
      ),
    );

    return answer == true;
  }

  void _say(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
    );
  }

  // ── Вёрстка ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: activeIconColor))
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
                // Нажатие на всю строку, а не только на стрелку: попасть пальцем
                // в иконку шириной 16 точек трудно, а заголовок рядом читается
                // как часть той же кнопки «назад».
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_ios,
                      color: textPrimary, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Добавить сотрудников',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
              const Text('Категория',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),

              // Тот же блок, что на экране товара: человек проваливается сюда
              // через несколько экранов и должен видеть, к чему заводит
              // сотрудников.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: formBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.publication.categoryName.isEmpty
                          ? 'Раздел не указан'
                          : widget.publication.categoryName,
                      style: TextStyle(
                        color: widget.publication.categoryName.isEmpty
                            ? textMuted
                            : textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (widget.publication.categoryPath.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.publication.categoryPath,
                        style: const TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('Название группы',
                  style: TextStyle(color: textPrimary, fontSize: 15)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: group == null ? null : () => _editGroup(group),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          group?.name ??
                              (_openGroupId == _ungrouped
                                  ? 'Без группы'
                                  : 'Группы пока нет'),
                          style: TextStyle(
                            color: group == null ? textMuted : textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (group != null)
                        const Icon(Icons.edit_outlined,
                            color: activeIconColor, size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _groupsStrip(),

              const SizedBox(height: 7),
              Text(
                _contentTitle,
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _membersGrid(),
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
            onTap: _onSave,
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
  ///
  /// Если кто-то заведён без группы, перед «плюсом» стоит плитка «Без
  /// группы» (18.09.2026). До неё такие сотрудники были видны, только пока
  /// групп не было ни одной: первая же группа закрывала их собой, хотя
  /// счётчик на форме публикации продолжал их считать.
  Widget _groupsStrip() {
    final hasLoose = _staff.ungrouped.isNotEmpty;
    final looseIndex = hasLoose ? _staff.groups.length : -1;
    final plusIndex = _staff.groups.length + (hasLoose ? 1 : 0);

    // Лента по высоте содержимого, а не числом: при коротких названиях
    // фиксированная высота оставляла пустую полосу снизу (23.09.2026).
    Widget tile(BuildContext context, int index) {
          if (index == looseIndex) return _looseTile();

          if (index == plusIndex) {
            return SizedBox(
              width: 116,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _createGroup,
                    child: Container(
                      width: double.infinity,
                      height: 88,
                      decoration: BoxDecoration(
                        color: formBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_circle_outline,
                          color: textSecondary, size: 24),
                    ),
                  ),
                ],
              ),
            );
          }

          final group = _staff.groups[index];
          final isOpen = group.id == _openGroupId;

          return GestureDetector(
            onTap: () => setState(() => _openGroupId = group.id),
            onLongPress: () => _deleteGroup(group),
            child: SizedBox(
              width: 116,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
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
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: GestureDetector(
                          onTap: () => _editGroup(group),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.photo_camera_outlined,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    group.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOpen ? textPrimary : textSecondary,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < plusIndex + 1; index++) ...[
              if (index > 0) const SizedBox(width: 12),
              tile(context, index),
            ],
          ],
        ),
      ),
    );
  }

  /// Плитка «Без группы»: те, кого завели, не выбрав группу.
  ///
  /// Обложки у неё нет и быть не может, поэтому значок людей, а не пустая
  /// рамка: пустая читалась бы как группа без картинки.
  Widget _looseTile() {
    final isOpen = _openGroupId == _ungrouped;

    return GestureDetector(
      onTap: () => setState(() => _openGroupId = _ungrouped),
      child: SizedBox(
        width: 116,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 88,
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isOpen ? activeIconColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.people_outline,
                  color: textMuted, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'Без группы: ${_staff.ungrouped.length}',
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
  }

  Widget _membersGrid() {
    return TileGrid(
      children: [
        ..._visibleMembers.map(_memberCard),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _addMember,
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: formBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: textSecondary, size: 24),
                      SizedBox(height: 8),
                      Text('Добавить позицию',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _memberCard(StaffMember member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          GestureDetector(
            onLongPress: () => _deleteMember(member),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: formBackground,
                      borderRadius: BorderRadius.circular(8),
                      image: member.image == null
                          ? null
                          : DecorationImage(
                              image: NetworkImage(member.image!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: member.image != null
                        ? null
                        : const Icon(Icons.person_outline,
                            color: textMuted, size: 24),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: GestureDetector(
                    onTap: () => _editMember(member),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.photo_camera_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => _editMember(member),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(Icons.edit_outlined,
                      color: activeIconColor, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            member.position == null || member.position!.isEmpty
                ? 'Должность не указана'
                : 'Роль: ${member.position}',
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),

          // Работает ли он в этой публикации (25.09.2026): список общий, и
          // здесь работают не все.
          const SizedBox(height: 3),
          GestureDetector(
            onTap: () => _togglePlace(member),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  member.worksHere
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: member.worksHere ? activeIconColor : textSecondary,
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Работает здесь',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Дальше то, что человек заполнил. Незаполненное не показываем
          // вовсе: строки «не указано» под каждой карточкой превратят список
          // в простыню, а должность и так уже об этом сказала.
          if (member.salaryShort.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Оклад: ${member.salaryShort}',
              style: const TextStyle(color: textPrimary, fontSize: 13),
            ),
          ],

          if (member.hasSchedule) ...[
            const SizedBox(height: 3),
            Text(
              member.schedule!.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],

          // Доступов на карточке нет намеренно: числом они мало о чём
          // говорят, а названиями в карточку шириной в полэкрана не влезают.
          // Какие отмечены, видно внутри сотрудника.
      ],
    );
  }
}
