// ============================================================
// "Виджет: Экран подключения служб доставки"
// ============================================================
//
// Задача 53, 16.11.2026.
//
// Компания подключает СВОИ договоры: со СДЭК, Яндексом, Озоном. Решение Саши
// 16.11.2026, дословно про причину: если мы будем деньги через себя гонять,
// у нас налогообложение другое будет. Поэтому мы даём только функционал,
// расчёты и ответственность за доставку остаются между компанией и службой.
//
// ЭКРАН СТРОИТСЯ ПО ОТВЕТУ СЕРВЕРА. Службы и поля их ключей приходят с
// сервера, здесь ничего не зашито. Следующая служба появится у всех сразу,
// без новой сборки приложения.
//
// КЛЮЧИ НАЗАД НЕ ПРИХОДЯТ. Сервер хранит их зашифрованными и наружу не
// отдаёт. Поле секрета всегда пустое, а под ним написано, сохранён ключ или
// нет. Ввод поверх заменяет прежний.

import 'package:flutter/material.dart';
import 'package:lidle/services/delivery_connections_service.dart';
import 'package:lidle/services/help_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/widgets/components/help_tile.dart';

class DeliveryConnectionsScreen extends StatefulWidget {
  const DeliveryConnectionsScreen({super.key});

  @override
  State<DeliveryConnectionsScreen> createState() =>
      _DeliveryConnectionsScreenState();
}

