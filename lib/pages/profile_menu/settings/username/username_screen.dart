import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lidle/widgets/components/header.dart';
import 'package:lidle/blocs/profile/profile_bloc.dart';
import 'package:lidle/blocs/profile/profile_state.dart';
import 'package:lidle/blocs/profile/profile_event.dart';

class UsernameScreen extends StatefulWidget {
  static const routeName = '/username';

  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  static const bgColor = Color(0xFF243241);
  static const fieldColor = Color(0xFF1F2C3A);
  static const accentColor = Color(0xFF00B7FF);

  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Загружаем профиль для получения текущего username
    context.read<ProfileBloc>().add(LoadProfileEvent());
  }

  void _confirmUsername() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      final currentState = context.read<ProfileBloc>().state;
      if (currentState is ProfileLoaded) {
        context.read<ProfileBloc>().add(UpdateProfileEvent(
          name: currentState.name,
          email: currentState.email,
          phone: currentState.phone,
          profileImage: currentState.profileImage,
          username: username,
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───── Header ─────
            Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 23),
              child: Row(
                children: const [Header()],
              ),
            ),

            // ───── Back row ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Имя пользователя',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ───── Description ─────
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 25),
              child: Text(
                'Вы можете выбрать публичное имя пользователя. '
                'В этом случае другие люди смогут найти вас не зная вашего номера телефона.',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
            ),

            const SizedBox(height: 5),

            // ───── Input ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: BlocBuilder<ProfileBloc, ProfileState>(
                builder: (context, state) {
                  if (state is ProfileLoaded && _usernameController.text.isEmpty) {
                    _usernameController.text = state.username;
                  }
                  return Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: fieldColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '@Name',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // ───── Confirm button ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SizedBox(
                width: double.infinity,
                height: 47,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: _confirmUsername,
                  child: const Text(
                    'Подтвердить',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
