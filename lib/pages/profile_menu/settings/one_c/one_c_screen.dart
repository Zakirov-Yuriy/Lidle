// ============================================================
// "Виджет: Обмен с 1С"
// ============================================================
//
// Задача 54, 10.11.2026.
//
// ЗАЧЕМ ЭТОТ ЭКРАН. Компания выгружает каталог и цены из своей 1С прямо к нам.
// До сегодняшнего дня ключ для этого выдавала наша команда на сервере: годится
// для проверки, не годится для жизни. Подключающихся компаний будет много, и
// бегать к нам за каждым ключом никто не станет.
//
// ЧТО ЗДЕСЬ ЕСТЬ: подключить обмен и получить адреса с ключом, увидеть
// состояние по каждому каналу отдельно, прочитать последнюю ошибку, выключить
// обмен, выдать новый ключ. И счёт со сроком подписки, чтобы было видно, за
// что платим.
//
// АДРЕСА ПОКАЗЫВАЕМ ЦЕЛИКОМ И ВСЕГДА, в отличие от секрета CRM. Там секрет
// вставляют один раз в чужой приёмник, здесь ключ лежит в адресе, который
// программист компании вставляет в настройки обмена и потом сверяет. Прятать
// его значит заставлять выдавать новый при каждой пересборке настроек.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lidle/services/one_c_service.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lidle/widgets/components/help_tile.dart';
import 'package:lidle/services/help_service.dart';

class OneCScreen extends StatefulWidget {
  const OneCScreen({super.key});

  static const routeName = '/one_c';

  @override
  State<OneCScreen> createState() => _OneCScreenState();
}

