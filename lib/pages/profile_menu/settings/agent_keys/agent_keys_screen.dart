// ============================================================
// "Виджет: Экран ключей для ИИ-агентов"
// ============================================================
//
// Человек выпускает ключ себе сам и вставляет его в своего агента: Клода,
// GPT, Алису, любого. Раньше ключ выписывал только администратор в админке,
// куда обычному человеку хода нет (задача 55, 27.10.2026).
//
// КЛЮЧ ПОКАЗЫВАЕТСЯ ОДИН РАЗ. Сервер хранит только отпечаток, поэтому после
// закрытия окна ключ не увидеть ни здесь, ни в админке. Если потерял, нужно
// выпустить новый.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/services/agent_keys_service.dart';
import 'package:lidle/widgets/components/header.dart';

class AgentKeysScreen extends StatefulWidget {
  const AgentKeysScreen({super.key});

  @override
  State<AgentKeysScreen> createState() => _AgentKeysScreenState();
}

class _AgentKeysScreenState extends State<AgentKeysScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const textSecondary = Colors.white54;

  List<AgentKey> _keys = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final keys = await AgentKeysService.all();

      if (!mounted) return;

      setState(() {
        _keys = keys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Не вышло загрузить ключи. Проверьте связь и попробуйте ещё раз.';
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
                      'Ключи для ИИ-агентов',
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
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Ключ нужен, чтобы ваш помощник работал на площадке за вас: '
                'искал, бронировал, подавал объявления и оформлял заказы. '
                'Права у него будут ровно ваши.',
                style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 10, 25, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _openIssueDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Выпустить ключ',
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _load,
                child: const Text('Повторить', style: TextStyle(color: accentColor)),
              ),
            ],
          ),
        ),
      );
    }

    if (_keys.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 25),
          child: Text(
            'Ключей пока нет. Выпустите первый и вставьте его в настройках своего помощника.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 15, height: 1.4),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: accentColor,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        itemCount: _keys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildCard(_keys[index]),
      ),
    );
  }

  Widget _buildCard(AgentKey key) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: accentColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        key.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (key.trusted) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'доверенный',
                        style: TextStyle(color: accentColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  key.subtitle,
                  style: TextStyle(
                    color: key.expired ? dangerColor : textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => _confirmRevoke(key),
            icon: const Icon(Icons.delete_outline, color: dangerColor),
            tooltip: 'Отозвать',
          ),
        ],
      ),
    );
  }

  /// Окно выпуска: название и срок.
  ///
  /// Доверенного уровня здесь нет намеренно: повышенные лимиты нужны крупным
  /// площадкам, и ставит их администратор.
  Future<void> _openIssueDialog() async {
    final nameController = TextEditingController();
    int? days;

    final issue = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: cardColor,
          title: const Text(
            'Новый ключ',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                maxLength: 60,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Для кого ключ',
                  labelStyle: TextStyle(color: textSecondary),
                  hintText: 'Например, Клод на телефоне',
                  hintStyle: TextStyle(color: Colors.white24),
                  counterText: '',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accentColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Срок действия', style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _dayChip('Бессрочно', null, days, (value) => setLocal(() => days = value)),
                  _dayChip('30 дней', 30, days, (value) => setLocal(() => days = value)),
                  _dayChip('90 дней', 90, days, (value) => setLocal(() => days = value)),
                  _dayChip('365 дней', 365, days, (value) => setLocal(() => days = value)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена', style: TextStyle(color: textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Выпустить', style: TextStyle(color: accentColor)),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text;
    nameController.dispose();

    if (issue != true) return;

    setState(() => _busy = true);

    try {
      final issued = await AgentKeysService.issue(
        name: name,
        days: days,
      );

      if (!mounted) return;

      setState(() => _busy = false);
      await _showKeyOnce(issued);
      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Выпустить ключ не вышло. Возможно, их уже пять: отзовите ненужный.');
    }
  }

  Widget _dayChip(String title, int? value, int? current, void Function(int?) onPick) {
    final selected = current == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: (_) => onPick(value),
      backgroundColor: bgColor,
      selectedColor: accentColor,
      labelStyle: TextStyle(color: selected ? Colors.white : textSecondary),
      side: const BorderSide(color: Colors.white24),
    );
  }

  /// Единственный показ ключа.
  Future<void> _showKeyOnce(IssuedAgentKey issued) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Ключ выпущен',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Скопируйте его сейчас: второй раз он не покажется.',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                issued.key,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Вставьте его в настройках своего помощника, в поле заголовка '
              'Authorization или X-Api-Key.',
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: issued.key));

              if (context.mounted) {
                Navigator.pop(context);
              }

              _say('Ключ скопирован.');
            },
            child: const Text('Скопировать', style: TextStyle(color: accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Готово', style: TextStyle(color: textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(AgentKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Отозвать ключ?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Помощник с ключом «${key.name}» сразу перестанет заходить на площадку.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Отозвать', style: TextStyle(color: dangerColor)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);

    try {
      await AgentKeysService.revoke(key.id);

      if (!mounted) return;

      setState(() => _busy = false);
      _say('Ключ отозван.');
      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Отозвать не вышло. Попробуйте ещё раз.');
    }
  }

  void _say(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: cardColor),
    );
  }
}
