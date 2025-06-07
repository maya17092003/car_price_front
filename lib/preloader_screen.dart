import 'package:flutter/material.dart';

class PreloaderScreen extends StatefulWidget {
  @override
  _PreloaderScreenState createState() => _PreloaderScreenState();
}

class _PreloaderScreenState extends State<PreloaderScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    // Имитируем задержку загрузки (например, запрос к API)
    // await Future.delayed(const Duration(seconds: 3));

    // Логика проверки (замени на свою)
    bool isAuthenticated = false; // Заменить на реальную проверку

    if (!isAuthenticated) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Темный фон
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип или иконка
            Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 100,
            ),
            SizedBox(height: 20),
            // Текст "Загрузка..."
            Text(
              'Загрузка...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            // Вращающийся индикатор
            CircularProgressIndicator(
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }
}
