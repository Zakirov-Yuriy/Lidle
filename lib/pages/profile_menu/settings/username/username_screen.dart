// ============================================================
// "Виджет: Экран изменения имени пользователя"
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/services/user_service.dart';

/// Короткое имя пользователя (задача 62).
///
/// ЧТО БЫЛО ДО 12.10.2026. Экран существовал, поле работало, а кнопка
/// «Подтвердить» просто закрывала окно: запроса на сервер не было вовсе.
/// Короткое имя мог завести только администратор через админку, а человек
/// видел на своём профиле собачку с обычным именем и считал, что оно у него
/// уже есть.
class UsernameScreen extends StatefulWidget {
  static const routeName = '/username';

  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const okColor = Color(0xFF4CD964);
  static const badColor = Color(0xFFFF6B6B);

  final TextEditingController _usernameController = TextEditingController();

  /// Что лежало в поле, когда экран открылся. По нему понимаем, менял ли
  /// человек имя вообще: своё прежнее имя занятым считать нельзя.
  String _initial = '';

  /// Поле уже заполнено значением из профиля.
  bool _filled = false;

  /// Проверка занятости: ждём, пока человек допечатает.
  Timer? _checkTimer;
  bool _checking = false;

  /// Свободно ли имя. `null` это «ещё не знаем» или «спросить не удалось».
  bool? _free;

  /// Что не так с именем, если не так. Пусто, когда всё в порядке.
  String _problem = '';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Загружаем профиль для получения текущего username
    context.read<ProfileBloc>().add(LoadProfileEvent());

