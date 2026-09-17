// ============================================================
// "Переход в свой магазин из нижнего меню"
// ============================================================
//
// Экран магазина ждёт имя, аватарку и id продавца, а нижнее меню рисуется на
// любом экране и своего состояния профиля не имеет. Поэтому данные берём из
// локальной памяти: они кладутся туда при входе и обновляются при каждой
// загрузке профиля. Сам экран всё равно перечитывает продавца с сервера,
// переданные значения нужны ему только на первую отрисовку.
//
// Одно место на все копии нижней панели: панель существует в общем виджете и
// в четырёх экранах со своими копиями, и повторять переход пять раз значит
// завести пять мест, где он может разойтись.

import 'package:flutter/material.dart';

import 'package:lidle/pages/full_category_screen/seller_profile_screen.dart';
import 'package:lidle/services/user_service.dart';

/// Открыть витрину текущего пользователя.
void openMyStore(BuildContext context) {
  final me = (UserService.getLocal('userId')?.toString() ?? '')
      .replaceFirst('ID: ', '')
      .trim();

  if (me.isEmpty) return;

  final nickRaw = (UserService.getLocal('username')?.toString() ?? '').trim();
  final nick = nickRaw.startsWith('@') ? nickRaw.substring(1).trim() : nickRaw;
  final accountName = (UserService.getLocal('name')?.toString() ?? '').trim();
  final displayName = nick.isNotEmpty ? nick : accountName;

  final avatar = (UserService.getLocal('profileImage')?.toString() ?? '').trim();

  final ImageProvider avatarProvider =
      avatar.startsWith('http://') || avatar.startsWith('https://')
          ? NetworkImage(avatar)
          : const AssetImage('assets/profile_dashboard/default-photo.svg');

  Navigator.of(context).push(
    MaterialPageRoute(
      // Имя маршрута нужно нижнему меню: по нему подсвечивается пункт
      // магазина, когда человек уже стоит на своей витрине.
      settings: const RouteSettings(name: SellerProfileScreen.routeName),
      builder: (_) => SellerProfileScreen(
        sellerName: displayName,
        sellerAvatar: avatarProvider,
        sellerAvatarUrl: avatar.isEmpty ? null : avatar,
        userId: me,
      ),
    ),
  );
}
