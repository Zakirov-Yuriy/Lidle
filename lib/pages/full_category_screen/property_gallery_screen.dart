import 'package:flutter/material.dart';
import 'package:lidle/constants.dart';

class PropertyGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const PropertyGalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<PropertyGalleryScreen> createState() => _PropertyGalleryScreenState();
}

class _PropertyGalleryScreenState extends State<PropertyGalleryScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF243241),
      body: SafeArea(
        child: Column(
          children: [
            // ───── Back ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: activeIconColor,
                      size: 16,
                    ),
                  ),
                  const Text(
                    'Назад',
                    style: TextStyle(
                      color: activeIconColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // ───── Main image ─────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: widget.images.length,
                itemBuilder: (_, index) {
                  return SizedBox(
                    height: 584,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: widget.images[index].startsWith('http')
                            ? Image.network(
                                widget.images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF374B5C),
                                    child: Icon(
                                      Icons.image,
                                      color: textMuted,
                                      size: 50,
                                    ),
                                  );
                                },
                              )
                            : Image.asset(
                                widget.images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF374B5C),
                                    child: Icon(
                                      Icons.image,
                                      color: textMuted,
                                      size: 50,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ───── Counter + Actions ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '${_currentIndex + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // ───── Thumbnails ─────
            Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.images.length, (index) {
                    final isActive = index == _currentIndex;

                    return Padding(
                      padding: EdgeInsets.only(
                        right: index == widget.images.length - 1 ? 0 : 8,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        },
                        child: Container(
                          width: 64,
                          height: 57,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF00B7FF)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: widget.images[index].startsWith('http')
                                ? Image.network(
                                    widget.images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF374B5C),
                                        child: Icon(
                                          Icons.image,
                                          color: textMuted,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  )
                                : Image.asset(
                                    widget.images[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF374B5C),
                                        child: Icon(
                                          Icons.image,
                                          color: textMuted,
                                          size: 20,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
