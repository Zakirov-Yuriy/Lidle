// ============================================================
// "Mock данные: Статические объявления для тестирования"
// ============================================================
//
// Хранит статические данные объявлений для разработки и тестирования.
// В производстве эти данные загружаются из API.

import 'package:lidle/models/home_models.dart' as home;

/// Статические данные объявлений.
/// В будущем можно заменить на загрузку из API.
final List<home.Listing> mockListings = [
  home.Listing(
    id: 'listing_1',
    imagePath: 'assets/home_page/apartment1.png',
    images: ['assets/home_page/apartment1.png', 'assets/home_page/image.png'],
    title: '4-к. квартира, 169,5 м²...',
    price: '78 970 000 ₽',
    location: 'Москва, ул. Кусинена, 21А',
    date: 'Сегодня',
    isFavorited: false,
    isBargain: false,
  ),
  home.Listing(
    id: 'listing_2',
    imagePath: 'assets/home_page/acura_mdx.png',
    images: ['assets/home_page/acura_mdx.png'],
    title: 'Acura MDX 3.5 AT, 20...',
    price: '2 399 999 ₽',
    location: 'Брянск, Авиационная ул., 34',
    date: '29.08.2024',
    isFavorited: false,
    isBargain: false,
  ),
  home.Listing(
    id: 'listing_3',
    imagePath: 'assets/home_page/acura_rdx.png',
    images: ['assets/home_page/acura_rdx.png'],
    title: 'Acura RDX 2.3 AT, 2007...',
    price: '2 780 000 ₽',
    location: 'Москва, Отрадная ул., 11',
    date: '29.08.2024',
    isFavorited: false,
    isBargain: false,
  ),
  home.Listing(
    id: 'listing_4',
    imagePath: 'assets/home_page/studio.png',
    images: ['assets/home_page/studio.png', 'assets/home_page/image2.png'],
    title: 'Студия, 35,7 м², 2/6 эт...',
    price: '6 500 000 ₽',
    location: 'Москва, Варшавское ш., 125',
    date: '11.05.2024',
    isFavorited: false,
    isBargain: true,
  ),
  home.Listing(
    id: 'listing_5',
    imagePath: 'assets/home_page/image.png',
    images: ['assets/home_page/image.png'],
    title: 'Студия, 35,7 м², 2/6 эт...',
    price: '6 500 000 ₽',
    location: 'Москва, Варшавское ш., 125',
    date: '11.05.2024',
    isFavorited: false,
    isBargain: false,
  ),
  home.Listing(
    id: 'listing_6',
    imagePath: 'assets/home_page/image2.png',
    images: [
      'assets/home_page/image2.png',
      'assets/home_page/apartment1.png',
    ],
    title: '3-к. квартира, 125,5 м²...',
    price: '44 500 000 ₽ ',
    location: 'Москва, Истринская ул., 8к3',
    date: '09.08.2024',
    isFavorited: false,
    isBargain: true,
  ),
];
