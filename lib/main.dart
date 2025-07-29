import 'package:flutter/material.dart';
import '/dashboards.dart';
import '/pages/login_page.dart';
import '/utils/auth_storage.dart';
import 'models/user_data.dart';
import 'services/app_config_service.dart'; 

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfigService.initialize();
  
  UserData? user = await AuthStorage.getUser();
  runApp(MyApp(initialUser: user));
}

class MyApp extends StatelessWidget {
  final UserData? initialUser;
  const MyApp({this.initialUser, Key? key}) : super(key: key);

  Widget _getInitialPage() {
    if (initialUser == null) {
      return LoginPage();
    } else {
      return DashboardPage(currentUser: initialUser!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'South Indian Farmers Society(SIFS)',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: _getInitialPage(),
    );
  }
}