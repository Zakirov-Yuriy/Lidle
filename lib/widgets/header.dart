/// Виджет заголовка приложения, отображающий логотип.
import 'package:flutter/material.dart';
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
        left: defaultPadding,
        bottom: headerBottomPadding,
      ),
      child: Row(
        children: [
          Image.asset(logoAsset, height: logoHeight),
          const Spacer(),
        ],
      ),
    );
  }
}
