import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _username;
  String? _userId;
  String? _email;
  String? _avatar;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get username => _username;
  String? get userId => _userId;
  String? get email => _email;
  String? get avatar => _avatar;

  final String baseUrl = "http://localhost:5000/api/auth";

  AuthProvider() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _username = prefs.getString('username');
    _userId = prefs.getString('userId');
    _email = prefs.getString('email');
    _avatar = prefs.getString('avatar');
    notifyListeners();
  }

  Future<void> _persistUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString('token', _token!);
    if (_username != null) await prefs.setString('username', _username!);
    if (_userId != null) await prefs.setString('userId', _userId!);
    if (_email != null) await prefs.setString('email', _email!);
    if (_avatar != null) await prefs.setString('avatar', _avatar!);
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['token'];
        _username = data['user']['username'];
        _userId = data['user']['id'];
        _email = data['user']['email'];
        _avatar = data['user']['avatar'];
        await _persistUser();
        return true;
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
        }),
      );

      _isLoading = false;
      notifyListeners();

      return res.statusCode == 201;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "newPassword": newPassword,
        }),
      );

      _isLoading = false;
      notifyListeners();

      return res.statusCode == 200;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({
    required String username,
    String? avatar,
  }) async {
    _username = username;
    if (avatar != null) {
      _avatar = avatar;
    }
    await _persistUser();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _username = null;
    _userId = null;
    _email = null;
    _avatar = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
