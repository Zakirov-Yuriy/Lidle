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
import 'package:lidle/pages/products/add_product/product_payment_method_screen.dart';
import 'package:lidle/pages/products/add_product/product_payment_screen.dart';
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

  /// Настройки, заданные раньше: ключ способа → счёт.
  final Map<String, String> settings;

  @override
  State<ProductPaymentSetupScreen> createState() =>
      _ProductPaymentSetupScreenState();
}

class _ProductPaymentSetupScreenState extends State<ProductPaymentSetupScreen> {
  late final Map<String, String> _settings = {...widget.settings};

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

    final account = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductPaymentMethodScreen(
          method: method,
          accounts: widget.dictionary.accounts,
          account: _settings[method.key],
        ),
      ),
    );

    if (account == null || !mounted) return;

    setState(() => _settings[method.key] = account);
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
            const SizedBox(height: 8),
            Text(
              'Деньги приходят: '
              '${widget.dictionary.accountTitle(_settings[method.key])}',
              style: const TextStyle(color: textPrimary, fontSize: 14),
            ),
          ],
          if (method.needsSetup) ...[
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
