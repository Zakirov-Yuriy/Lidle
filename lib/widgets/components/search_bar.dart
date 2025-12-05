// ============================================================
//  "Панель поиска"
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/constants.dart';

class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    this.onMenuPressed,
    this.onSettingsPressed,
    this.onSearchChanged,
  });

  final VoidCallback? onMenuPressed;

  final VoidCallback? onSettingsPressed;

  final ValueChanged<String>? onSearchChanged;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onMenuPressed,
            child: const Icon(Icons.menu, color: textPrimary, size: 28),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: secondaryBackground,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: textPrimary, fontSize: 16),

                      decoration: InputDecoration(
                        hintText: searchPlaceholder,
                        hintStyle: const TextStyle(
                          color: textMuted,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onSettingsPressed,
                    child: SvgPicture.asset(
                      settingsIconAsset,
                      height: 24,
                      width: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
