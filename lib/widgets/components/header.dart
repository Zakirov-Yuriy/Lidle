// ============================================================
//  "Заголовок"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';

class Header extends StatelessWidget {
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
