// ============================================================
// "Экран: Ссылки" — сайт и соцсети компании (макет 11.09.2026).
// ============================================================
//
// Открывается со строки «Ссылки» на экране контактных данных компании. Под
// каждым типом поле ввода, под полем «Добавить ещё» и «Отключить».
//
// «Добавить ещё» даёт второе поле того же типа: у компании бывает два канала
// в Telegram или сайт и лендинг. «Отключить» убирает поле; последнее поле
// типа не исчезает совсем, а очищается, иначе тип пропал бы с экрана и его
// нельзя было бы заполнить заново.
//
// СПИСОК ТИПОВ ПРИХОДИТ С СЕРВЕРА вместе с подсказками в полях: приложение не
// держит второй копии, иначе добавление новой соцсети требовало бы новой
// версии приложения.
//
// Telegram и MAX здесь же, одним списком с остальными. Внутри они лежат в
// своих таблицах (на их id ссылается публикация объявления), но человеку это
// знать незачем — для него это такие же ссылки.

import 'package:flutter/material.dart';
import 'package:lidle/services/company_contact_service.dart';
import 'package:lidle/services/token_service.dart';
import 'package:lidle/core/logger.dart';
import 'package:lidle/widgets/components/header.dart';

/// Ссылка: тип и адрес.
class CompanyLink {
  const CompanyLink({required this.type, required this.url});

  final String type;
  final String url;
}

/// Тип ссылки из справочника сервера.
class CompanyLinkType {
  const CompanyLinkType({
    required this.code,
    required this.title,
    required this.placeholder,
  });

  final String code;
  final String title;
  final String placeholder;
}

class CompanyLinksScreen extends StatefulWidget {
  const CompanyLinksScreen({super.key});

  @override
  State<CompanyLinksScreen> createState() => _CompanyLinksScreenState();
}

class _CompanyLinksScreenState extends State<CompanyLinksScreen> {
  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF17212B);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);

  List<CompanyLinkType> _types = [];

  /// Поля по типам: ключ — код типа, значение — контроллеры его полей.
  ///
  /// Контроллеры намеренно не освобождаем: экран закрывается с анимацией, и
  /// поля живут ещё несколько кадров. Освобождение здесь оставляет живой
  /// TextField с мёртвым контроллером, а это зависание приложения.
  final Map<String, List<TextEditingController>> _fields = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await CompanyContactService.getLinks(
        token: TokenService.currentToken,
      );

      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      final types = <CompanyLinkType>[];

      for (final raw in (data['types'] as List? ?? const [])) {
        if (raw is! Map) continue;

        final code = '${raw['code'] ?? ''}'.trim();
        final title = '${raw['title'] ?? ''}'.trim();

        if (code.isEmpty || title.isEmpty) continue;

        types.add(CompanyLinkType(
          code: code,
          title: title,
          placeholder: '${raw['placeholder'] ?? ''}'.trim(),
        ));
      }

      final saved = <String, List<String>>{};

      for (final raw in (data['links'] as List? ?? const [])) {
        if (raw is! Map) continue;

        final type = '${raw['type'] ?? ''}'.trim();
        final url = '${raw['url'] ?? ''}'.trim();

        if (type.isEmpty || url.isEmpty) continue;

        saved.putIfAbsent(type, () => []).add(url);
      }

      if (!mounted) return;

      setState(() {
        _types = types;
        _fields.clear();

        for (final type in types) {
          final urls = saved[type.code] ?? const <String>[];

          // Пустое поле под каждым типом, даже если ссылки нет: так человек
          // видит, что этот канал вообще можно указать.
          _fields[type.code] = urls.isEmpty
              ? [TextEditingController()]
              : urls.map((url) => TextEditingController(text: url)).toList();
        }

        _isLoading = false;
      });
    } catch (e) {
      log.d('❌ Не удалось загрузить ссылки: $e');

      if (!mounted) return;

      setState(() {
        _error = 'Не удалось загрузить ссылки. Потяните вниз, чтобы повторить.';
        _isLoading = false;
      });
    }
  }

  void _addField(String type) {
    setState(() => _fields[type]?.add(TextEditingController()));
  }

  /// «Отключить»: убрать поле.
  ///
  /// Последнее поле типа не удаляем, а очищаем: иначе тип исчез бы с экрана
  /// совсем и заполнить его заново было бы нечем.
  void _removeField(String type, int index) {
    setState(() {
      final list = _fields[type];

      if (list == null) return;

      if (list.length == 1) {
        list.first.clear();
      } else {
        list.removeAt(index);
      }
    });
  }

  List<CompanyLink> _collect() {
    final links = <CompanyLink>[];

    for (final type in _types) {
      for (final controller in (_fields[type.code] ?? const [])) {
        final url = controller.text.trim();

        if (url.isEmpty) continue;

        links.add(CompanyLink(type: type.code, url: url));
      }
    }

    return links;
  }

  /// «Готово»: сохранить и вернуть список наверх.
  ///
  /// Сохраняем прямо здесь, а не на экране компании: сервер проверяет каждую
  /// ссылку, и об ошибке человек должен узнать, пока поля перед глазами.
  Future<void> _done() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final links = _collect();

    try {
      await CompanyContactService.changeLinks(
        links: links.map((l) => {'type': l.type, 'url': l.url}).toList(),
        token: TokenService.currentToken,
      );

      if (!mounted) return;

      Navigator.pop(context, links);
    } catch (e) {
      log.d('❌ Не удалось сохранить ссылки: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
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
              child: Row(
                children: [
                  GestureDetector(
                    // Стрелка назад уходит, ничего не сохраняя: человек мог
                    // зайти посмотреть, а сохранение здесь ещё и проверяется
                    // сервером.
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ссылки',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Добавьте сюда ваши ссылки на социальные сети, которые будут '
                'отображаться для ваших клиентов',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),

            const SizedBox(height: 14),

            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _isLoading = true;
            _error = null;
          });

          await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final type in _types) ..._typeBlock(type),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: SizedBox(
            width: double.infinity,
            height: 47,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: _isSaving ? null : _done,
              child: Text(
                _isSaving ? 'Сохраняем…' : 'Готово',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _typeBlock(CompanyLinkType type) {
    final controllers = _fields[type.code] ?? const <TextEditingController>[];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(25, 6, 25, 6),
        child: Text(
          type.title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),

      for (var i = 0; i < controllers.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: fieldColor,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controllers[i],
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: type.placeholder,
                hintStyle: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(25, 6, 25, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _addField(type.code),
                child: const Text(
                  'Добавить ещё',
                  style: TextStyle(color: accentColor, fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: () => _removeField(type.code, i),
                child: const Text(
                  'Отключить',
                  style: TextStyle(color: dangerColor, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }
}
