import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_data.dart';

class AuthStorage {
  static const _tokenKey = 'jwt_token';
  static const _userKey = 'user_data';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(userData));
  }

  static Future<UserData?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userKey);
    if (userDataString == null) return null;
    return UserData.fromJson(jsonDecode(userDataString));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}