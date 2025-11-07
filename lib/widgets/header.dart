import 'package:flutter/material.dart';
import '../constants.dart';

class Header extends StatelessWidget {
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