    _usernameController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _usernameController.removeListener(_onChanged);
    _usernameController.dispose();
    super.dispose();
  }

  /// Имя без собачки и пробелов по краям.
  String get _value => _usernameController.text.trim();

  /// Человек печатает: сбрасываем прежний ответ и ждём паузы.
  void _onChanged() {
    _checkTimer?.cancel();

    final value = _value;

    setState(() {
      _free = null;
      _problem = _localProblem(value);
    });

    if (value.isEmpty || value == _initial || _problem.isNotEmpty) {
      return;
    }

    // Шестьсот миллисекунд: спрашивать сервер на каждую букву незачем, а
    // ждать дольше человек уже замечает.
    _checkTimer = Timer(const Duration(milliseconds: 600), _check);
  }

  /// То, что видно без сервера. Правила те же, что в `ChangeNameRequest`.
  String _localProblem(String value) {
    if (value.isEmpty) return '';

    if (value.length < 2) return 'Слишком короткое, нужно хотя бы два знака';

    if (value.length > 50) return 'Слишком длинное, не больше пятидесяти знаков';

    if (!RegExp(r'^[\p{L}\p{N}._\-]+$', unicode: true).hasMatch(value)) {
      return 'Можно буквы, цифры, точку, дефис и подчёркивание';
    }

    return '';
  }

  Future<void> _check() async {
    final value = _value;

    if (value.isEmpty) return;

    setState(() => _checking = true);

    final free = await UserService.isNicknameFree(
      value,
      token: TokenService.currentToken,
    );

    if (!mounted) return;

    setState(() {
      _checking = false;
      _free = free;
    });
  }

  /// Сохранить короткое имя.
  ///
  /// Имя и фамилия уходят ТЕМ ЖЕ запросом и на сервере обязательны, поэтому
  /// подставляем их из профиля. Отправить одно короткое имя нельзя.
  Future<void> _save(ProfileLoaded? profile) async {
    if (_saving) return;

    final value = _value;
    final problem = _localProblem(value);

    if (problem.isNotEmpty) {
      setState(() => _problem = problem);

      return;
    }

    if (_free == false) {
      setState(() => _problem = 'Это короткое имя уже занято');

      return;
    }

    final token = TokenService.currentToken;

    if (token == null) {
      _say('Войдите заново, срок сессии истёк');

      return;
    }

    final name = (profile?.name ?? UserService.getLocal('name') ?? '').toString();
    final lastName =
        (profile?.lastName ?? UserService.getLocal('lastName') ?? '').toString();

    if (name.trim().isEmpty) {
      _say('Сначала заполните имя в личной информации');

      return;
    }

    setState(() => _saving = true);

    try {
      final response = await UserService.updateName(
        name: name,
        lastName: lastName,
        // Пустое поле это отказ от короткого имени, сервер примет null.
        nickname: value,
        token: token,
      );

      if (!mounted) return;

      if (response['success'] == false) {
        setState(() => _saving = false);
        _say(response['message']?.toString() ?? 'Сохранить не удалось');

        return;
      }

      // Профиль перечитываем, чтобы новое имя сразу встало и в настройках, и
      // в личной информации, и на самом профиле: все три экрана берут его из
      // одного места.
      await UserService.saveLocal('username', '@$value');

      // ОБЯЗАТЕЛЬНО forceRefresh (12.10.2026). Обычная загрузка профиля при
      // живом кеше отдаёт то, что в нём лежит, и вовсе не ходит на сервер:
      // после сохранения экраны показывали бы прежнее имя ещё пять минут.
      context.read<ProfileBloc>().add(LoadProfileEvent(forceRefresh: true));

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      log.d('❌ Не удалось сохранить короткое имя: $e');

      if (!mounted) return;

      setState(() => _saving = false);
      _say('Сохранить не удалось, попробуйте ещё раз');
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Подпись под полем: занято, свободно или что не так.
  Widget _hint() {
    if (_problem.isNotEmpty) {
      return Text(
        _problem,
        style: const TextStyle(color: badColor, fontSize: 13),
      );
    }

    if (_checking) {
      return const Text(
        'Проверяем...',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      );
    }

    if (_value.isEmpty || _value == _initial) {
      // Молчать здесь нельзя: поле само отбрасывает неподходящие знаки, и без
      // подписи это выглядит поломкой (12.10.2026).
      return const Text(
        'Буквы, цифры, точка, дефис и подчёркивание. '
        'Пробел станет подчёркиванием',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      );
    }

    if (_free == true) {
      return const Text(
        'Имя свободно',
        style: TextStyle(color: okColor, fontSize: 13),
      );
    }

    if (_free == false) {
      return const Text(
        'Имя уже занято',
        style: TextStyle(color: badColor, fontSize: 13),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(children: const [Header()]),
            ),

            // ───── Back row ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
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
                        const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Имя пользователя',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── Description ─────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Вы можете выбрать публичное имя пользователя. '
                'В этом случае другие люди смогут найти вас не зная вашего номера телефона.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ───── Input ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  // Заполняем поле ОДИН раз, настоящим коротким именем, а не
                  // тем, что показано в профиле: там при пустом имени стоит
                  // подставленное обычное имя с собачкой, и человек сохранил
                  // бы его себе как короткое.
                  if (state is ProfileLoaded && !_filled) {
                    _filled = true;
                    _initial = (state.nickname ?? '').trim();
                    _usernameController.text = _initial;
                  }

                  return Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      // Только то, что примет сервер. Собачку и пробелы в
                      // поле не пускаем вовсе: она закреплена слева.
                      inputFormatters: [
                        // Пробел превращаем в подчёркивание (12.10.2026):
                        // компании называются в два и три слова, и ООО
                        // Авангард должно становиться ООО_Авангард само, а не
                        // упираться в отказ. Пробел в имени оставить нельзя,
                        // оно работает как адрес.
                        _SpaceToUnderscore(),
                        // Буквы ЛЮБОГО алфавита, не только латиница: компании
                        // пишутся и по-русски, и по-английски.
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[\p{L}\p{N}._\-]', unicode: true),
                        ),
                        LengthLimitingTextInputFormatter(50),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixText: '@',
                        prefixStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        hintText: 'Name',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: _hint(),
            ),

            const SizedBox(height: 10),

            // ───── Confirm button ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: BlocBuilder<ProfileBloc, ProfileState>(
                  builder: (context, state) {
                    final profile = state is ProfileLoaded ? state : null;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: _saving ? null : () => _save(profile),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Подтвердить',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Пробел в коротком имени превращается в подчёркивание (12.10.2026).
///
/// Отдельным форматировщиком, а не заменой в обработчике: так знак меняется
/// прямо под пальцем, и человек видит, что получилось, ещё до сохранения.
class _SpaceToUnderscore extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains(RegExp(r'\s'))) {
      return newValue;
    }

    return TextEditingValue(
      text: newValue.text.replaceAll(RegExp(r'\s'), '_'),
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
