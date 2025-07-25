import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'registration_page.dart';
import '../dashboards.dart'; // UPDATED: Import the single dashboard.dart file
import '../models/user_data.dart';
import '../services/api_service.dart';
import '../utils/auth_storage.dart';
import '/libraries/copyright_footer.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // All your existing state variables
  final _apiService = ApiService();
  final mobileController = TextEditingController();
  final otpController = TextEditingController();
  late FocusNode mobileFocusNode;
  late FocusNode otpFocusNode;
  bool _isLoading = false;
  bool otpSent = false;
  bool otpVerified = false;
  bool adminDetailsConfirmed = false;
  List<String> aadharList = [];
  String? selectedAadhar;
  String message = '';
  Timer? _timer;
  int _secondsRemaining = 0;
  UserData? _loggedInUser;

  @override
  void initState() {
    super.initState();
    mobileFocusNode = FocusNode();
    otpFocusNode = FocusNode();
    mobileFocusNode.addListener(() => setState(() {}));
    otpFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    mobileFocusNode.dispose();
    otpFocusNode.dispose();
    _timer?.cancel();
    mobileController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() => message = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && message == text) setState(() => message = '');
    });
  }

  Future<void> sendOtp() async {
    // This function's logic remains the same
    FocusScope.of(context).unfocus();
    if (mobileController.text.length != 10) {
      _showMessage('Please enter a valid 10-digit mobile number.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.sendOtp(mobileController.text);
      if (response.containsKey('error')) {
        _showMessage(response['error'], isError: true);
      } else {
        setState(() {
          otpSent = true;
          _secondsRemaining = 60;
        });
        _startTimer();
        _showMessage('OTP sent successfully');
      }
    } catch (e) {
      _showMessage("Failed to send OTP. Please check your connection.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> verifyOtp() async {
    // This function's logic remains the same
    FocusScope.of(context).unfocus();
    if (otpController.text.length < 6) {
      _showMessage('Please enter the 6-digit OTP.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.login(mobileController.text, otpController.text);

      if (response.containsKey('token')) {
        await AuthStorage.saveToken(response['token']);
        await AuthStorage.saveUser(response['user']);

        _loggedInUser = UserData.fromJson(response['user']);

        _timer?.cancel();
        setState(() => otpVerified = true);
        _showMessage('OTP Verified.');

        if (_loggedInUser!.roleId == 0) { // User role
          _fetchAadharForUser();
        } else { // Admin or Super Admin role
          _showAdminDetailsPopup(_loggedInUser!);
        }
      } else {
        _showMessage(response['error'] ?? 'Login failed.', isError: true);
      }
    } catch (e) {
      _showMessage("An error occurred during verification.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAadharForUser() async {
    // This function's logic remains the same
    setState(() { aadharList = []; });
    try {
      final numbers = await _apiService.getAadharNumbers(mobileController.text);
      if (!mounted) return;
      setState(() => aadharList = numbers);
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _showAdminDetailsPopup(UserData admin) {
    // This function's logic remains the same
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Your Identity'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Name: ${admin.name}'),
          Text('Role: ${admin.roleId == 1 ? "Admin" : "Super Admin"}'),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _resetToStartState(); }, child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            setState(() => adminDetailsConfirmed = true);
            Navigator.pop(context);
            submitAndNavigate(); // Navigate immediately on confirm
          }, child: const Text('Confirm and Continue')),
        ],
      ),
    );
  }

  // ### THIS IS THE KEY CHANGE ###
  // This function is now simplified to use the DashboardPage router.
  void submitAndNavigate() {
    if (_loggedInUser == null) return;
    
    // The switch statement is no longer needed here.
    // We navigate to the single DashboardPage and it handles showing the correct view.
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardPage(currentUser: _loggedInUser!)),
      (route) => false
    );
  }

  void _startTimer() {
    // This function's logic remains the same
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        if (mounted) setState(() {});
      } else if (mounted) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _resetToStartState() {
    // This function's logic remains the same
    setState(() {
      _isLoading = false; otpSent = false; otpVerified = false; adminDetailsConfirmed = false;
      aadharList.clear(); selectedAadhar = null; mobileController.clear();
      otpController.clear(); message = ''; _timer?.cancel(); _secondsRemaining = 0;
      _loggedInUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Your build method remains the same as it correctly calls _buildLoginStage()
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text("South Indian Farmers Society(SIFS)", style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 93, 215, 97),
        foregroundColor: const Color.fromARGB(255, 241, 243, 241),
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("LOGIN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      const SizedBox(height: 20),
                      Container(
                        width: 400,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.green.shade100, blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: Column(
                          children: [
                            Text("Welcome", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            const SizedBox(height: 20),
                            _buildLoginStage(),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(message, textAlign: TextAlign.center, style: TextStyle(color: message.contains('successfully') || message.contains('Verified') ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegistrationPage())),
                        child: const Text.rich(
                          TextSpan(text: "Don't have an account? ", style: TextStyle(color: Colors.black), children: [
                            TextSpan(text: "Register here", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          CopyrightFooter(color: Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _buildLoginStage() {
    // This function's logic remains the same
    if (otpVerified && _loggedInUser != null) {
      final bool isUserRole = _loggedInUser!.roleId == 0;
      final bool isSubmitEnabled = (isUserRole && selectedAadhar != null) || (!isUserRole && adminDetailsConfirmed);

      return Column(
        children: [
          if (isUserRole)
            _buildAadhaarSelection()
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                adminDetailsConfirmed ? 'Details Confirmed. Please wait...' : 'Awaiting confirmation...',
                style: TextStyle(fontSize: 16, color: Colors.green.shade800, fontWeight: FontWeight.w500)
              ),
            ),
          
          if (isUserRole) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSubmitEnabled ? submitAndNavigate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Submit"),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: mobileController,
            focusNode: mobileFocusNode,
            keyboardType: TextInputType.phone,
            enabled: !otpSent,
            inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: mobileFocusNode.hasFocus ? null : 'Mobile Number', border: InputBorder.none, icon: const Icon(Icons.phone, color: Colors.green)),
          ),
        ),
        const SizedBox(height: 16),
        if (otpSent) ...[
          Container(
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: otpController,
              focusNode: otpFocusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [LengthLimitingTextInputFormatter(6)],
              decoration: InputDecoration(hintText: otpFocusNode.hasFocus ? null : 'Enter OTP', border: InputBorder.none, icon: const Icon(Icons.lock, color: Colors.green)),
            ),
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: verifyOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("Verify OTP"),
                ),
          const SizedBox(height: 16),
          _secondsRemaining > 0
              ? Text('Resend OTP in $_secondsRemaining seconds', style: const TextStyle(color: Colors.grey))
              : TextButton(onPressed: _isLoading ? null : sendOtp, child: const Text("Resend OTP")),
        ] else ...[
          _isLoading
              ? const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))
              : ElevatedButton(
                  onPressed: sendOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text("Send OTP"),
                ),
        ]
      ],
    );
  }

  Widget _buildAadhaarSelection() {
    // This function's logic remains the same
    return Column(
      children: [
        const Text("Select Your Aadhaar Number", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (aadharList.isEmpty)
          const Text("No Aadhaar numbers found for this mobile.")
        else
          Wrap(
            spacing: 10,
            alignment: WrapAlignment.center,
            children: aadharList.map((aadhar) {
              final isSelected = selectedAadhar == aadhar;
              return ElevatedButton(
                onPressed: () => setState(() => selectedAadhar = aadhar),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.green : Colors.green.shade100,
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                child: Text(aadhar),
              );
            }).toList(),
          ),
      ],
    );
  }
}