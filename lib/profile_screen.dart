import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Создаем класс для работы с авторизацией
class AuthService {
  static Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return false;

    try {
      // Пробуем сделать запрос к профилю для проверки токена
      final response = await http.get(
        Uri.parse('https://example.com/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Метод для повторной авторизации
  static Future<bool> reAuthenticate(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final login = prefs.getString('login');
    final password = prefs.getString('password');

    if (login == null || password == null) {
      await logout(context);
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('https://example.com/auth'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login': login,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('token', data['token']);
        return true;
      }
    } catch (e) {
      print('Ошибка реаутентификации: $e');
    }

    await logout(context);
    return false;
  }
}


class ProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final bool hasSubscription;
  final int remainingRequests;

  ProfileScreen({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.hasSubscription,
    required this.remainingRequests,
  });

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? firstName;
  String? lastName;
  String? email;
  bool? hasSubscription;
  int? remainingRequests;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeProfileData();
  }

  Future<void> _initializeProfileData() async {
    await _checkAuthAndLoadProfile();
  }

  Future<void> _checkAuthAndLoadProfile() async {
    if (!mounted) return;

    final isValid = await AuthService.isTokenValid();
    if (!isValid) {
      // Пробуем переавторизоваться
      final reAuthSuccessful = await AuthService.reAuthenticate(context);
      if (!reAuthSuccessful) return; // Редирект на логин произойдет в reAuthenticate
    }

    await _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://example.com/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          if (!mounted) return;

          setState(() {
            firstName = data['user']['first_name'];
            lastName = data['user']['last_name'];
            email = data['user']['email'];
            hasSubscription = data['user']['has_subscription'];
            remainingRequests = data['user']['remaining_requests'];
            isLoading = false;
          });

          // Обновляем данные в SharedPreferences
          await prefs.setString('firstName', firstName ?? '');
          await prefs.setString('lastName', lastName ?? '');
          await prefs.setString('email', email ?? '');
          await prefs.setBool('hasSubscription', hasSubscription ?? false);
          await prefs.setInt('remainingRequests', remainingRequests ?? 0);
        }
      } else if (response.statusCode == 401) {
        // Если токен невалиден, пробуем переавторизоваться
        final reAuthSuccessful = await AuthService.reAuthenticate(context);
        if (reAuthSuccessful) {
          // Если переавторизация успешна, пробуем загрузить данные снова
          await _loadProfileData();
        }
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshProfileData() async {
    setState(() {
      isLoading = true;
    });
    await _checkAuthAndLoadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Color(0xFF1F1F1F),
        title: Text('Профиль', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: Color(0xFF1F1F1F),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    SizedBox(width: 16),
                    Text(
                      '${firstName ?? "Имя"} ${lastName ?? "Фамилия"}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Color(0xFF1F1F1F),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Colors.white, size: 30),
                    SizedBox(width: 16),
                    Text(
                      email ?? "example@example.com",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Color(0xFF1F1F1F),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      hasSubscription == true ? Icons.check_circle : Icons.cancel,
                      color: hasSubscription == true ? Colors.green : Colors.red,
                      size: 30,
                    ),
                    SizedBox(width: 16),
                    Text(
                      hasSubscription == true ? 'Активная подписка' : 'Нет подписки',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: Color(0xFF1F1F1F),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.query_stats, color: Colors.white, size: 30),
                    SizedBox(width: 16),
                    Text(
                      'Оставшиеся запросы: ${remainingRequests ?? 0}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () => AuthService.logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Выйти',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

