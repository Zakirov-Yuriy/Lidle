// ============================================================
//  "Аватар пользователя"
//  Единая точка отрисовки аватарки: если ссылки нет или картинка не
//  загрузилась — показываем общую заглушку default-photo.svg.
//  Использовать везде, где рисуется аватар человека или компании,
//  чтобы заглушка по проекту была одна и та же.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Общая заглушка аватара по всему проекту.
const String kDefaultAvatarAsset = 'assets/profile_dashboard/default-photo.svg';

class UserAvatar extends StatelessWidget {
  /// Ссылка на аватар с сервера. null/пусто/не http — покажем заглушку.
  final String? url;

  /// Диаметр аватара.
  final double size;

  const UserAvatar({
    super.key,
    this.url,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final link = url?.trim();
    final hasLink = link != null && link.isNotEmpty && link.startsWith('http');

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasLink
            ? Image.network(
                link,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Битая ссылка или нет сети — та же заглушка, что и без ссылки.
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return SvgPicture.asset(
      kDefaultAvatarAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
