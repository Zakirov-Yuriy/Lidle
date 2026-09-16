// ============================================================
//  "Укажите свою почту" (16.09.2026)
//
//  Экран для тех, кто вошёл через соцсеть, а почту ВК не отдал. Такому
//  человеку сервер завёл служебный адрес вида vk_123@social.lidle.io: письма
//  на него не доходят, покупателю его не покажешь, и объявление опубликовать
//  нельзя.
//
//  Сервер умел досбор почты давно (claim-email и confirm-email), но приложение
//  об этом не знало: признак needs_email приходил и терялся. Нашли 16.09.2026,
//  разбирая, почему свежие аккаунты не публикуют объявления.
//
//  Два шага в одном экране, а не два экрана: человек только что вошёл, и
//  прыжок по экранам ради шести цифр выглядит как новая регистрация.
// ============================================================

import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';
import 'package:lidle/services/auth_service.dart';
import 'package:lidle/widgets/components/custom_error_snackbar.dart';
import 'package:lidle/widgets/components/header.dart';

class SocialEmailScreen extends StatefulWidget {
  const SocialEmailScreen({super.key});

  static const String routeName = '/social-email';

  @override
  State<SocialEmailScreen> createState() => _SocialEmailScreenState();
}

class _SocialEmailScreenState extends State<SocialEmailScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();

  /// Шаг: false — вводим почту, true — вводим код.
  bool _waitingCode = false;

  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();

    // Проверка простая и на месте: гонять человека на сервер ради очевидной
    // опечатки значит ждать сеть, чтобы услышать то, что видно сразу.
    if (!email.contains('@') || !email.contains('.') || email.length < 6) {
      SnackBarHelper.showWarning(context, 'Проверьте адрес почты');

      return;
    }

    setState(() => _busy = true);

    try {
      final response = await AuthService.claimSocialEmail(email: email);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _waitingCode = true;
          _busy = false;
        });

        SnackBarHelper.showSuccess(
          context,
          'Код отправлен на $email. Письмо может идти до минуты.',
        );

        return;
      }

      setState(() => _busy = false);

      SnackBarHelper.showError(
        context,
        '${response['message'] ?? 'Не получилось отправить код'}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);

      SnackBarHelper.showError(context, 'Не получилось связаться с сервером');
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();

    if (code.isEmpty) {
      SnackBarHelper.showWarning(context, 'Введите код из письма');

      return;
    }

    setState(() => _busy = true);

    try {
      final response = await AuthService.confirmSocialEmail(
        email: _email.text.trim(),
        code: code,
      );

      if (!mounted) return;

      setState(() => _busy = false);

      if (response['success'] == true) {
        SnackBarHelper.showSuccess(context, 'Почта подтверждена');

        Navigator.of(context).pop(true);

        return;
      }

      SnackBarHelper.showError(
        context,
        '${response['message'] ?? 'Код не подошёл'}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);

      SnackBarHelper.showError(context, 'Не получилось связаться с сервером');
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
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 8, 25, 24),
                children: [
                  Text(
                    _waitingCode ? 'Введите код' : 'Укажите свою почту',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _waitingCode
                        ? 'Мы отправили код на ${_email.text.trim()}. '
                            'Введите его, чтобы подтвердить почту.'
                        : 'Вход через соцсеть прошёл, но почту она нам не '
                            'передала. Без почты вы не получите письма о '
                            'заказах и не сможете опубликовать объявление.',
                    style: const TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (!_waitingCode)
                    _field(
                      controller: _email,
                      hint: 'Ваша почта',
                      keyboard: TextInputType.emailAddress,
                    )
                  else
                    _field(
                      controller: _code,
                      hint: 'Код из письма',
                      keyboard: TextInputType.number,
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeIconColor,
                        disabledBackgroundColor: secondaryBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : (_waitingCode ? _confirm : _sendCode),
                      child: Text(
                        _waitingCode ? 'Подтвердить' : 'Отправить код',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Письмо не дошло — самый частый случай здесь, и выход из
                  // него должен быть на виду. Две кнопки, а не одна: адрес
                  // могли и набрать с опечаткой, как это было у Натальи
                  // 15.09.2026 с лишней буквой в mail.ru.
                  if (_waitingCode) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _busy ? null : _sendCode,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Отправить код ещё раз',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _busy
                          ? null
                          : () => setState(() {
                                _waitingCode = false;
                                _code.clear();
                              }),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Исправить адрес почты',
                          style: TextStyle(
                            color: activeIconColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 25, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            behavior: HitTestBehavior.opaque,
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios, color: activeIconColor, size: 16),
                SizedBox(width: 4),
                Text(
                  'Назад',
                  style: TextStyle(
                    color: activeIconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Уйти можно в любой момент: почта нужна для писем и публикации, а
          // смотреть витрину и покупать человек может и без неё. Запирать его
          // на этом экране значит превратить вход через соцсеть в анкету.
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
            behavior: HitTestBehavior.opaque,
            child: const Text(
              'Позже',
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboard,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: formBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: textMuted, fontSize: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
