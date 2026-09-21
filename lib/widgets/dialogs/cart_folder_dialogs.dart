// ============================================================
//  Папки корзины: диалоги (18.09.2026)
// ============================================================
//
// Папка это полка внутри корзины: «к первому сентября», «для дома». Человек
// откладывает вещи впрок, а потом заходит и решает, что из отложенного берёт.
//
// Диалоги собраны в одном файле, потому что открываются из трёх мест: с
// карточки товара, с плитки в ленте разделов и из самой корзины. Три копии
// одного окна разошлись бы после первой же правки текста.

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/pages/products/add_product/photo_source_sheet.dart';
import 'package:lidle/services/cart_service.dart';

/// Положить товар в корзину, спросив папку, если есть из чего выбирать.
///
/// Диалог показываем ТОЛЬКО когда человек завёл хоть одну папку (решение
/// заказчика 18.09.2026): пока полок нет, выбирать не из чего, и окно было бы
/// лишним нажатием на пустом месте.
///
/// Возвращает результат добавления. `null` — человек закрыл диалог, ничего не
/// произошло, и экрану не о чем сообщать.
Future<CartResult?> addToCartWithFolder(
  BuildContext context,
  int productId, {
  int quantity = 1,
}) async {
  if (!CartService.hasFolders) {
    return CartService.add(productId, quantity: quantity);
  }

  final chosen = await showFolderPicker(context);

  if (chosen == null) return null;

  return CartService.add(
    productId,
    quantity: quantity,
    folderId: chosen.id,
  );
}

/// Диалог «Выберите папку в корзине».
///
/// Возвращает выбранный пункт либо `null`, если человек закрыл окно.
///
/// Первым пунктом стоит «Без папки» и он же выбран по умолчанию: товар,
/// добавленный без выбора, должен попадать в корзину общим списком, как это
/// работало до появления папок (правка заказчика 18.09.2026). Раскладывать
/// вещи по полкам человек решает сам, а не потому, что окно не оставило ему
/// другого выхода.
Future<CartFolderInfo?> showFolderPicker(
  BuildContext context, {
  String title = 'Выберите папку в корзине',
  int? selectedId,
}) {
  final folders = <CartFolderInfo>[
    const CartFolderInfo(id: null, name: 'Без папки', isMain: true),
    ...CartService.folders.value,
  ];

  return showDialog<CartFolderInfo>(
    context: context,
    builder: (_) => _FolderPickerDialog(
      title: title,
      folders: folders,
      selectedId: selectedId,
    ),
  );
}

/// Что человек заполнил в окне папки (21.09.2026).
///
/// Отдельный тип, а не строка: кроме названия окно теперь знает про
/// обложку, и у обложки три исхода. Выбрал новую (`imagePath`), убрал
/// прежнюю (`removeImage`) или не трогал (оба пусты).
class FolderForm {
  const FolderForm({
    required this.name,
    this.imagePath,
    this.removeImage = false,
    this.delete = false,
  });

  /// Человек нажал «Удалить папку» в окне правки.
  const FolderForm.delete()
      : name = '',
        imagePath = null,
        removeImage = false,
        delete = true;

  final String name;

  /// Путь к выбранной картинке на телефоне или `null`, если новую не брали.
  final String? imagePath;

  /// Человек нажал «Убрать» у прежней обложки.
  final bool removeImage;

  /// Удалить папку целиком (21.09.2026). Подтверждение спрашивает экран.
  final bool delete;
}

/// Диалог «Создания папки в корзине». Возвращает заполненное или `null`.
///
/// Обложка по желанию (21.09.2026): полка «К 1 сентября» с картинкой рюкзака
/// находится глазами быстрее, чем по названию. `initialImage` это ссылка на
/// текущую обложку, когда окно открыто для правки.
///
/// `canDelete` добавляет внизу «Удалить папку»: в окне правки это
/// единственное видимое место, откуда папку можно убрать (21.09.2026). До
/// этого удаление висело на долгом нажатии по плитке, и найти его было
/// нельзя.
Future<FolderForm?> showCreateFolderDialog(
  BuildContext context, {
  String title = 'Создание папки в корзине',
  String notice = 'После создания папка появится в корзине',
  String? initial,
  String? initialImage,
  bool canDelete = false,
}) {
  return showDialog<FolderForm>(
    context: context,
    builder: (_) => _FolderNameDialog(
      title: title,
      notice: notice,
      initial: initial,
      initialImage: initialImage,
      canDelete: canDelete,
    ),
  );
}

/// Диалог подтверждения: удаление товара, очистка корзины.
///
/// Отдельным окном, а не снекбаром с «Отменить»: удаление необратимо, а
/// корзину собирают неделями.
Future<bool> showCartConfirmDialog(
  BuildContext context, {
  required String title,
  required String notice,
  String hint = 'Потвердите действие',
  String action = 'Потвердить',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (_) => _ConfirmDialog(
      title: title,
      notice: notice,
      hint: hint,
      action: action,
    ),
  );

  return answer == true;
}

// ── Оболочка ────────────────────────────────────────────────────────

/// Общий вид окон корзины: заголовок с крестиком, содержимое, «Отмена» и
/// голубая кнопка действия справа.
class _CartDialogShell extends StatelessWidget {
  const _CartDialogShell({
    required this.title,
    required this.children,
    required this.action,
    this.onAction,
  });

