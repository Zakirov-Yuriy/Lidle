import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  // Устанавливаем стиль системной панели
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LidleApp());
}

class LidleApp extends StatelessWidget {
  const LidleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LIDLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF232E3C),
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF232E3C),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header с логотипом
            _buildHeader(),

            // Строка поиска
            _buildSearchBar(),

            // Scrollable контент
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Секция категорий
                    _buildCategoriesSection(),

                    const SizedBox(height: 25),

                    // Секция "Самое новое"
                    _buildLatestSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // Header с логотипом LIDLE
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 44, left: 72, bottom: 35),
      child: Row(
        children: [
          // Логотип LIDLE
          Image.asset('assets/logo.png', height: 20),
          const Spacer(),
        ],
      ),
    );
  }

  // Строка поиска
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 31),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white, size: 28),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2831),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Поиск',
                      style: TextStyle(color: Color(0xFF6B7684), fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/settings.svg',
                    height: 24,
                    width: 24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Секция категорий
  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции (FIX: защита от переполнения вправо)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 31),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Предложения на LIDLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Смотреть все',
                  style: TextStyle(
                    color: Color(0xFF00A6FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Слайдер категорий
        SizedBox(
          height: 85,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryCard(
                'Недвижи-\nмость',
                Colors.blue.shade700,
                'assets/14.png',
              ),
              _buildCategoryCard(
                'Авто\nи мото',
                Colors.purple.shade700,
                'assets/15.png',
              ),
              _buildCategoryCard(
                'Работа',
                Colors.orange.shade700,
                'assets/16.png',
              ),
              _buildCategoryCard(
                'Подработка',
                Colors.teal.shade700,
                'assets/17.png',
              ),
              _buildCategoryCard(
                'Услуги',
                Colors.green.shade700,
                'assets/14.png',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Карточка категории
  Widget _buildCategoryCard(String title, Color color, String imagePath) {
    return Container(
      width: 115,
      margin: const EdgeInsets.only(right: 11),
      child: Stack(
        children: [
          // Изображение
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Image.asset(
              imagePath,
              width: 115,
              height: 83,
              fit: BoxFit.cover,
            ),
          ),
          // Текст вверху слева
          Positioned(
            top: 15,
            left: 10,
            child: Text(
              title,
              style: const TextStyle(
                color: Color.fromARGB(255, 0, 0, 0),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.0,
                shadows: [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Секция "Самое новое"
  Widget _buildLatestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 31),
          child: Text(
            'Самое новое',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Сетка объявлений (2 в ряд)
        LayoutBuilder(
          builder: (context, constraints) {
            // Ширина карточки с учётом паддингов и межколоночного отступа
            final itemWidth = (constraints.maxWidth - 31 - 31 - 16) / 2;

            // FIX: гарантируем достаточную высоту тайла
            double tileHeight = 263; // базовая высота
            if (itemWidth < 170) tileHeight = 275; // +12 px запаса под текст
            if (itemWidth < 140)
              tileHeight = 300; // ещё бол                тьше для очень узких экранов

            return GridView.custom(
              padding: const EdgeInsets.only(
                left: 31,
                right: 31,
                bottom: 60,
              ), // нижний отступ здесь
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: tileHeight, // FIX: фикс высоты каждой плитки
              ),
              childrenDelegate: SliverChildListDelegate.fixed([
                _buildListingCard(
                  'assets/apartment1.png',
                  '4-к. квартира, 169,5 м²...',
                  '78 970 000 ₽',
                  'Москва, ул. Кусинена, 21А',
                  'Сегодня',
                ),
                _buildListingCard(
                  'assets/acura_mdx.png',
                  'Acura MDX 3.5 AT, 20...',
                  '2 399 999 ₽',
                  'Брянск, Авиационная ул., 34',
                  '29.08.2024',
                ),
                _buildListingCard(
                  'assets/acura_rdx.png',
                  'Acura RDX 2.3 AT, 2007...',
                  '2 780 000 ₽',
                  'Москва, Отрадная ул., 11',
                  '29.08.2024',
                ),
                _buildListingCard(
                  'assets/studio.png',
                  'Студия, 35,7 м², 2/6 эт...',
                  '6 500 000 ₽',
                  'Москва, Варшавское ш., 125',
                  '11.05.2024',
                ),
                _buildListingCard(
                  'assets/acura_rdx.png',
                  'Acura RDX 2.3 AT, 2007...',
                  '2 780 000 ₽',
                  'Москва, Отрадная ул., 11',
                  '29.08.2024',
                ),
                _buildListingCard(
                  'assets/studio.png',
                  'Студия, 35,7 м², 2/6 эт...',
                  '6 500 000 ₽',
                  'Москва, Варшавское ш., 125',
                  '11.05.2024',
                ),
              ]),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            );
          },
        ),
      ],
    );
  }

  // Карточка объявления
  Widget _buildListingCard(
    String imagePath,
    String title,
    String price,
    String location,
    String date,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        final cardWidth = constraints.maxWidth;

        // FIX: немного уменьшаем долю высоты под изображение
        double imageProportion = cardWidth < 140 ? 0.50 : 0.58; // было 0.604
        final imageHeight = cardHeight * imageProportion;

        // Масштаб шрифтов относительно базовой высоты 263
        final scale = cardHeight / 263;
        final titleFontSize = 14 * scale;
        final priceFontSize = 16 * scale;
        final locationFontSize = 13 * scale;
        final dateFontSize = 12 * scale;
        final iconSize = 16 * scale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение
            SizedBox(
              width: double.infinity,
              height: imageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF374B5C),
                      child: Icon(
                        Icons.image,
                        color: const Color(0xFF6B7684),
                        size: 50 * scale,
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 8 * scale),

            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название и избранное
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1, // FIX: только одна строка
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4 * scale),
                      Icon(
                        Icons.favorite_border,
                        color: Colors.white,
                        size: iconSize,
                      ),
                    ],
                  ),

                  SizedBox(height: 3 * scale), // FIX: было 4
                  // Цена
                  Text(
                    price,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  SizedBox(height: 3 * scale), // FIX: было 4
                  // Адрес
                  Text(
                    location,
                    style: TextStyle(
                      color: const Color(0xFF9BA5B0),
                      fontSize: locationFontSize,
                    ),
                    maxLines: 1, // FIX: было 2
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 1 * scale),

                  // Дата
                  Text(
                    date,
                    style: TextStyle(
                      color: const Color(0xFF6B7684),
                      fontSize: dateFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  

  // Цвета (удобно держать в одном месте)
  static const _barColor = Color(0xFF0F1A23);
  static const _iconActive = Color(0xFF00A6FF);
  static const _iconInactive = Color(0xFFE5EDF5); // мягкий светлый
  static const _shadowColor = Colors.black26;

  Widget _buildBottomNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(31, 0, 31, 17), // отступы от краёв
        child: Container(
          height: 57,
          decoration: BoxDecoration(
            color: _barColor,
            borderRadius: BorderRadius.circular(37.5), // пилюля
            boxShadow: const [
              BoxShadow(
                color: _shadowColor,
                blurRadius: 18,
                spreadRadius: 2,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly, // как на скрине
            children: [
              _buildNavItem('assets/BottomNavigation/home-02.png', 0),
              _buildNavItem('assets/BottomNavigation/heart-rounded.png', 1),
              _buildCenterAdd(2), // “+” в кружке
              _buildNavItem('assets/BottomNavigation/message-circle-01.png', 3),
              _buildNavItem('assets/BottomNavigation/user-01.png', 4),
            ],
          ),
        ),
      ),
    );
  }

  // Обычные пункты
  Widget _buildNavItem(String iconPath, int index) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Image.asset(
            iconPath,
            width: 28,
            height: 28,
            color: isSelected ? _iconActive : _iconInactive,
          ),
        ),
      ),
    );
  }

  // Центральная кнопка “+” в обводке
  Widget _buildCenterAdd(int index) {
    final isSelected = _selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,

          child: Image.asset(
            'assets/BottomNavigation/plus-circle.png',
            width: 28,
            height: 28,
            color: isSelected ? _iconActive : _iconInactive,
          ),
        ),
      ),
    );
  }
}
