import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lidle/blocs/navigation/navigation_bloc.dart'; // Import NavigationBloc
import 'package:lidle/blocs/navigation/navigation_event.dart'; // Import NavigationEvent
import 'package:lidle/blocs/navigation/navigation_state.dart'; // Import NavigationState
import 'package:lidle/widgets/navigation/bottom_navigation.dart'; // Import custom BottomNavigation
import 'package:lidle/constants.dart'; // Import constants
import 'package:lidle/widgets/components/header.dart'; // Import Header widget

class MyPurchasesScreen extends StatelessWidget {
  static const String routeName = '/my-purchases'; // Define route name
  const MyPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<NavigationBloc, NavigationState>(
      listener: (context, state) {
        if (state is NavigationToProfile || state is NavigationToHome || state is NavigationToFavorites || state is NavigationToMessages) {
          context.read<NavigationBloc>().executeNavigation(context);
        }
      },
      child: Scaffold(
      backgroundColor: primaryBackground,
      body: SafeArea(
        child: Column( // Removed SingleChildScrollView
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(), // Add the Header widget
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 25,
                vertical: 19,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: textPrimary, size: 16,),
                  ),
                  // const SizedBox(width: 10), // Added spacing
                  const Text(
                    'Мои покупки', // Title from the mockup
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.import_export, color: textPrimary), // Sort icon
                    onPressed: () {
                      // TODO: Implement sort functionality
                    },
                  ),
                ],
              ),
            ),
            Expanded( // Wrap Center with Expanded for vertical centering
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/my_purchases/shopping-bag-01.svg',
                      height: 120, // Adjusted size as per feedback
                      width: 120, // Adjusted size as per feedback
                      colorFilter: const ColorFilter.mode(Color(0xFFFEDC02), BlendMode.srcIn), // Yellow color
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Нет покупок',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600, // Changed to w600 for consistency
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        'У вас нет покупок, как только вы\n купите товар здесь он будет\n отображен',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFAAAAAA), // Lighter grey for description
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        onItemSelected: (index) {
          context.read<NavigationBloc>().add(SelectNavigationIndexEvent(index));
        },
      ),
      ),
    );
  }
}
