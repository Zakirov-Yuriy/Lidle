import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/constants.dart';

/// ============================================================
/// "Виджет: Поле для выбора и загрузки фотографий"
/// ============================================================
/// Компонент для выбора фотографий из камеры или галереи.
/// Поддерживает отображение загруженных фото в сетке GridView.
/// Автоматически управляет удалением изображений.
/// ============================================================
class PhotoPickerField extends StatefulWidget {
  /// Начальный список изображений (если есть)
  final List<File> initialImages;

  /// Callback когда список изображений изменился
  final ValueChanged<List<File>> onImagesChanged;

  /// Максимальное количество изображений (по умолчанию нет лимита)
  final int? maxImages;

  /// Размер миниатюры в GridView
  final Size thumbnailSize;

  const PhotoPickerField({
    required this.initialImages,
    required this.onImagesChanged,
    this.maxImages,
    this.thumbnailSize = const Size(115, 89),
    super.key,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  late List<File> _images;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  /// Выбор изображения из источника (камера или галерея)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _images.add(File(pickedFile.path));
        });
        widget.onImagesChanged(_images);
      }
    } catch (e) {
      // Логирование и обработка ошибок изоляция выбором изображения
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при выборе изображения')),
        );
      }
    }
  }

  /// Удаление изображения по индексу
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
    widget.onImagesChanged(_images);
  }

  /// BottomSheet для выбора источника изображения (камера/галерея)
  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF232E3C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 13.0),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SvgPicture.asset(
                        'assets/showImageSourceActionSheet/camera-01.svg',
                      ),
                      title: const Text(
                        'Сделать фотографию',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SvgPicture.asset(
                        'assets/showImageSourceActionSheet/image-01.svg',
                      ),
                      title: const Text(
                        'Загрузить фотографию',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Проверка лимита на количество изображений
  bool _isMaxImagesReached() {
    return widget.maxImages != null && _images.length >= widget.maxImages!;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isMaxImagesReached()
          ? null
          : () {
              _showImageSourceActionSheet(context);
            },
      child: Container(
        decoration: BoxDecoration(
          color: _images.isEmpty ? secondaryBackground : primaryBackground,
          borderRadius: BorderRadius.circular(5),
        ),
        child: _images.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(top: 28.0),
                      child: Icon(
                        Icons.add_circle_outline,
                        color: textSecondary,
                        size: 40,
                      ),
                    ),
                    SizedBox(height: 3),
                    Padding(
                      padding: EdgeInsets.only(bottom: 27.0),
                      child: Text(
                        'Добавить изображение',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio:
                      widget.thumbnailSize.width / widget.thumbnailSize.height,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _isMaxImagesReached() ? _images.length : _images.length + 1,
                itemBuilder: (context, index) {
                  // Кнопка добавления нового изображения (если не достигнут лимит)
                  if (index == _images.length) {
                    return GestureDetector(
                      onTap: () => _showImageSourceActionSheet(context),
                      child: Container(
                        width: widget.thumbnailSize.width,
                        height: widget.thumbnailSize.height,
                        decoration: BoxDecoration(
                          color: formBackground,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            color: textSecondary,
                            size: 30,
                          ),
                        ),
                      ),
                    );
                  }

                  // Отображение загруженного изображения
                  return Container(
                    width: widget.thumbnailSize.width,
                    height: widget.thumbnailSize.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(
                            _images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 7,
                          right: 11,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
