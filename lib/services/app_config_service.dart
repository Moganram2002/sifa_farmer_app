import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart'; 

class AppConfigService {
  
  static final ValueNotifier<String> appTitleNotifier = ValueNotifier(_defaultTitle);
  static final ValueNotifier<String> copyrightNotifier = ValueNotifier(_defaultCopyright);

 
  static const String _titleKey = 'app_title';
  static const String _copyrightKey = 'copyright_text';

  
  static const String _defaultTitle = "South Indian Farmers Society (SIFS)";
  static const String _defaultCopyright = "© CShiine Tech 2025";

  
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    
    appTitleNotifier.value = prefs.getString(_titleKey) ?? _defaultTitle;
    copyrightNotifier.value = prefs.getString(_copyrightKey) ?? _defaultCopyright;

    try {
      final apiService = ApiService(); 
      final serverSettings = await apiService.getSettings();

      if (serverSettings['app_title'] != null) {
        final serverTitle = serverSettings['app_title'];
        await prefs.setString(_titleKey, serverTitle);
        appTitleNotifier.value = serverTitle;
      }
      if (serverSettings['copyright_text'] != null) {
        final serverCopyright = serverSettings['copyright_text'];
        await prefs.setString(_copyrightKey, serverCopyright);
        copyrightNotifier.value = serverCopyright;
      }
    } catch (e) {
     
      print("Could not fetch server settings: $e");
    }
  }


  static Future<void> setAppTitle(String newTitle) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_titleKey, newTitle);
    appTitleNotifier.value = newTitle;
  }

  static Future<void> setCopyrightText(String newText) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_copyrightKey, newText);
    copyrightNotifier.value = newText;
  }
}