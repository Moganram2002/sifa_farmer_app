import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'registration_page.dart';
import '../dashboards.dart';
import '../models/user_data.dart';
import '../services/api_service.dart';
import '../utils/auth_storage.dart';
import '/libraries/copyright_footer.dart';
import '../services/app_config_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
  UserData? _loggedInUser;

  bool? _isMobileValid;
  bool? _isOtpValid;

  final ValueNotifier<int> _secondsRemaining = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    mobileFocusNode = FocusNode();
    otpFocusNode = FocusNode();
    mobileFocusNode.addListener(_validateMobileOnFocus);
    otpFocusNode.addListener(_validateOtpOnFocus);
  }

  @override
  void dispose() {
    mobileFocusNode.removeListener(_validateMobileOnFocus);
    otpFocusNode.removeListener(_validateOtpOnFocus);
    mobileFocusNode.dispose();
    otpFocusNode.dispose();
    _timer?.cancel();
    mobileController.dispose();
    otpController.dispose();
    _secondsRemaining.dispose();
    super.dispose();
  }
  
  void _validateMobileOnFocus() {
    if (!mobileFocusNode.hasFocus) {
      setState(() {
        if (mobileController.text.isNotEmpty) {
          _isMobileValid = mobileController.text.length == 10;
        } else {
          _isMobileValid = null;
        }
      });
    }
  }

  void _validateOtpOnFocus() {
    if (!otpFocusNode.hasFocus) {
      setState(() {
        if (otpController.text.isNotEmpty) {
          _isOtpValid = otpController.text.length == 6;
        } else {
          _isOtpValid = null;
        }
      });
    }
  }

  Color _getBorderColor(bool? isValid) {
    if (isValid == null) {
      return Colors.grey.shade300; 
    } else if (isValid) {
      return Colors.green; 
    } else {
      return Colors.grey.shade600; 
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    setState(() => message = text);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && message == text) setState(() => message = '');
    });
  }

  Future<void> sendOtp() async {
    FocusScope.of(context).unfocus();
    setState(() => _isMobileValid = mobileController.text.length == 10);
    if (_isMobileValid != true) {
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
    FocusScope.of(context).unfocus();
    setState(() => _isOtpValid = otpController.text.length == 6);
    if (_isOtpValid != true) {
      _showMessage('Please enter the 6-digit OTP.', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.login(mobileController.text, otpController.text);

      if (response.containsKey('token')) {
        await Future.wait([
          AuthStorage.saveToken(response['token']),
          AuthStorage.saveUser(response['user'])
        ]);

        _loggedInUser = UserData.fromJson(response['user']);

        _timer?.cancel();
        _showMessage('OTP Verified.');

        if (_loggedInUser!.roleId == 0) {
          await _fetchAadharForUser();
        } else {
          setState(() => otpVerified = true);
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
    try {
      final numbers = await _apiService.getAadharNumbers(mobileController.text);
      if (!mounted) return;

      if (numbers != null && numbers.length == 1) {
        setState(() {
          selectedAadhar = numbers.first;
        });
        submitAndNavigate();
      } else {
        setState(() {
          aadharList = numbers ?? [];
          otpVerified = true; 
        });
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
      setState(() {
        aadharList = [];
        otpVerified = true; 
      });
    }
  }

  
  void _showAdminDetailsPopup(UserData admin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: Colors.green.shade300, width: 2),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.green.shade800),
            const SizedBox(width: 10),
            Text(
              'Admin Confirmation',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Name: ',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  children: [
                    TextSpan(
                      text: admin.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Role: ',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                  children: [
                    TextSpan(
                      text: admin.roleId == 1 ? "Admin" : "Super Admin",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetToStartState();
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => adminDetailsConfirmed = true);
              Navigator.pop(context);
              submitAndNavigate();
            },
            child: const Text('Confirm & Continue'),
          ),
        ],
      ),
    );
  }

  void submitAndNavigate() {
    if (_loggedInUser == null) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardPage(currentUser: _loggedInUser!)),
      (route) => false
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining.value = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining.value <= 0) {
        timer.cancel();
      } else {
        _secondsRemaining.value--;
      }
    });
  }

  void _resetToStartState() {
    setState(() {
      _isLoading = false; otpSent = false; otpVerified = false; adminDetailsConfirmed = false;
      aadharList.clear(); selectedAadhar = null; mobileController.clear();
      otpController.clear(); message = ''; _timer?.cancel(); _secondsRemaining.value = 0;
      _loggedInUser = null;
      _isMobileValid = null;
      _isOtpValid = null;
    });
  }

 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        
        title: ValueListenableBuilder<String>(
          valueListenable: AppConfigService.appTitleNotifier,
          builder: (context, title, child) {
            return Text(title, style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
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
                              Text(message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: message.contains('successfully') || message.contains('Verified')
                                          ? Colors.green.shade700
                                          : Colors.grey.shade800,
                                      fontWeight: FontWeight.bold)),
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
          const CopyrightFooter(),
        ],
      ),
    );
  }

  Widget _buildLoginStage() {
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
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getBorderColor(_isMobileValid), width: 1.5),
          ),
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
            decoration: BoxDecoration(
              color: Colors.green.shade50, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getBorderColor(_isOtpValid), width: 1.5),
            ),
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
          ValueListenableBuilder<int>(
            valueListenable: _secondsRemaining,
            builder: (context, seconds, child) {
              return seconds > 0
                  ? Text('Resend OTP in $seconds seconds', style: const TextStyle(color: Colors.grey))
                  : TextButton(onPressed: _isLoading ? null : sendOtp, child: const Text("Resend OTP"));
            },
          ),
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