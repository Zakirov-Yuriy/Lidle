// ============================================================
// Настройка одного способа оплаты (макет 11.09.2026).
// ============================================================
//
// Открывается кнопкой «Настроить» на экране выбранных способов. Пока
// нарисован только для банковской карты, и приложение понимает это по
// текстам справочника: у способов, чей экран ещё не согласован, их нет.
//
// Две вещи на экране:
//
//   привязка — «Привязать карту». За ней стоит платёжный шлюз, которого у
//   нас ещё нет, поэтому кнопка честно говорит об этом, а не открывает
//   пустую форму;
//
//   касса — куда приходят деньги: в кассу или на расчётный счёт. Это
//   выбирается уже сейчас и сохраняется вместе с публикацией.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPaymentMethodScreen extends StatefulWidget {
  const ProductPaymentMethodScreen({
    super.key,
    required this.method,
    required this.accounts,
    this.account,
  });

  final PaymentMethod method;

  /// Куда можно направить деньги: касса и расчётный счёт.
  final List<PaymentAccount> accounts;

  /// Что выбрано сейчас. Пусто — ещё не выбирали.
  final String? account;

  @override
  State<ProductPaymentMethodScreen> createState() =>
      _ProductPaymentMethodScreenState();
}

class _ProductPaymentMethodScreenState
    extends State<ProductPaymentMethodScreen> {
  late String? _account = widget.account;

  String get _accountTitle {
    for (final account in widget.accounts) {
      if (account.key == _account) return account.title;
    }

    return 'Выбрать';
  }

  Future<void> _chooseAccount() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => _AccountDialog(
        accounts: widget.accounts,
        chosen: _account ??
            (widget.accounts.isEmpty ? null : widget.accounts.first.key),
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _account = chosen);
  }

  void _bind() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Привязка ещё не подключена'),
        backgroundColor: secondaryBackground,
      ),
    );
  }

  void _explain() {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: secondaryBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Как это работает',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Привязка нужна, чтобы деньги покупателя доходили до вас без '
                'вашего участия.\n\n'
                'Касса и расчётный счёт это то, куда они попадут. Касса — '
                'наличный оборот точки, расчётный счёт — безналичный. Выбор '
                'влияет на вашу отчётность, поэтому спрашиваем заранее.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(color: activeIconColor, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.method;

    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Header(),
            const SizedBox(height: 8),
            _titleRow(),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _explain,
                  child: const Text(
                    'Как это работает?',
                    style: TextStyle(color: activeIconColor, fontSize: 14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  14,
                  defaultPadding,
                  16,
                ),
                children: [
                  Text(
                    method.field ?? 'Реквизиты',
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _bind,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: activeIconColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        method.action ?? 'Привязать',
                        style: const TextStyle(
                          color: activeIconColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  if (method.actionHint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      method.actionHint!,
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),
                  const Text(
                    'Касса',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _chooseAccount,
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
                              _accountTitle,
                              style: const TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              color: textSecondary, size: 22),
                        ],
                      ),
                    ),
                  ),
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
                onTap: () => Navigator.pop(context, _account),
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activeIconColor,
                    borderRadius: BorderRadius.circular(10),
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
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.chevron_left, color: textPrimary, size: 26),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.method.title,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // «Отмена» уходит, ничего не меняя: настройка остаётся прежней.
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Диалог «Касса»: куда приходят деньги.
///
/// Выбор один, поэтому кружки, а не галочки.
class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.accounts, this.chosen});

  final List<PaymentAccount> accounts;
  final String? chosen;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late String? _chosen = widget.chosen;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: secondaryBackground,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Касса',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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

            for (final account in widget.accounts)
              GestureDetector(
                onTap: () => setState(() => _chosen = account.key),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          account.title,
                          style: const TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      CustomRadioButton<String>(
                        value: account.key,
                        groupValue: _chosen,
                        onChanged: (value) =>
                            setState(() => _chosen = value ?? account.key),
                        selectedBorderColor: const Color(0xFF888888),
                        unselectedBorderColor: const Color(0xFF888888),
                        selectedFillColor: activeIconColor,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
                  onTap: () => Navigator.pop(context, _chosen),
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
}
