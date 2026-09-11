// ============================================================
// Экран «Добавить оплату»: настройка выбранных способов
// (макет 11.09.2026).
// ============================================================
//
// Второй шаг после выбора. Показывает только то, что человек отметил, и у
// каждого способа объясняет, что с ним делать дальше.
//
// Способам, которым нужны реквизиты, показывается кнопка «Настроить».
// Наличным не нужно ничего, поэтому у них вместо кнопки объяснение: кнопка,
// которая ведёт в пустую форму, читается как недоделка.
//
// Что именно настраивается и нужны ли реквизиты, решает сервер: тексты и
// признак приходят вместе со справочником. Вторая копия в приложении рано
// или поздно разъедется с первой.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/models/products/product_publication.dart';
import 'package:lidle/pages/products/add_product/product_payment_company_screen.dart';
import 'package:lidle/pages/products/add_product/product_payment_method_screen.dart';
import 'package:lidle/pages/products/add_product/product_payment_screen.dart';
import 'package:lidle/widgets/components/custom_checkbox.dart';
import 'package:lidle/widgets/components/header.dart';

class ProductPaymentSetupScreen extends StatefulWidget {
  const ProductPaymentSetupScreen({
    super.key,
    required this.chosen,
    required this.dictionary,
    this.settings = const {},
  });

  /// Ключи способов, которые человек отметил.
  final List<String> chosen;

  /// Справочник целиком: названия, подсказки, признак «нужны реквизиты» и
  /// список счетов.
  final PaymentDictionary dictionary;

  /// Настройки, заданные раньше: ключ способа → его настройка.
  final Map<String, PaymentSetting> settings;

  @override
  State<ProductPaymentSetupScreen> createState() =>
      _ProductPaymentSetupScreenState();
}

class _ProductPaymentSetupScreenState extends State<ProductPaymentSetupScreen> {
  late final Map<String, PaymentSetting> _settings = {...widget.settings};

  /// Открыть настройку способа.
  ///
  /// Экран есть пока только у банковской карты. Понимаем это по справочнику:
  /// у способов, чей экран не согласован, сервер не присылает подписей.
  Future<void> _openMethod(PaymentMethod method) async {
    if (!method.hasSetupScreen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Экран настройки этого способа ещё не сделан'),
          backgroundColor: secondaryBackground,
        ),
      );

      return;
    }

    // Какую форму открыть, говорит сервер полем `form`: у карты своя, у
    // СБП реквизиты организации.
    final setting = await Navigator.push<PaymentSetting>(
      context,
      MaterialPageRoute(
        builder: (_) => method.form == 'company'
            ? ProductPaymentCompanyScreen(
                method: method,
                accounts: widget.dictionary.accounts,
                setting: _settings[method.key],
              )
            : ProductPaymentMethodScreen(
                method: method,
                accounts: widget.dictionary.accounts,
                setting: _settings[method.key],
              ),
      ),
    );

    if (setting == null || !mounted) return;

    setState(() => _settings[method.key] = setting);
  }

  @override
  Widget build(BuildContext context) {
    // Порядок справочника, а не порядок нажатий: иначе карточки на экране
    // прыгали бы местами от того, что человек отмечал первым.
    final picked = widget.dictionary.methods
        .where((m) => widget.chosen.contains(m.key))
        .toList();

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
                  const Text(
                    'Настройте выбранные варианты',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (picked.isEmpty)
                    const Text(
                      'Ни один способ не выбран. Вернитесь назад и отметьте, '
                      'чем у вас можно заплатить.',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),

                  for (final method in picked) ...[
                    _card(method),
                    const SizedBox(height: 14),
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
                onTap: () => Navigator.pop(context, _settings),
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
          const Expanded(
            child: Text(
              'Добавить оплату',
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // «Отмена» закрывает оплату целиком, не сохраняя выбор: человек
          // передумал, а не хочет поправить отметки.
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

  Widget _card(PaymentMethod method) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                height: 24,
                child: Center(child: _badge(method.key)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  method.title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            method.hint,
            style: const TextStyle(
              color: textMuted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (_settings[method.key] != null) ...[
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2A3744), height: 1),
            const SizedBox(height: 12),
            _summary(method, _settings[method.key]!),
          ] else if (method.needsSetup) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _openMethod(method),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: activeIconColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Настроить',
                      style: TextStyle(color: activeIconColor, fontSize: 15),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: activeIconColor, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Настроенный способ: что задано и кнопка «Изменить».
  ///
  /// Показываем прямо в карточке, а не прячем за нажатием: человек должен
  /// видеть, чем именно он настроил способ, не проваливаясь внутрь.
  Widget _summary(PaymentMethod method, PaymentSetting setting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setting.last4 != null)
          _line(method.field ?? 'Реквизиты', setting.maskedCard),

        _line('Касса', widget.dictionary.accountTitle(setting.account)),

        // Реквизиты организации. Показываем только заполненное: пустая
        // строка с подписью выглядит как потерянные данные.
        _line('Полное название юр. лица, организации (ООО, ИП)',
            setting.legalName),
        _line('Краткое название юр. лица, организации (ООО, ИП)',
            setting.shortName),
        _line('Наименование проекта в чеках', setting.receiptName),
        _line('ИНН', setting.inn),
        _line('КПП', setting.kpp),

        if (setting.legalName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Самозанятый',
                    style: TextStyle(color: textPrimary, fontSize: 15),
                  ),
                ),
                CustomCheckbox(
                  value: setting.selfEmployed,

                  // Здесь только показываем: менять реквизиты надо на их
                  // экране, а не мимоходом из списка.
                  onChanged: (_) => _openMethod(method),
                ),
              ],
            ),
          ),

        _line('ОГРН', setting.ogrn),

        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => _openMethod(method),
            child: const Text(
              'Изменить',
              style: TextStyle(color: activeIconColor, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  /// Строка «подпись и значение». Пустое значение не показываем вовсе.
  Widget _line(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: textMuted,
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: textPrimary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Значок способа. Берём тот же, что и на экране выбора: два разных набора
  /// значков для одного и того же человек воспримет как разные вещи.
  Widget _badge(String key) {
    final vector = ProductPaymentScreen.vectorFor(key);

    if (vector != null) {
      return SvgPicture.asset(vector, height: 20, fit: BoxFit.contain);
    }

    final image = ProductPaymentScreen.imageFor(key);

    if (image != null) {
      return Image.asset(image, height: 20, fit: BoxFit.contain);
    }

    return const Icon(Icons.payment, color: activeIconColor, size: 16);
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
                'Здесь перечислено только то, что вы отметили.\n\n'
                'Способам, по которым деньги приходят на счёт, нужны '
                'реквизиты: нажмите «Настроить» и заполните их.\n\n'
                'Наличным настраивать нечего: покупатель платит вам при '
                'получении заказа.',
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
}
