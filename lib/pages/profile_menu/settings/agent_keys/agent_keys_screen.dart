// ============================================================
// "Виджет: Экран ключей для ИИ-агентов"
// ============================================================
//
// Человек выпускает ключ себе сам и вставляет его в своего помощника: Клода,
// GPT, Алису, любого. Раньше ключ выписывал только администратор в админке,
// куда обычному человеку хода нет (задача 55, 27.10.2026).
//
// ФОРМА ПРЯМО НА ЭКРАНЕ, а не в окне (27.10.2026). Так же, как в админке:
// поле «для кого», срок и уровень видны сразу, и выпуск это одно нажатие, а
// не два. Поля живут в состоянии экрана, поэтому не теряются и не
// уничтожаются по второму разу: на окне это и ловило падение при повторном
// выпуске.
//
// КЛЮЧ ПОКАЗЫВАЕТСЯ ОДИН РАЗ. Сервер хранит только отпечаток, поэтому после
// закрытия окна ключ не увидеть ни здесь, ни в админке. Потерял, значит
// выпускай новый.

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

  final TextEditingController _nameController = TextEditingController();

  List<AgentKey> _keys = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  /// Срок действия в днях. Пусто означает бессрочно.
  int? _days;

  /// Повышенные лимиты.
  bool _trusted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(25, 16, 25, 24),
                children: [
                  const Text(
                    'Ключ нужен, чтобы ваш помощник работал на площадке за вас: '
                    'искал, бронировал, подавал объявления и оформлял заказы. '
                    'Права у него будут ровно ваши.',
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildForm(),
                  const SizedBox(height: 28),
                  const Text(
                    'Мои ключи',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildKeys(),
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
            'Новый ключ',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            maxLength: 60,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Для кого этот ключ',
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
          const SizedBox(height: 18),
          const Text('Срок действия', style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _dayChip('Бессрочно', null),
              _dayChip('30 дней', 30),
              _dayChip('90 дней', 90),
              _dayChip('365 дней', 365),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : () => setState(() => _trusted = !_trusted),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _trusted,
                  onChanged: _busy ? null : (value) => setState(() => _trusted = value == true),
                  activeColor: accentColor,
                  side: const BorderSide(color: Colors.white38),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Доверенный ключ. Нужен крупным площадкам вроде Яндекса: '
                      'у него выше предел обращений в минуту и в сутки. '
                      'Обычному помощнику он не требуется.',
                      style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _issue,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Выпустить ключ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeys() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Повторить', style: TextStyle(color: accentColor)),
          ),
        ],
      );
    }

    if (_keys.isEmpty) {
      return const Text(
        'Ключей пока нет. Выпустите первый и вставьте его в настройках своего помощника.',
        style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
      );
    }

    return Column(
      children: [
        for (final key in _keys) ...[
          _buildCard(key),
          const SizedBox(height: 12),
        ],
      ],
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

  Widget _dayChip(String title, int? value) {
    final selected = _days == value;

    return ChoiceChip(
      label: Text(title),
      selected: selected,
      onSelected: _busy ? null : (_) => setState(() => _days = value),
      backgroundColor: bgColor,
      selectedColor: accentColor,
      labelStyle: TextStyle(color: selected ? Colors.white : textSecondary),
      side: const BorderSide(color: Colors.white24),
    );
  }

  Future<void> _issue() async {
    setState(() => _busy = true);

    try {
      final issued = await AgentKeysService.issue(
        name: _nameController.text,
        days: _days,
        trusted: _trusted,
      );

      if (!mounted) return;

      setState(() {
        _busy = false;
        _nameController.clear();
        _days = null;
        _trusted = false;
      });

      await _showKeyOnce(issued.key);
      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _busy = false);
      _say('Выпустить ключ не вышло. Возможно, их уже пять: отзовите ненужный.');
    }
  }

  /// Единственный показ ключа.
  Future<void> _showKeyOnce(String key) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text(
          'Ключ выпущен',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
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
                  key,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Вставьте его в настройках своего помощника, в заголовок '
                'Authorization или X-Api-Key.',
                style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: key));
              Navigator.of(dialogContext).pop();
              _say('Ключ скопирован.');
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

  Future<void> _confirmRevoke(AgentKey key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Отозвать ключ?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text(
          'Помощник с ключом «${key.name}» сразу перестанет заходить на площадку.',
          style: const TextStyle(color: textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
