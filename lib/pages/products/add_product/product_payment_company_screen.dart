// ============================================================
// Настройка способа оплаты: реквизиты организации (макет 11.09.2026).
// ============================================================
//
// Открывается кнопкой «Настроить» у способов, которым нужны данные
// организации, сейчас это «Системы быстрых платежей». Какую форму открыть,
// говорит сервер полем `form` в справочнике: приложение не держит своего
// списка «что чем настраивается».
//
// Что здесь спрашивается и зачем:
//
//   касса — куда приходят деньги, в кассу или на расчётный счёт;
//   полное и краткое название — так организация называется в документах и в
//   приложении;
//   название в чеках — то, что покупатель увидит в чеке, и оно часто
//   отличается от названия юр. лица: человек покупал в «Москвиче», а не в
//   «ООО Москвич 2140»;
//   ИНН, КПП, ОГРН — по ним платёж находит получателя;
//   самозанятый — у него нет ни КПП, ни ОГРН, поэтому эти поля прячутся.
//
// Номера набираются с пробелами, а хранятся цифрами: сервер режет лишнее
// сам, чтобы «123 445 123» и «123445123» не оказались разными реквизитами.

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/custom_radio_button.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPaymentCompanyScreen extends StatefulWidget {
  const ProductPaymentCompanyScreen({
    super.key,
    required this.method,
    required this.accounts,
    this.setting,
  });

  final PaymentMethod method;
  final List<PaymentAccount> accounts;
  final PaymentSetting? setting;

  @override
  State<ProductPaymentCompanyScreen> createState() =>
      _ProductPaymentCompanyScreenState();
}

class _ProductPaymentCompanyScreenState
    extends State<ProductPaymentCompanyScreen> {
  // Контроллеры намеренно не освобождаем: экран закрывается с анимацией, и
  // поля живут ещё несколько кадров. Освобождение здесь оставляет живой
  // TextField с мёртвым контроллером, а это зависание приложения.
  late final _legal = TextEditingController(text: widget.setting?.legalName);
  late final _short = TextEditingController(text: widget.setting?.shortName);
  late final _receipt =
      TextEditingController(text: widget.setting?.receiptName);
  late final _inn = TextEditingController(text: widget.setting?.inn);
  late final _kpp = TextEditingController(text: widget.setting?.kpp);
  late final _ogrn = TextEditingController(text: widget.setting?.ogrn);

  late String? _account = widget.setting?.account;
  late bool _selfEmployed = widget.setting?.selfEmployed ?? false;

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

    String? text(TextEditingController controller) {
      final value = controller.text.trim();

      return value.isEmpty ? null : value;
    }

    if (text(_legal) == null) {
      _say('Укажите полное название организации');

      return;
    }

    Navigator.pop(
      context,
      PaymentSetting(
        account: account,
        last4: widget.setting?.last4,
        legalName: text(_legal),
        shortName: text(_short),
        receiptName: text(_receipt),
        inn: text(_inn),

        // У самозанятого нет ни КПП, ни ОГРН: сохранять то, что он мог
        // ввести до того, как поставил галочку, значит отдать в платёж
        // чужие номера.
        kpp: _selfEmployed ? null : text(_kpp),
        ogrn: _selfEmployed ? null : text(_ogrn),
        selfEmployed: _selfEmployed,
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
                'По этим данным платёж находит получателя, а покупатель '
                'видит, кому он заплатил.\n\n'
                'Название в чеках часто отличается от названия юр. лица: '
                'человек покупал в «Москвиче», а не в «ООО Москвич 2140».\n\n'
                'Если вы самозанятый, поставьте галочку: КПП и ОГРН у вас '
                'нет, и спрашивать их незачем.',
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

                  _field(
                    'Полное название юр. лица, организации (ООО, ИП)',
                    _legal,
                  ),
                  _field(
                    'Краткое название юр. лица, организации (ООО, ИП)',
                    _short,
                  ),
                  _field('Наименование проекта в чеках', _receipt),
                  _field('ИНН', _inn, digits: true),

                  if (!_selfEmployed) _field('КПП', _kpp, digits: true),

                  GestureDetector(
                    onTap: () =>
                        setState(() => _selfEmployed = !_selfEmployed),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Самозанятый',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          CustomCheckbox(
                            value: _selfEmployed,
                            onChanged: (_) => setState(
                              () => _selfEmployed = !_selfEmployed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (!_selfEmployed) ...[
                    const SizedBox(height: 14),
                    _field('ОГРН', _ogrn, digits: true),
                  ],
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

          // «Отмена» уходит, ничего не меняя: реквизиты остаются прежними.
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

  Widget _field(
    String label,
    TextEditingController controller, {
    bool digits = false,
  }) {
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
              keyboardType:
                  digits ? TextInputType.number : TextInputType.text,
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