class _OneCScreenState extends State<OneCScreen> {
  static const bgColor = Color(0xFF243241);
  static const cardColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);
  static const dangerColor = Color(0xFFFF3B30);
  static const okColor = Color(0xFF34C759);
  static const warnColor = Color(0xFFE0B33C);
  static const textSecondary = Colors.white54;

  OneCState? _state;
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

    final state = await OneCService.state();

    if (!mounted) return;

    setState(() {
      _state = state;
      _loading = false;
      _error = state == null ? 'Не удалось получить состояние обмена' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12, right: 23),
              child: Row(children: [Header()]),
            ),
            _buildBack(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBack() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: [
            const Icon(Icons.chevron_left, color: accentColor, size: 26),
            const Text(
              'Обмен с 1С',
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w500,
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

    final state = _state;

    if (state == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error ?? 'Не удалось получить состояние обмена',
            textAlign: TextAlign.center,
            style: const TextStyle(color: textSecondary, fontSize: 15),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: accentColor,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Инструкция по подключению (задача 94, 13.11.2026). Текст на
          // сервере, правится в админке, один на приложение и на сайт.
          const HelpTile(
            slug: HelpService.oneC,
            margin: EdgeInsets.only(bottom: 12),
          ),
          _shopCard(state),
          const SizedBox(height: 12),
          if (state.processorReady) ...[
            _processorCard(state),
            const SizedBox(height: 12),
          ],
          if (!state.connected) _notConnectedCard() else ...[
            _urlsCard(state),
            const SizedBox(height: 12),
            _channelsCard(state),
            if (state.lastError.isNotEmpty) ...[
              const SizedBox(height: 12),
              _errorCard(state),
            ],
            const SizedBox(height: 12),
            _billingCard(state),
            const SizedBox(height: 12),
            _actionsCard(state),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: textSecondary, fontSize: 14),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopCard(OneCState state) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Точка продаж'),
          _line('Витрина', state.shopName),
          _line('Товаров из обмена', '${state.productsCount}'),
          if (state.connected)
            _line('Обмен', state.isActive ? 'включён' : 'выключен'),
        ],
      ),
    );
  }

  Widget _notConnectedCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Обмен не подключён'),
          const SizedBox(height: 6),
          const Text(
            'Подключите обмен, и мы выдадим адреса с ключом. Их передают '
            'программисту, который настраивает выгрузку в вашей 1С. Доступ к '
            'вашей базе нам не нужен: 1С сама отправляет нам то, что вы в неё '
            'положите.',
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          _button('Подключить обмен', accentColor, _connect),
        ],
      ),
    );
  }

  /// Готовая обработка для 1С.
  ///
  /// СТОИТ ВЫШЕ АДРЕСОВ НАРОЧНО. Адреса нужны тому, кто пишет выгрузку сам, а
  /// это меньшинство. Большинству нужен файл: открыл в своей 1С, вставил ключ,
  /// нажал кнопку. Поэтому наверху лежит короткая дорога, а длинная под ней.
  ///
  /// Показываем и до подключения обмена: человек сначала смотрит, что вообще
  /// придётся делать, и только потом решает подключаться.
  Widget _processorCard(OneCState state) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Готовый файл для 1С'),
          const SizedBox(height: 6),
          const Text(
            'Скачайте файл и откройте его в своей 1С через Файл, Открыть. '
            'Он сам найдёт в вашей базе товары, цены и остатки. Останется '
            'вставить ключ, выбрать вид цен и нажать выгрузить. Программист '
            'для этого не нужен.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          _button('Скачать обработку для 1С', accentColor, () async {
            final uri = Uri.tryParse(state.processorUrl);

            if (uri == null) {
              _say('Ссылка на файл не пришла, обновите экран');

              return;
            }

            // Внешним приложением: файл скачивает браузер, внутри приложения
            // его всё равно некуда положить.
            final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

            if (!ok) _say('Не удалось открыть ссылку');
          }),

          /*
           * ПАМЯТКА ОТСЮДА УБРАНА (задача 94, 13.11.2026).
           *
           * Те же шесть шагов теперь лежат в инструкции наверху экрана, и
           * держать их в двух местах значит однажды поправить одно и забыть
           * другое. Сами шаги не потеряны: они переехали в текст инструкции
           * целиком, вместе с сочетанием клавиш и предупреждением про вопрос
           * 1С о безопасности, найденными на живом человеке 11.11.2026.
           */

          /*
           * АДРЕС СЕРВЕРА И КЛЮЧ ПРЯМО ЗДЕСЬ, ПОД ПАМЯТКОЙ.
           *
           * Продавец открыл обработку и видит пустое поле «Сервер». Откуда ему
           * знать наш адрес? Ниже в карточке адресов он есть, но внутри длинной
           * ссылки вместе с ключом, и выковырять из неё хост человек не должен.
           *
           * Поэтому показываем ровно два значения, ровно в том виде, в каком их
           * вставляют в обработку. Хост берётся из адреса, пришедшего с
           * сервера, поэтому на дев-сборке покажется дев, на проде прод.
           */
          // До подключения обмена ключа ещё нет, и показывать пустые поля
          // незачем: человек решит, что чего-то не хватает.
          if (state.token.isNotEmpty) ...[
            const SizedBox(height: 6),
            _title('Что вставить в обработку'),
            const SizedBox(height: 2),
            const Text(
              'Два поля в открывшемся окне 1С. Больше ничего вводить не нужно.',
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
            _copyRow('Сервер', state.serverHost, 'Адрес сервера скопирован'),
            _copyRow('Ключ', state.token, 'Ключ скопирован'),
          ],
        ],
      ),
    );
  }

  /// Строка «подпись, значение, кнопка скопировать».
  ///
  /// Отдельно от `_urlRow`: там значение это длинная ссылка мелким шрифтом, а
  /// здесь короткое значение, которое человек сверяет глазами с тем, что
  /// вставил в 1С.
  Widget _copyRow(String label, String value, String said) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    value.isEmpty ? 'нет данных' : value,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: value.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: value));
                    _say(said);
                  },
            child: const Text(
              'Скопировать',
              style: TextStyle(color: accentColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Три адреса целиком, с ключом внутри.
  ///
  /// СПРЯТАНЫ ПОД РАСКРЫВАШКУ НАРОЧНО (12.11.2026). С готовой обработкой они
  /// не нужны: она собирает адреса сама из имени сервера и ключа, которые
  /// стоят выше. Раскрытыми они отвечали на вопрос, которого у продавца нет,
  /// и мешали найти то, что ему правда нужно.
  ///
  /// Но и убирать их нельзя. Компания с переделанной базой, где обработка не
  /// найдёт поля, пишет выгрузку сама, и тогда адреса единственный способ их
  /// узнать. Отдельно нужен и адрес цен: обработка гонит цены вместе с
  /// каталогом, а своя выгрузка может обновлять их каждые четверть часа
  /// отдельно.
  Widget _urlsCard(OneCState state) {
    return _card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: textSecondary,
          collapsedIconColor: textSecondary,
          title: _title('Если выгрузку пишет ваш программист'),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Адреса для своей выгрузки, ключ уже внутри. С готовым файлом '
              'они не нужны.',
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          children: [
            _urlRow('Проверка ключа', state.pingUrl),
            _urlRow('Каталог, раз в сутки', state.catalogUrl),
            _urlRow('Цены и остатки, часто', state.pricesUrl),
            const SizedBox(height: 14),

            /*
             * ИНСТРУКЦИЯ ЛЕЖИТ ЗДЕСЬ ЖЕ, А НЕ ОТДЕЛЬНОЙ КАРТОЧКОЙ.
             *
             * Кому нужны адреса, тому нужна и она: своей выгрузке мало ключа,
             * нужны названия полей, формат, признак полной выгрузки и разбор
             * ответов. Продавцу она не нужна вовсе, поэтому и прячется вместе
             * с адресами.
             */
            if (state.docsReady) ...[
              const Text(
                'Полное описание обмена: адреса, названия полей, примеры '
                'выгрузок, ответы и ошибки. Передайте программисту вместе с '
                'адресами.',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _button('Скачать документацию', cardColor, () async {
                final uri = Uri.tryParse(state.docsUrl);

                if (uri == null) {
                  _say('Ссылка на документацию не пришла, обновите экран');

                  return;
                }

                final ok =
                    await launchUrl(uri, mode: LaunchMode.externalApplication);

                if (!ok) _say('Не удалось открыть ссылку');
              }),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _urlRow(String label, String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                _say('Адрес скопирован');
              },
              child: const Text(
                'Скопировать',
                style: TextStyle(color: accentColor, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelsCard(OneCState state) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Что приезжало'),
          const SizedBox(height: 6),
          const Text(
            'Каналы показаны порознь: каталог ходит редко, цены часто. Одна '
            'общая строка скрыла бы, что каталог не обновлялся неделю.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          _line('Каталог', _when(state.catalogLastAt, state.catalogItems)),
          _line('Цены и остатки', _when(state.pricesLastAt, state.pricesItems)),

          /*
           * ЖДУТ НАШЕГО РАЗБОРА (12.11.2026).
           *
           * Товар заводится, только если мы узнали его раздел. Названия групп
           * у каждой компании свои, поэтому часть каталога на первой выгрузке
           * не заводится, и человек ищет причину у себя: в ключе, в правах, в
           * настройках обмена.
           *
           * Поэтому говорим прямо: товары не пропали, их разбираем мы, и от
           * компании сейчас ничего не нужно.
           */
          if (state.waitingItems > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Ждут нашего разбора: ${state.waitingItems} позиций '
                'в ${state.waitingGroups} группах. Это товары, разделы которых '
                'мы пока не сопоставили со своими. Мы это сделаем и сообщим, '
                'после чего выгрузите каталог ещё раз. От вас сейчас ничего '
                'не нужно.',
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorCard(OneCState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2E14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warnColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последняя ошибка',
            style: TextStyle(
              color: warnColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.lastError,
            style: const TextStyle(
              color: Color(0xFFE8D6A8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _billingCard(OneCState state) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Оплата'),
          if (!state.billingEnabled) ...[
            const SizedBox(height: 6),
            const Text(
              'Сейчас оплата за обмен не взимается. Счёт ниже показан, чтобы '
              'было понятно, из чего он сложится.',
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
          if (state.firstTime) ...[
            _line('За подключение, разово', _money(state.feeConnection)),
            _line('За товары, разово', _money(state.feeProducts)),
          ],
          _line('За месяц витрины', _money(state.feeMonthly)),
          _line('Итого', _money(state.feeTotal)),
          if (state.endsAt.isNotEmpty)
            _line('Оплачено до', _date(state.endsAt)),
          if (state.hiddenByBilling > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Скрыто за неоплату: ${state.hiddenByBilling}. Товары не '
              'удалены и вернутся на витрину после оплаты.',
              style: const TextStyle(color: warnColor, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsCard(OneCState state) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Управление'),
          const SizedBox(height: 10),
          _button(
            state.isActive ? 'Выключить обмен' : 'Включить обмен',
            state.isActive ? warnColor : okColor,
            () => _setActive(!state.isActive),
          ),
          const SizedBox(height: 8),
          const Text(
            'Выключенный обмен ничего не принимает. Нужно, когда у вас '
            'переезжает база или правится выгрузка и в неё летит лишнее.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _button('Выдать новый ключ', accentColor, _confirmNewKey),
          const SizedBox(height: 8),
          const Text(
            'Прежний перестанет работать сразу. Нужно, если ключ мог попасть '
            'не в те руки.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _button('Отключить обмен', dangerColor, _confirmDisconnect),
          const SizedBox(height: 8),
          const Text(
            'Загруженные товары останутся на витрине, обновлять их будет '
            'нечем.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _when(String iso, int items) {
    if (iso.isEmpty) return 'ещё не приезжал';

    return '${_date(iso)}, позиций: $items';
  }

  String _date(String iso) {
    final parsed = DateTime.tryParse(iso);

    if (parsed == null) return iso;

    final local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');

    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  String _money(double value) {
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} руб.';
  }

  Future<void> _connect() async {
    await _run(OneCService.connect);
  }

  Future<void> _setActive(bool active) async {
    await _run(() => OneCService.setActive(active));
  }

  Future<void> _confirmNewKey() async {
    final ok = await _ask(
      'Выдать новый ключ',
      'Прежний ключ перестанет работать сразу, и выгрузка из 1С остановится, '
      'пока программист не вставит новые адреса.',
      'Выдать',
    );

    if (ok) await _run(OneCService.newKey);
  }

  Future<void> _confirmDisconnect() async {
    final ok = await _ask(
      'Отключить обмен',
      'Выгрузка из вашей 1С перестанет приниматься. Загруженные товары '
      'останутся на витрине.',
      'Отключить',
    );

    if (ok) await _run(OneCService.disconnect);
  }

  /// Любое действие: выполнить, показать ответ сервера, перечитать состояние.
  ///
  /// Подпись берём от сервера, а не придумываем свою: он один знает, что
  /// именно произошло.
  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);

    try {
      final response = await action();

      if (!mounted) return;

      final message = '${response['message'] ?? ''}'.trim();

      if (message.isNotEmpty) _say(message);
    } catch (e) {
      if (mounted) _say('Не удалось, попробуйте ещё раз');
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    await _load();
  }

  Future<bool> _ask(String title, String text, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          text,
          style: const TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action, style: const TextStyle(color: dangerColor)),
          ),
        ],
      ),
    );

    return result == true;
  }

  void _say(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