class _DeliveryConnectionsScreenState extends State<DeliveryConnectionsScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const okColor = Color(0xFF34C759);
  static const textSecondary = Colors.white54;

  /// Поля ввода по ключу службы и ключу поля: cdek.client_id и так далее.
  final Map<String, TextEditingController> _fields = {};

  /// Какая служба сейчас раскрыта. Все сразу раскрывать незачем: подключают
  /// их по одной.
  String? _open;

  /// Тестовый режим по службе.
  final Map<String, bool> _test = {};

  /// Поля, которые человек уже правил руками. Нужны, чтобы перерисовка не
  /// затирала то, что он печатает прямо сейчас.
  final Set<String> _tronuto = {};

  List<DeliveryConnection> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await DeliveryConnectionsService.all();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;

        for (final item in items) {
          _test[item.provider] = item.isTest;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Не вышло загрузить службы. Проверьте связь и попробуйте ещё раз.';
      });
    }
  }

  DeliveryConnection? _connectionOf(String provider) {
    for (final item in _items) {
      if (item.provider == provider) return item;
    }

    return null;
  }

  TextEditingController _controller(String provider, String field) {
    return _fields.putIfAbsent('$provider.$field', () => TextEditingController());
  }

  void _say(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20, right: 23),
              child: Row(children: [Header()]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Службы доставки',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: accentColor,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(25, 16, 25, 24),
                  children: [
                    const HelpTile(
                      slug: 'delivery',
                      margin: EdgeInsets.only(bottom: 20),
                    ),
                    const Text(
                      'Подключите свои договоры со службами доставки. Покупатель увидит '
                      'стоимость и срок, выберет пункт выдачи, а заказ уйдёт в службу. '
                      'Деньги за доставку идут мимо нас, договор у вас со службой напрямую.',
                      style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: accentColor),
                        ),
                      )
                    else if (_error != null)
                      Text(
                        _error!,
                        style: const TextStyle(color: dangerColor, fontSize: 14),
                      )
                    else
                      ...DeliveryConnectionsService.providers.map(_providerCard),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerCard(DeliveryProviderInfo provider) {
    final connection = _connectionOf(provider.key);
    final open = _open == provider.key;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      connection == null ? provider.about : connection.state,
                      style: TextStyle(
                        color: _stateColor(connection),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _open = open ? null : provider.key),
                child: Text(
                  open
                      ? 'Свернуть'
                      : (connection == null ? 'Подключить' : 'Настроить'),
                  style: const TextStyle(color: accentColor),
                ),
              ),
            ],
          ),

          // Ошибка службы прямо в карточке: человек читает её здесь, а не
          // идёт в поддержку.
          if (connection?.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              connection!.lastError!,
              style: const TextStyle(color: dangerColor, fontSize: 13, height: 1.4),
            ),
          ],

          if (open) ...[
            const SizedBox(height: 14),

            // Инструкция именно по этой службе (задача 53, 25.11.2026).
            //
            // ЗАЧЕМ ОНА ЗДЕСЬ, А НЕ ОДНА СВЕРХУ. Общая инструкция наверху
            // отвечает на вопрос «что вообще происходит», а человек,
            // нажавший «Подключить», уже спрашивает другое: где у ЭТОЙ
            // службы лежат ключи. Раньше подробно был описан только СДЭК,
            // и про остальные три спрашивали в поддержке.
            //
            // Текст приходит с сервера и правится в админке: кабинеты
            // служб меняются чаще, чем наш код.
            if (provider.help.isNotEmpty)
              HelpTile(
                slug: provider.help,
                margin: const EdgeInsets.only(bottom: 16),
              ),

            ...provider.fields.map((field) => _field(provider, field, connection)),

            // Настройки отправителя: откуда везём. Без них служба считать
            // не может, поэтому они тут же, а не в отдельном месте.
            if (provider.settings.isNotEmpty) ...[
              const Text(
                'Откуда отправляете',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ...provider.settings.map(
                (field) => _field(provider, field, connection, setting: true),
              ),
            ],

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: accentColor,
              value: _test[provider.key] ?? false,
              onChanged: (value) => setState(() => _test[provider.key] = value),
              title: const Text(
                'Тестовый режим',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: const Text(
                'Учебный контур службы: посылки никуда не едут. Ключи для него служба выдаёт отдельно, боевые там не работают.',
                style: TextStyle(color: textSecondary, fontSize: 12, height: 1.3),
              ),
            ),

            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _button(
                    'Сохранить',
                    accentColor,
                    _busy ? null : () => _save(provider),
                  ),
                ),
                if (connection != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _button(
                      'Проверить связь',
                      bgColor,
                      _busy ? null : () => _check(connection),
                    ),
                  ),
                ],
              ],
            ),

            if (connection != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _toggle(connection),
                    child: Text(
                      connection.isActive ? 'Выключить' : 'Включить',
                      style: const TextStyle(color: textSecondary),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : () => _remove(connection),
                    child: const Text(
                      'Отключить совсем',
                      style: TextStyle(color: dangerColor),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _field(
    DeliveryProviderInfo provider,
    DeliveryField field,
    DeliveryConnection? connection, {
    bool setting = false,
  }) {
    final saved = connection?.filled[field.key] == true;

    final controller = _controller(provider.key, field.key);

    // Настройки сервер отдаёт обратно, поэтому подставляем сохранённое
    // значение: человек правит его, а не вводит заново. С ключами так
    // нельзя, их сервер не отдаёт.
    if (setting && !_tronuto.contains('${provider.key}.${field.key}')) {
      final value = connection?.settings[field.key] ?? '';

      if (controller.text != value) controller.text = value;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: (_) => _tronuto.add('${provider.key}.${field.key}'),
            controller: controller,
            obscureText: field.secret,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: field.label,
              labelStyle: const TextStyle(color: textSecondary),
              hintText: saved ? 'Ключ сохранён, введите новый для замены' : null,
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: accentColor),
              ),
            ),
          ),
          if (field.hint != null) ...[
            const SizedBox(height: 6),
            Text(
              field.hint!,
              style: const TextStyle(color: textSecondary, fontSize: 12, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Color _stateColor(DeliveryConnection? connection) {
    if (connection == null) return textSecondary;

    // Состояние приходит строкой с сервера, и в ней может быть перечень
    // незаполненных полей, поэтому сравниваем по началу, а не целиком.
    if (connection.state == 'работает') return okColor;

    if (connection.state == 'служба ответила ошибкой' ||
        connection.state.startsWith('не заполнено')) {
      return dangerColor;
    }

    return textSecondary;
  }

  Future<void> _save(DeliveryProviderInfo provider) async {
    final credentials = <String, String>{};

    for (final field in provider.fields) {
      credentials[field.key] = _controller(provider.key, field.key).text;
    }

    final settings = <String, String>{};

    for (final field in provider.settings) {
      settings[field.key] = _controller(provider.key, field.key).text.trim();
    }

    final test = _test[provider.key] ?? false;
    final connection = _connectionOf(provider.key);

    // Ключи нужны всегда, и в тестовом режиме тоже: у учебного контура свои
    // ключи, служба выдаёт их отдельно (проверено 16.11.2026). Проверяем
    // только при первом подключении: дальше они уже сохранены, и человек
    // может менять один тестовый режим, ничего не вводя.
    if (connection == null) {
      for (final field in provider.fields) {
        if (field.required_ && credentials[field.key]!.trim().isEmpty) {
          _say('Заполните поле «${field.label}»');

          return;
        }
      }
    }

    setState(() => _busy = true);

    final error = await DeliveryConnectionsService.save(
      provider: provider.key,
      credentials: credentials,
      settings: settings,
      isTest: test,
    );

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) {
      _say(error);

      return;
    }

    // Чистим только ключи: они уже на сервере, и держать их на экране
    // незачем. Настройки остаются на виду, их человек правит.
    for (final field in provider.fields) {
      _controller(provider.key, field.key).clear();
    }

    for (final field in provider.settings) {
      _tronuto.remove('${provider.key}.${field.key}');
    }

    await _load();

    if (mounted) _say('Сохранено. Проверьте связь.');
  }

  Future<void> _check(DeliveryConnection connection) async {
    setState(() => _busy = true);

    final error = await DeliveryConnectionsService.check(connection.id);

    if (!mounted) return;

    setState(() => _busy = false);

    _say(error ?? 'Связь есть, ключи приняты');

    await _load();
  }

  Future<void> _toggle(DeliveryConnection connection) async {
    setState(() => _busy = true);

    final error = await DeliveryConnectionsService.toggle(connection.id);

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) _say(error);

    await _load();
  }

  Future<void> _remove(DeliveryConnection connection) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Отключить службу?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Ключи будут удалены. Покупатели перестанут видеть доставку этой службой.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отключить', style: TextStyle(color: dangerColor)),
          ),
        ],
      ),
    );

    if (yes != true) return;

    setState(() => _busy = true);

    final error = await DeliveryConnectionsService.remove(connection.id);

    if (!mounted) return;

    setState(() => _busy = false);

    if (error != null) _say(error);

    await _load();
  }

  Widget _button(String text, Color color, VoidCallback? onTap) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withOpacity(0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ),
    );
  }
}
