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

import 'package:flutter/material.dart';

import 'package:lidle/constants.dart';
import 'package:lidle/models/orders/cart_snapshot.dart';
import 'package:lidle/services/cart_service.dart';

/// Положить товар в корзину, спросив папку, если есть из чего выбирать.
///
/// Диалог показываем ТОЛЬКО когда у человека есть свои папки (решение
/// заказчика 18.09.2026): окно с единственным пунктом «Основная папка» это
/// лишнее нажатие на пустом месте.
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
/// Возвращает выбранную папку либо `null`, если человек передумал. Основная
/// папка в списке обычным пунктом: это такой же выбор, как остальные, и
/// прятать её значит заставлять искать, куда деть вещь «просто в корзину».
Future<CartFolderInfo?> showFolderPicker(
  BuildContext context, {
  String title = 'Выберите папку в корзине',
  int? selectedId,
}) {
  final folders = CartService.folders.value;

  return showDialog<CartFolderInfo>(
    context: context,
    builder: (_) => _FolderPickerDialog(
      title: title,
      folders: folders,
      selectedId: selectedId,
    ),
  );
}

/// Диалог «Создания папки в корзине». Возвращает название или `null`.
Future<String?> showCreateFolderDialog(
  BuildContext context, {
  String title = 'Создания папки в корзине',
  String notice = 'После создания папка появиться в корзине',
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderNameDialog(
      title: title,
      notice: notice,
      initial: initial,
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
  });

  final String title;
  final String notice;
  final String? initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CartDialogShell(
      title: widget.title,
      action: 'Готово',
      onAction: () {
        final name = _name.text.trim();

        // Папка без названия неотличима от соседней, поэтому пустое имя
        // просто не закрывает окно.
        if (name.isEmpty) return;

        Navigator.of(context).pop(name);
      },
      children: [
        _Notice(widget.notice),
        const SizedBox(height: 14),
        const Text(
          'Название группы',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: formBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _name,
            autofocus: true,
            maxLength: 64,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              hintText: 'Введите',
              hintStyle: TextStyle(color: textMuted, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
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
