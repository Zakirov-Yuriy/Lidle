// ============================================================
// Настройка способа оплаты: кошелёк (макет 11.09.2026).
// ============================================================
//
// Открывается кнопкой «Настроить» у ЮMoney. Какую форму открыть, говорит
// сервер полем `form` в справочнике, здесь это `wallet`.
//
// Спрашивается ровно две вещи:
//
//   номер кошелька — куда переводить. Подпись поля приходит с сервера, чтобы
//   переименование кошелька не требовало новой версии приложения;
//
//   касса — наличный или безналичный оборот. Тот же вопрос, что и у
//   остальных способов: он нужен продавцу для отчётности.
//
// Реквизитов организации здесь нет намеренно: кошелёк бывает и у человека без
// юр. лица, а лишние обязательные поля отрезали бы таких продавцов от
// способа, который им как раз и подходит.
//
// Номер набирается с пробелами и дефисами, а хранится цифрами: сервер режет
// лишнее сам, чтобы «410 011-234» и «410011234» не оказались разными
// кошельками.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPaymentWalletScreen extends StatefulWidget {
  const ProductPaymentWalletScreen({
    super.key,
    required this.method,
    required this.accounts,
    this.setting,
  });

  final PaymentMethod method;
  final List<PaymentAccount> accounts;
  final PaymentSetting? setting;

  @override
  State<ProductPaymentWalletScreen> createState() =>
      _ProductPaymentWalletScreenState();
}

class _ProductPaymentWalletScreenState
    extends State<ProductPaymentWalletScreen> {
  // Контроллер намеренно не освобождаем: экран закрывается с анимацией, и
  // поле живёт ещё несколько кадров. Освобождение здесь оставляет живой
  // TextField с мёртвым контроллером, а это зависание приложения.
  late final _wallet = TextEditingController(text: widget.setting?.wallet);

  late String? _account = widget.setting?.account;

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

  void _save() {
    final account = _account;

    if (account == null) {
      _say('Выберите, куда приходят деньги');

      return;
    }

    final wallet = _wallet.text.trim();

    if (wallet.isEmpty) {
      _say('Укажите номер кошелька');

      return;
    }

    Navigator.pop(
      context,
      PaymentSetting(
        account: account,

        // Остальное этому способу не принадлежит, но и терять его нельзя:
        // человек мог настроить кошелёк, а до того завести реквизиты.
        last4: widget.setting?.last4,
        legalName: widget.setting?.legalName,
        shortName: widget.setting?.shortName,
        receiptName: widget.setting?.receiptName,
        inn: widget.setting?.inn,
        kpp: widget.setting?.kpp,
        ogrn: widget.setting?.ogrn,
        selfEmployed: widget.setting?.selfEmployed ?? false,
        wallet: wallet,
      ),
    );
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: secondaryBackground),
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
                'Номер кошелька это то, куда придут деньги покупателя. Он '
                'виден в самом кошельке рядом с балансом и состоит только из '
                'цифр.\n\n'
                'Касса и расчётный счёт это то, как вы этот приход учитываете: '
                'касса — наличный оборот точки, расчётный счёт — безналичный. '
                'Выбор влияет на вашу отчётность, поэтому спрашиваем заранее.',
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
                  const Text('Касса',
                      style: TextStyle(color: textPrimary, fontSize: 15)),
                  const SizedBox(height: 8),
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

                  const SizedBox(height: 22),
                  const Text(
                    'Основная информация',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Подпись поля приходит с сервера: у разных кошельков она
                  // разная, а переименование не должно требовать новой
                  // версии приложения.
                  _field(widget.method.field ?? 'Номер кошелька', _wallet),
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
                onTap: _save,
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

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textSecondary,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: formBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: textPrimary, fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Введите',
                hintStyle: TextStyle(color: textMuted, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Диалог «Касса»: куда приходят деньги.
///
/// Копия того же диалога с соседних экранов. Вынести его в общий файл стоит,
/// когда экранов станет больше трёх: пока перенос тронул бы уже проверенные
/// экраны ради одной новой кнопки.
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
