import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/home_models.dart';
import '../widgets/header.dart';
import '../widgets/search_bar.dart' as custom_widgets;
import '../widgets/category_card.dart';
import '../widgets/listing_card.dart';
import '../widgets/bottom_navigation.dart';
import 'signIn_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  void _onItemSelected(int index) {
    if (index == 4) {
      Navigator.of(context).pushNamed(SignInScreen.routeName);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  // Sample data - in a real app, this would come from a repository or API
  final List<Category> _categories = [
    const Category(
      title: 'Недвижи-\nмость',
      color: Colors.blue,
      imagePath: 'assets/14.png',
    ),
    const Category(
      title: 'Авто\nи мото',
      color: Colors.purple,
      imagePath: 'assets/15.png',
    ),
    const Category(
      title: 'Работа',
      color: Colors.orange,
      imagePath: 'assets/16.png',
    ),
    const Category(
      title: 'Подработка',
      color: Colors.teal,
      imagePath: 'assets/17.png',
    ),
    const Category(
      title: 'Услуги',
      color: Colors.green,
      imagePath: 'assets/14.png',
    ),
  ];

  final List<Listing> _listings = [
    const Listing(
      imagePath: 'assets/apartment1.png',
      title: '4-к. квартира, 169,5 м²...',
      price: '78 970 000 ₽',
      location: 'Москва, ул. Кусинена, 21А',
      date: 'Сегодня',
    ),
    const Listing(
      imagePath: 'assets/acura_mdx.png',
      title: 'Acura MDX 3.5 AT, 20...',
      price: '2 399 999 ₽',
      location: 'Брянск, Авиационная ул., 34',
      date: '29.08.2024',
    ),
    const Listing(
      imagePath: 'assets/acura_rdx.png',
      title: 'Acura RDX 2.3 AT, 2007...',
      price: '2 780 000 ₽',
      location: 'Москва, Отрадная ул., 11',
      date: '29.08.2024',
    ),
    const Listing(
      imagePath: 'assets/studio.png',
      title: 'Студия, 35,7 м², 2/6 эт...',
      price: '6 500 000 ₽',
      location: 'Москва, Варшавское ш., 125',
      date: '11.05.2024',
    ),
    const Listing(
      imagePath: 'assets/acura_rdx.png',
      title: 'Acura RDX 2.3 AT, 2007...',
      price: '2 780 000 ₽',
      location: 'Москва, Отрадная ул., 11',
      date: '29.08.2024',
    ),
    const Listing(
      imagePath: 'assets/studio.png',
      title: 'Студия, 35,7 м², 2/6 эт...',
      price: '6 500 000 ₽',
      location: 'Москва, Варшавское ш., 125',
      date: '11.05.2024',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: primaryBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 41.0),
              child: const Header(),
            ),
            const custom_widgets.SearchBarWidget(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildCategoriesSection(),
                    const SizedBox(height: 25),
                    _buildLatestSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  categoriesTitle,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  viewAll,
                  style: TextStyle(
                    color: activeIconColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return CategoryCard(category: _categories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLatestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Text(
            latestTitle,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - defaultPadding - defaultPadding - listingCardSpacing) / 2;
            double tileHeight = 263;
            if (itemWidth < 170) tileHeight = 275;
            if (itemWidth < 140) tileHeight = 300;

            return GridView.builder(
              padding: const EdgeInsets.only(
                left: defaultPadding,
                right: defaultPadding,
                bottom: 60,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: listingCardSpacing,
                mainAxisSpacing: listingCardSpacing,
                mainAxisExtent: tileHeight,
              ),
              itemCount: _listings.length,
              itemBuilder: (context, index) {
                return ListingCard(listing: _listings[index]);
              },
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            );
          },
        ),
      ],
    );
  }
}
