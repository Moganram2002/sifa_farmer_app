// lib/pages/registration_page.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../libraries/copyright_footer.dart';
import '../libraries/registration_form_widget.dart'; // Import your new library

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  // The ApiService can be initialized here or passed via a dependency injector
  final _apiService = ApiService();

  // This is the logic that will run when the form is successfully submitted.
  Future<void> _registerUser(RegistrationPayload payload) async {
    try {
      final response = await _apiService.register(
        payload.userData,
        payload.profilePhotoBytes,
        payload.idDocument,
      );

      if (!mounted) return;

      if (response.containsKey('id')) {
        _showMessage('Registration successful! Please log in.');
        Navigator.of(context).pop();
      } else {
        _showMessage(response['error'] ?? 'Registration failed.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('An error occurred: $e', isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('South India Farmers Society(SIFS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 93, 213, 97),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // You can keep the language switcher here if you want it in the AppBar
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Container(
                  width: MediaQuery.of(context).size.width > 800 ? 700 : MediaQuery.of(context).size.width * 0.9,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.grey.shade400, blurRadius: 12, spreadRadius: 1, offset: Offset(0, 0))],
                  ),
                  // Using the library widget
                  child: RegistrationForm(
                    apiService: _apiService,
                    onFormSubmit: _registerUser,
                    submitButtonText: 'Register Now',
                    isOtpFieldVisible: true, // Show OTP for public registration
                  ),
                ),
              ),
            ),
          ),
          CopyrightFooter(),
        ],
      ),
    );
  }
}