import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lidle/constants.dart';

class CreateListingScreen extends StatefulWidget {
  static const String routeName = '/create-listing';

  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

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
                    padding: const EdgeInsets.only(right: 43.0),
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
                        _pickImage(ImageSource.camera);
                        Navigator.of(context).pop();
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
                        _pickImage(ImageSource.gallery);
                        Navigator.of(context).pop();
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

  void _addImage() {
    _showImageSourceActionSheet(context);
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: AddListingForm(
          images: _images,
          onAddImage: _addImage,
          onRemoveImage: _removeImage,
        ),
      ),
    );
  }
}

class AddListingForm extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAddImage;
  final Function(int index) onRemoveImage;

  const AddListingForm({
    super.key,
    required this.images,
    required this.onAddImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: defaultPadding, right: defaultPadding, top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------- Заголовок -------------
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'Создайте объявление',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 17),

          // -------------------- Подзаголовок ---------------------
          const Text(
            'Опишите товар или услугу',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),

          const SizedBox(height: 6),
          const Text(
            'Изображение',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),

          const SizedBox(height: 9),

          // -------------------- Сетка изображений ---------------------
          _buildImageGrid(context),

          const SizedBox(height: 28),

          // -------------------- Заголовок ---------------------
          const Text(
            'Заголовок объявления',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 9),

          _field(hint: 'Например, футболка мужская белая'),

          const SizedBox(height: 7),
          const Text(
            'Введите не менее 16 символов',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),

          const SizedBox(height: 15),

          // -------------------- Категория ---------------------
          const Text('Категория', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 7),

          _categoryTile(context),

          const SizedBox(height: 13),

          // -------------------- Описание ---------------------
          const Text('Описание', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 8),

          _descriptionField(),

          const SizedBox(height: 12),
          const Text(
            'Введите не менее 70 символов',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),

          const SizedBox(height: 17),

          // -------------------- Цена ---------------------
          const Text('Цена*', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 9),

          Padding(
            padding: const EdgeInsets.only(bottom: 23.0),
            child: Row(
              children: [
                Expanded(
                  child: _field(
                    hint: '1 000 000',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 50,
                  width: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: secondaryBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '₽',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  //  Grid of Images
  // =======================================================================

  Widget _buildImageGrid(BuildContext context) {
    const cellSize = 95.0;
    final List<Widget> children = [];

    // Уже добавленные изображения
    for (var i = 0; i < images.length; i++) {
      children.add(_imageCell(images[i], i));
    }

    // Кнопка добавления
    children.add(_addImageCell());

    return Wrap(spacing: 10, runSpacing: 10, children: children);
  }

  // Image preview with delete button
  Widget _imageCell(File img, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.file(
            img,
            width: 115,
            height: 89,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => onRemoveImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black87,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  // Add Image Button
  Widget _addImageCell() {
    return GestureDetector(
      onTap: onAddImage,
      child: Container(
        width: 115,
        height: 89,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: secondaryBackground,
        ),
        child: const Center(
          child: Icon(Icons.add_circle_outline_outlined, color: Colors.white54, size: 28),
        ),
      ),
    );
  }

  // =======================================================================
  //  Category Tile
  // =======================================================================

  Widget _categoryTile(BuildContext context) {
    // Get arguments from route
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    final source = args?['source'];

    // Default values
    String hint = 'Продажа квартир';
    String subtitle = 'Недвижимость / Квартиры';

    // Set based on source
    if (source == 'rent') {
      hint = 'Аренда квартир';
      subtitle = 'Недвижимость';
    } else if (source == 'sell') {
      hint = 'Продажа квартир';
      subtitle = 'Недвижимость / Квартиры';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: secondaryBackground,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: textMuted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Изменить',
              style: TextStyle(color: Colors.lightBlueAccent),
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================================
  //  Fields
  // =======================================================================

  Widget _field({required String hint, TextInputType? keyboardType}) {
    return TextField(
      keyboardType: keyboardType,
      style: const TextStyle(color: textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textPrimary, fontSize: 14),
        filled: true,
        fillColor: secondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: _border(),
        focusedBorder: _border(),
      ),
    );
  }

  Widget _descriptionField() {
    return TextField(
      maxLines: 5,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText:
            'Чем больше информации вы укажите о вашем товаре, тем более привлекателен он будет для клиентов.\nБез ссылок, телефонов, матерных слов.',
        hintStyle: const TextStyle(color: textMuted, height: 1.35),
        filled: true,
        fillColor: secondaryBackground,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: _border(),
        focusedBorder: _border(),
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: Colors.transparent),
  );
}