  final String title;
  final List<Widget> children;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: onAction == null ? textMuted : activeIconColor,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        color: onAction == null ? textMuted : activeIconColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Жёлтое слово «Внимание» и объяснение рядом, как на макете.
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Внимание: ',
            style: TextStyle(
              color: Color(0xFFE8D44D),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Окна ────────────────────────────────────────────────────────────

class _FolderPickerDialog extends StatefulWidget {
  const _FolderPickerDialog({
    required this.title,
    required this.folders,
    this.selectedId,
  });

  final String title;
  final List<CartFolderInfo> folders;
  final int? selectedId;

  @override
  State<_FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<_FolderPickerDialog> {
  late CartFolderInfo? _chosen = _initial();

  CartFolderInfo? _initial() {
    for (final folder in widget.folders) {
      if (folder.id == widget.selectedId) return folder;
    }

    return widget.folders.isEmpty ? null : widget.folders.first;
  }

  @override
  Widget build(BuildContext context) {
    return _CartDialogShell(
      title: widget.title,
      action: 'Готово',
      onAction: _chosen == null
          ? null
          : () => Navigator.of(context).pop(_chosen),
      children: [
        for (final folder in widget.folders)
          GestureDetector(
            onTap: () => setState(() => _chosen = folder),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Кружок, а не галочка: папку выбирают одну, и круглая
                  // отметка сама говорит, что вариант здесь один.
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _chosen?.id == folder.id
                            ? activeIconColor
                            : textMuted,
                        width: 2,
                      ),
                    ),
                    child: _chosen?.id == folder.id
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeIconColor,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.notice,
    this.initial,
    this.initialImage,
    this.canDelete = false,
  });

  final String title;
  final String notice;
  final String? initial;
  final String? initialImage;
  final bool canDelete;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  // Вид окна повторяет диалог группы в кабинете продавца
  // (`group_dialog.dart`, правка заказчика 21.09.2026): большой блок
  // «Добавить изображение», под ним название, внизу «Отмена» и «Готово».
  // Картинка выбирается тем же листом «Камера / Галерея», что у товаров.

  late final TextEditingController _name =
      TextEditingController(text: widget.initial ?? '');

  /// Новая картинка с телефона. Пока не выбрана, показываем прежнюю.
  String? _pickedPath;

  /// Человек убрал прежнюю обложку.
  bool _removed = false;

  String? get _savedImage {
    final url = widget.initialImage;

    return (!_removed && url != null && url.isNotEmpty) ? url : null;
  }

  bool get _hasCover => _pickedPath != null || _savedImage != null;

  // Контроллер не освобождаем по той же причине, что в диалоге группы:
  // окно закрывается с анимацией, и поле живёт ещё несколько кадров. Живой
  // TextField с мёртвым контроллером подвешивает приложение.

  Future<void> _pickCover() async {
    final picked = await pickProductPhotos(context);

    if (picked.isEmpty || !mounted) return;

    setState(() {
      _pickedPath = picked.first;
      _removed = false;
    });
  }

  void _removeCover() => setState(() {
        _pickedPath = null;
        _removed = true;
      });

  void _submit() {
    final name = _name.text.trim();

    // Папка без названия неотличима от соседней, поэтому пустое имя просто
    // не закрывает окно.
    if (name.isEmpty) return;

    Navigator.of(context).pop(FolderForm(
      name: name,
      imagePath: _pickedPath,

      // «Убрать» имеет смысл только для обложки, которая уже была: у новой
      // папки убирать нечего.
      removeImage: _removed &&
          _pickedPath == null &&
          (widget.initialImage ?? '').isNotEmpty,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: textPrimary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Notice(widget.notice),

            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Изображение папки',
                    style: TextStyle(color: textPrimary, fontSize: 15),
                  ),
                ),
                if (_hasCover)
                  GestureDetector(
                    onTap: _removeCover,
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Убрать',
                      style: TextStyle(color: textSecondary, fontSize: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _photoBlock(),

            const SizedBox(height: 16),
            const Text(
              'Название папки',
              style: TextStyle(color: textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: formBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _name,
                autofocus: (widget.initial ?? '').isEmpty,
                maxLength: 64,
                style: const TextStyle(color: textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: 'Например, Купить к 1 сентября',
                  hintStyle: TextStyle(color: textMuted, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                // Удаление слева и красным, подальше от «Готово»: промахнуться
                // и снести папку вместо сохранения должно быть трудно. Само
                // удаление всё равно переспросит.
                if (widget.canDelete)
                  GestureDetector(
                    onTap: () =>
                        Navigator.pop(context, const FolderForm.delete()),
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Удалить папку',
                      style: TextStyle(color: Colors.redAccent, fontSize: 15),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: activeIconColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoBlock() {
    final local = _pickedPath;
    final saved = _savedImage;

    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: formBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: local != null
            ? Image.file(File(local), fit: BoxFit.cover)
            : saved != null
                ? Image.network(
                    saved,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, color: textSecondary, size: 28),
          SizedBox(height: 8),
          Text(
            'Добавить изображение',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ],
      );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.notice,
    required this.hint,
    required this.action,
  });

  final String title;
  final String notice;
  final String hint;
  final String action;

  @override
  Widget build(BuildContext context) {
    return _CartDialogShell(
      title: title,
      action: action,
      onAction: () => Navigator.of(context).pop(true),
      children: [
        _Notice(notice),
        const SizedBox(height: 10),
        Text(
          hint,
          style: const TextStyle(color: textMuted, fontSize: 14),
        ),
      ],
    );
  }
}
