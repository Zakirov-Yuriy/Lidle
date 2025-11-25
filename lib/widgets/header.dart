/// Виджет заголовка приложения, отображающий логотип.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';

/// `Header` - это StatelessWidget, который отображает
/// логотип приложения в верхней части экрана.
class Header extends StatelessWidget {
  /// Конструктор для `Header`.
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: headerTopPadding,
        left: headerLeftPadding,
      ),
      child: Row(
        children: [
          SvgPicture.asset(logoAsset, height: logoHeight),
        ],
      ),
    );
  }
}
