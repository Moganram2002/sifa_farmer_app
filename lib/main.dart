import 'package:flutter/material.dart';
import '/dashboards.dart'; // UPDATED: Changed from 'dashboards.dart' to your single file
import '/pages/login_page.dart';
import '/utils/auth_storage.dart';
import 'models/user_data.dart';

void main() async {
  // This ensures that widget binding is initialized before async calls
  WidgetsFlutterBinding.ensureInitialized();
  // Check if a user session is already stored
  UserData? user = await AuthStorage.getUser();
  runApp(MyApp(initialUser: user));
}

class MyApp extends StatelessWidget {
  final UserData? initialUser;
  const MyApp({this.initialUser, Key? key}) : super(key: key);

  // This method now correctly determines the initial page
  Widget _getInitialPage() {
    // If no user is logged in, show the LoginPage
    if (initialUser == null) {
      return LoginPage();
    } else {
      // If a user is logged in, show the DashboardPage.
      // The DashboardPage itself will handle showing the correct view based on the user's role.
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
      // The home property is now set to the result of our updated logic
      home: _getInitialPage(),
    );
  }
}