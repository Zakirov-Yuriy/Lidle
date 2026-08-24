// ============================================================
//  "Ряд иконок «Поделиться»"
//  ВК, Яндекс, ОК, почта, Telegram, MAX — один вид и одно поведение
//  для всех экранов: профиль продавца, карточка объявления и т.д.
//  Раньше эта логика жила только в seller_profile_screen.
// ============================================================

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareIconsRow extends StatelessWidget {
  /// Ссылка, которой делимся.
  final String url;

  /// Сопроводительный текст (заголовок объявления, имя продавца и т.п.).
  final String text;

  const ShareIconsRow({
    super.key,
    required this.url,
    required this.text,
  });

  /// Порядок плиток — как на макете.
  static const _socials = [
    ('ВКонтакте', 'assets/socials/vk.png', 'vk'),
    ('Яндекс', 'assets/socials/yandex.png', 'yandex'),
    ('Одноклассники', 'assets/socials/ok.png', 'ok'),
    ('Электронная почта', 'assets/socials/email.png', 'email'),
    ('Telegram', 'assets/socials/telegram.png', 'telegram'),
    ('MAX', 'assets/socials/max.png', 'max'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _socials.length;
        const spacing = 8.0; // зазор между плитками
        const maxTile = 46.0; // как на макете; на широком экране не больше

        // Ширина плитки под доступное место с учётом зазоров: на узком экране
        // плитки уменьшаются и никогда не переполняют строку.
        final raw = (constraints.maxWidth - spacing * (count - 1)) / count;
        final tile = raw > maxTile ? maxTile : raw;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final s in _socials)
              _ShareTile(
                label: s.$1,
                asset: s.$2,
                size: tile,
                onTap: () => _shareVia(s.$3),
              ),
          ],
        );
      },
    );
  }

  /// Открывает нужный способ шаринга. Для соцсетей — web/deep-link через
  /// url_launcher; если не вышло (нет приложения или браузера) — системный
  /// лист шаринга.
  Future<void> _shareVia(String kind) async {
    final encUrl = Uri.encodeComponent(url);
    final encText = Uri.encodeComponent(text);
    final encAll = Uri.encodeComponent('$text\n$url');

    String? link;
    switch (kind) {
      case 'vk':
        link = 'https://vk.com/share.php?url=$encUrl&title=$encText';
        break;
      case 'ok':
        link = 'https://connect.ok.ru/offer?url=$encUrl&title=$encText';
        break;
      case 'telegram':
        link = 'https://t.me/share/url?url=$encUrl&text=$encText';
        break;
      case 'whatsapp':
        link = 'https://wa.me/?text=$encAll';
        break;
      case 'email':
        link = 'mailto:?subject=$encText&body=$encAll';
        break;
      case 'yandex':
        // У Яндекса нет универсального web-share intent — системный лист
        // (можно выбрать Яндекс.Мессенджер или почту, если установлены).
        await Share.share('$text\n\n$url');
        return;
      case 'max':
        // У MAX нет публичного share-URL — системный лист.
        await Share.share('$text\n\n$url');
        return;
      default:
        await Share.share('$text\n\n$url');
        return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) await Share.share('$text\n\n$url');
    } catch (_) {
      await Share.share('$text\n\n$url');
    }
  }
}

/// Квадратная кнопка-иконка. [size] считается под ширину экрана, иконка
/// внутри масштабируется пропорционально макету (24 из 46).
class _ShareTile extends StatelessWidget {
  final String asset;
  final String label;
  final double size;
  final VoidCallback onTap;

  const _ShareTile({
    required this.asset,
    required this.label,
    required this.onTap,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size * (24 / 46);

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Плитка темнее панели секции — как на макете.
            color: const Color(0xFF17212B),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Image.asset(asset, width: iconSize, height: iconSize),
        ),
      ),
    );
  }
}