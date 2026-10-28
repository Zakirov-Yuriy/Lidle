// ============================================================
// "Виджет: Экран подключения CRM"
// ============================================================
//
// Компания подключает свою систему сама (задача 88, 28.10.2026). После
// подключения к ней уходят события площадки: нажали «Позвонить», открыли
// контакты, предложили цену, откликнулись, забронировали, написали в чат.
//
// ЗАЧЕМ ЭТО КОМПАНИИ. Человек посмотрел объявление, позвонил и приехал в
// офис. Для компании это клиент с улицы, и она считает, что с площадки
// обращений нет. Теперь каждое обращение видно в её системе, с указанием
// объявления.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/services/crm_connections_service.dart';
import 'package:lidle/widgets/components/header.dart';

class CrmConnectionsScreen extends StatefulWidget {
  const CrmConnectionsScreen({super.key});

  @override
  State<CrmConnectionsScreen> createState() => _CrmConnectionsScreenState();
}

class _CrmConnectionsScreenState extends State<CrmConnectionsScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const okColor = Color(0xFF34C759);
  static const textSecondary = Colors.white54;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  /// Вид подключения: обычный приёмник или Битрикс24.
  String _kind = 'webhook';

  List<CrmConnection> _items = const [];
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
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await CrmConnectionsService.all();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Не вышло загрузить подключения. Проверьте связь и попробуйте ещё раз.';
      });
    }
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
                      'Подключение CRM',
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 16, 25, 24),
                children: [
                  const Text(
                    'Мы будем присылать в вашу систему обращения по вашим объявлениям: '
                    'нажали «Позвонить», открыли контакты, предложили цену, откликнулись, '
                    'забронировали, написали в переписке. Вместе с обращением приходит '
                    'объявление и контакты человека, если он сам пошёл на связь.',
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildForm(),
                  const SizedBox(height: 28),
                  const Text(
                    'Мои подключения',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Новое подключение',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            maxLength: 120,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Название',
              labelStyle: TextStyle(color: textSecondary),
              hintText: 'Например, Битрикс нашего офиса',
              hintStyle: TextStyle(color: Colors.white24),
              counterText: '',
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Куда подключаем', style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _kindChip('Битрикс24', 'bitrix24'),
              _kindChip('Другая система', 'webhook'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Адрес приёмника',
              labelStyle: TextStyle(color: textSecondary),
              hintText: 'https://ваша-система/приём-заявок',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _kind == 'bitrix24'
                ? 'В Битрикс24 это «входящий вебхук»: Разработчикам, Другое, Входящий вебхук. '
                    'Отметьте права CRM и вставьте сюда полученную ссылку вида '
                    'https://ваш-портал.bitrix24.ru/rest/1/КЛЮЧ/'
                : 'Это адрес, на который ваша система принимает входящие запросы. '
                    'Если не знаете его, спросите у того, кто её настраивал.',
            style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Подключить',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(String title, String value) {
    final selected = _kind == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: _busy ? null : (_) => setState(() => _kind = value),
      backgroundColor: bgColor,
      selectedColor: accentColor,
      labelStyle: TextStyle(color: selected ? Colors.white : textSecondary),
      side: const BorderSide(color: Colors.white24),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
          TextButton(
            onPressed: _load,
            child: const Text('Повторить', style: TextStyle(color: accentColor)),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return const Text(
        'Подключений пока нет. Добавьте адрес приёмника, и обращения начнут приходить к вам.',
        style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
      );
    }

    return Column(
      children: [
        for (final item in _items) ...[
          _buildCard(item),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildCard(CrmConnection item) {
    final broken = item.lastError != null && item.lastError!.trim().isNotEmpty;

    return Container(
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
              Icon(
                broken ? Icons.error_outline : Icons.cloud_done_outlined,
                color: broken ? dangerColor : okColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                onPressed: _busy ? null : () => _confirmRemove(item),
                icon: const Icon(Icons.delete_outline, color: dangerColor),
                tooltip: 'Удалить',
              ),
            ],
          ),
          Text(
            item.kind == 'bitrix24' ? 'Битрикс24' : 'Другая система',
            style: const TextStyle(color: accentColor, fontSize: 12),
          ),
          if (item.url != null) ...[
            const SizedBox(height: 4),
            Text(
              item.url!,
              style: const TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            style: TextStyle(color: broken ? dangerColor : textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : () => _test(item),
                child: const Text('Проверить', style: TextStyle(color: accentColor)),
              ),
              TextButton(
                onPressed: _busy ? null : () => _showDeliveries(item),
                child: const Text('Журнал', style: TextStyle(color: accentColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final url = _urlController.text.trim();

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _say('Адрес должен начинаться с http:// или https://');

      return;
    }

    setState(() => _busy = true);

    try {
      final created = await CrmConnectionsService.create(
        url: url,
        name: _nameController.text,
        kind: _kind,
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _nameController.clear();
        _urlController.clear();
      });

      await _showSecretOnce(created.secret);
      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Подключить не вышло. Проверьте адрес: возможно, их уже три.');
    }
  }

  /// Секрет показывается один раз, как ключ агента.
  Future<void> _showSecretOnce(String secret) async {
    if (!mounted || secret.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Подключение создано', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Вот секрет подключения. Он нужен тому, кто настраивает приём на вашей '
                'стороне: мы подписываем им каждый запрос, чтобы вашей системе было '
                'видно, что письмо от нас, а не от постороннего.',
                style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                child: SelectableText(secret, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Скопируйте его сейчас: второй раз он не покажется.',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              Navigator.of(dialogContext).pop();
              _say('Секрет скопирован.');
            },
            child: const Text('Скопировать', style: TextStyle(color: accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Готово', style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _test(CrmConnection item) async {
    setState(() => _busy = true);

    try {
      await CrmConnectionsService.test(item.id);

      if (!mounted) return;

      setState(() => _busy = false);
      _say('Пробное обращение отправлено. Посмотрите журнал через несколько секунд.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Отправить пробное не вышло.');
    }
  }

  Future<void> _showDeliveries(CrmConnection item) async {
    setState(() => _busy = true);

    List<CrmDelivery> list = const [];

    try {
      list = await CrmConnectionsService.deliveries(item.id);
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Журнал не загрузился.');

      return;
    }

    if (!mounted) return;

    setState(() => _busy = false);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Что уходило',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Пока ничего не отправлялось.',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 20),
                    itemBuilder: (context, index) {
                      final row = list[index];
                      final failed = row.status == 'failed';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.stateLine,
                            style: TextStyle(
                              color: failed ? dangerColor : textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (failed && row.error != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              row.error!,
                              style: const TextStyle(color: dangerColor, fontSize: 12),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(CrmConnection item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Удалить подключение?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Обращения по вашим объявлениям перестанут приходить в «${item.title}».',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить', style: TextStyle(color: dangerColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await CrmConnectionsService.remove(item.id);

      if (!mounted) return;

      setState(() => _busy = false);
      _say('Подключение удалено.');
      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Удалить не вышло. Попробуйте ещё раз.');
    }
  }

  void _say(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: cardColor),
    );
  }
}
