// lib/widgets/registration_form_library.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import '../services/api_service.dart'; // Ensure this path is correct
import '../profile_picture_picker.dart'; // Ensure this path is correct

// A helper class to pass all form data back to the parent page
class RegistrationPayload {
  final Map<String, String?> userData;
  final Uint8List? profilePhotoBytes;
  final XFile? idDocument;

  RegistrationPayload({
    required this.userData,
    this.profilePhotoBytes,
    this.idDocument,
  });
}

// Your existing TranslatorHelper
class TranslatorHelper {
  static final translator = GoogleTranslator();
  static Future<String> translateText(String text, String toLangCode) async {
    try {
      final translation = await translator.translate(text, to: toLangCode);
      return translation.text;
    } catch (e) {
      return text;
    }
  }
}



// The reusable library widget
class RegistrationForm extends StatefulWidget {
  final ApiService apiService;
  // Callback to run when the form is submitted successfully
  final Future<void> Function(RegistrationPayload payload) onFormSubmit;
  // Parameters to customize the form
  final String submitButtonText;
  final bool isOtpFieldVisible;
  final bool isLanguageSwitcherVisible;
  final String formTitle;
  final bool isCreatedByAdmin;

  const RegistrationForm({
    Key? key,
    required this.apiService,
    required this.onFormSubmit,
    this.submitButtonText = 'Create User',
    this.isOtpFieldVisible = true,
    this.isLanguageSwitcherVisible = true,
    this.formTitle = 'Registration Form',
    this.isCreatedByAdmin = false,
  }) : super(key: key);

  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  // ALL of your original state variables and methods are moved here, unchanged.
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Map<String, String> _translations = {};
  bool _isTranslating = false;
  final Map<String, String> _defaultTexts = {
    'formTitle': 'Registration Form', 'fullName': 'Full Name', 'mobile': 'Mobile Number', 'otp': 'OTP', 'aadhar': 'Aadhar Number', 'emergency': 'Emergency Contact',
    'location': 'Location', 'bloodGroup': 'Select Blood Group', 'uploadPhoto': 'Profile Photo', 'changePhoto': 'Change Photo', 'uploadID': 'ID Card', 
    'changeID': 'Change ID Document', 'createUser': 'Create User', 'gender': 'Gender', 'maritalStatus': 'Marital Status', 'religion': 'Religion', 
    'occupation': 'Select Occupation', 'enterSkill': 'Enter Skill', 'enteredSkill': 'Entered Skill', 'male': 'Male', 'female': 'Female', 'married': 'Married', 
    'single': 'Single', 'widow': 'Widow', 'separated': 'Separated', 'hindu': 'Hindu', 'christianity': 'Christianity', 'islam': 'Islam', 'other': 'Other', 
    'business': 'Business', 'agriculture': 'Agriculture', 'agriLabour': 'Agri Labour', 'skillLabour': 'Skill Labour', 'enterName': 'Enter Name', 
    'nameMinLength': 'Name must be more than 5 letters', 'nameOnlyAlphabets': 'Only alphabets and spaces allowed', 'enterMobile': 'Enter your mobile number',
    'mobileLength': 'Mobile number must be 10 digits', 'enterOTP': 'Enter OTP', 'enterAadhar': 'Enter your Aadhar number', 'aadharLength': 'Aadhar number must be 12 digits',
    'enterEmergency': 'Enter emergency contact', 'emergencyLength': 'Emergency contact must be 10 digits', 'enterLocation': 'Please enter location',
    'selectBloodGroup': 'Please select blood group', 'formSubmitted': 'Form submitted successfully!', 'ok': 'OK', 'uploadIdBtn': 'Generate ID',
  };

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _aadharController = TextEditingController();
  final _locationController = TextEditingController(text: "salem");
  final _emergencyContactController = TextEditingController();
  final _skillController = TextEditingController();

  final _nameFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _aadharFocus = FocusNode();
  final _locationFocus = FocusNode();
  final _emergencyContactFocus = FocusNode();

  bool _nameTouched = false;
  bool _mobileTouched = false;
  bool _otpTouched = false;
  bool _aadharTouched = false;
  bool _locationTouched = false;
  bool _emergencyTouched = false;

  Uint8List? _finalProfileImageBytes;
  XFile? _idDocument;

  String? _gender = 'Male';
  String? _maritalStatus = 'Married';
  String? _religion = 'Hindu';
  String? _occupation;
  String? _skill;
  String? _bloodGroup;
  String _selectedLanguage = 'en';

  bool _otpSent = false;
  Timer? _timer;
  int _secondsRemaining = 0;
  
  // UNCHANGED CODE from your original page
  @override
  void initState() {
    super.initState();
    _addFocusListeners();
    _translateAll();
  }

  @override
  void dispose() {
    _nameController.dispose(); _mobileController.dispose(); _otpController.dispose();
    _aadharController.dispose(); _locationController.dispose(); _emergencyContactController.dispose();
    _skillController.dispose(); _nameFocus.dispose(); _mobileFocus.dispose();
    _otpFocus.dispose(); _aadharFocus.dispose(); _locationFocus.dispose();
    _emergencyContactFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _translateAll() async {
    if (_isTranslating) return;
    setState(() => _isTranslating = true);
    final translated = <String, String>{};
    for (final entry in _defaultTexts.entries) {
      if (_selectedLanguage == 'en') {
        translated[entry.key] = entry.value;
      } else {
        translated[entry.key] = await TranslatorHelper.translateText(entry.value, _selectedLanguage);
      }
    }
    if (mounted) setState(() { _translations = translated; _isTranslating = false; });
  }

  String _t(String key) {
    if (key == 'formTitle') return widget.formTitle;
    if (key == 'createUser') return widget.submitButtonText;
    return _translations[key] ?? _defaultTexts[key] ?? key;
  }
  
  void _addFocusListeners() {
    _nameFocus.addListener(() => setState(() { if (!_nameFocus.hasFocus) _nameTouched = true; }));
    _mobileFocus.addListener(() => setState(() { if (!_mobileFocus.hasFocus) _mobileTouched = true; }));
    _otpFocus.addListener(() => setState(() { if (!_otpFocus.hasFocus) _otpTouched = true; }));
    _aadharFocus.addListener(() => setState(() { if (!_aadharFocus.hasFocus) _aadharTouched = true; }));
    _locationFocus.addListener(() => setState(() { if (!_locationFocus.hasFocus) _locationTouched = true; }));
    _emergencyContactFocus.addListener(() => setState(() { if (!_emergencyContactFocus.hasFocus) _emergencyTouched = true; }));
  }

  Future<void> _pickIdDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _idDocument = picked);
  }
  
  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }
  
  Future<void> _sendOtp() async {
    if (_mobileController.text.length != 10) {
      _showMessage('Please enter a valid 10-digit mobile number.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await widget.apiService.sendRegistrationOtp(_mobileController.text);
      if (response.containsKey('error')) {
        _showMessage(response['error'], isError: true);
      } else {
        setState(() { _otpSent = true; _secondsRemaining = 60; });
        _startTimer();
        _showMessage('OTP sent successfully');
      }
    } catch (e) {
      _showMessage("Failed to send OTP.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
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

  // ### KEY CHANGE ###
  // This method now calls the parent's callback instead of handling the API logic itself.
  Future<void> _handleFormSubmission() async {
    setState(() {
      _nameTouched = true; _mobileTouched = true; _otpTouched = true;
      _aadharTouched = true; _locationTouched = true; _emergencyTouched = true;
    });

    if (_formKey.currentState?.validate() ?? false) {
      if (_finalProfileImageBytes == null) {
        _showMessage('Please upload a profile photo.', isError: true);
        return;
      }

      setState(() => _isLoading = true);
      
      final payload = RegistrationPayload(
        userData: {
          "name": _nameController.text, "mobile": _mobileController.text, "aadhar_number": _aadharController.text,
          "emergency_contact": _emergencyContactController.text, "location": _locationController.text, "blood_group": _bloodGroup,
          "gender": _gender, "marital_status": _maritalStatus, "religion": _religion, "occupation": _occupation, "skill": _skill,
          "otp": _otpController.text,
        },
        profilePhotoBytes: _finalProfileImageBytes,
        idDocument: _idDocument,
      );
      
      // Execute the callback passed from the parent widget
      await widget.onFormSubmit(payload);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      _showMessage('Please correct the errors in the form.', isError: true);
    }
  }

  // Your entire build method, unchanged.
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_t('formTitle'), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 93, 213, 97))),
          SizedBox(height: 20),
          _buildTextFields(),
          _buildRadioGroups(),
          _buildDropdownAndUploads(),
          SizedBox(height: 30),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _handleFormSubmission,
                  child: Text(_t('createUser'), style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 93, 213, 97),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }

  // ALL your helper build methods, unchanged.
  Widget _buildTextFields() {
    return Column(
      children: [
        _buildBoxedTextField(controller: _nameController, focusNode: _nameFocus, hint: _t('fullName'), touched: _nameTouched, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterName'); if (value.length < 5) return _t('nameMinLength'); return null; },
        ),
        SizedBox(height: 15),
        _buildMobileFieldWithButton(),
        // Conditionally show the OTP field
        if (widget.isOtpFieldVisible) ...[
          SizedBox(height: 15),
          _buildBoxedTextField(controller: _otpController, focusNode: _otpFocus, hint: _t('otp'), touched: _otpTouched, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            validator: (value) => value!.isEmpty ? _t('enterOTP') : null,
          ),
        ],
        SizedBox(height: 15),
        _buildBoxedTextField(controller: _aadharController, focusNode: _aadharFocus, hint: _t('aadhar'), touched: _aadharTouched, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterAadhar'); if (value.length != 12) return _t('aadharLength'); return null; },
        ),
        SizedBox(height: 15),
        _buildBoxedTextField(controller: _emergencyContactController, focusNode: _emergencyContactFocus, hint: _t('emergency'), touched: _emergencyTouched, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterEmergency'); if (value.length != 10) return _t('emergencyLength'); return null; },
        ),
        SizedBox(height: 15),
        _buildBoxedTextField(controller: _locationController, focusNode: _locationFocus, hint: _t('location'), touched: _locationTouched,
          validator: (value) => value!.isEmpty ? _t('enterLocation') : null,
        ),
      ],
    );
  }

  // ... (All other _build... methods are identical to your original code) ...
  // _buildMobileFieldWithButton, _buildDropdownAndUploads, _buildBoxedTextField
  // _buildRadioGroups, _buildRadioGroup, _buildDropdownField, _showSkillDialog

  // NOTE: I am including the full code for the remaining builder methods
  // to ensure nothing is missed, as per your request.
  Widget _buildMobileFieldWithButton() {
    bool hasFocus = _mobileFocus.hasFocus;
    String? errorText;
    if (_mobileTouched) {
      if (_mobileController.text.isEmpty) { errorText = _t('enterMobile'); } 
      else if (_mobileController.text.length != 10) { errorText = _t('mobileLength'); }
    }
    bool isInvalid = errorText != null;
    bool isValid = !isInvalid && _mobileTouched && _mobileController.text.isNotEmpty;
    Color getBorderColor() { if (isValid) return Colors.green; if (isInvalid) return Colors.red; return Colors.grey.shade400; }
    final Color finalBorderColor = getBorderColor();

    return TextFormField(
      controller: _mobileController, focusNode: _mobileFocus, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
      decoration: InputDecoration(
        hintText: hasFocus || _mobileController.text.isNotEmpty ? null : _t('mobile'), errorText: errorText, filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red, width: 2.0)),
        suffixIcon: _isLoading && !_otpSent
            ? Padding(padding: const EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
            : (_secondsRemaining > 0
                ? Center(widthFactor: 1, child: Text('$_secondsRemaining s', style: TextStyle(color: Colors.grey)))
                : TextButton(onPressed: _sendOtp, child: Text(_otpSent ? "Resend" : "Send OTP"))),
      ),
      onTap: () => setState(() {}), onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDropdownAndUploads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 15),
        _buildDropdownField(),
        SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _bloodGroup, hint: Text(_t('bloodGroup')), decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
          onChanged: (val) => setState(() => _bloodGroup = val), validator: (value) => value == null ? _t('selectBloodGroup') : null,
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(_t('uploadPhoto'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 8),
                  if (_finalProfileImageBytes != null) Column(
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_finalProfileImageBytes!, height: 100, width: 100, fit: BoxFit.cover)),
                          TextButton(onPressed: () => setState(() => _finalProfileImageBytes = null), child: Text(_t('changePhoto'))),
                        ],
                      )
                  else ProfilePicturePicker(
                        onImageSelected: (file) async { final bytes = await file.readAsBytes(); setState(() => _finalProfileImageBytes = bytes); },
                        onWebImageSelected: (bytes) { setState(() => _finalProfileImageBytes = bytes); },
                      ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(_t('uploadID'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: _pickIdDocument, icon: Icon(Icons.attach_file), label: Text(_idDocument == null ? _t('uploadIdBtn') : _t('changeID'))),
                  if (_idDocument != null) Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: kIsWeb ? Image.network(_idDocument!.path, height: 100, width: 100, fit: BoxFit.cover) : Image.file(File(_idDocument!.path), height: 100, width: 100, fit: BoxFit.cover),
                      ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBoxedTextField({ required TextEditingController controller, required FocusNode focusNode, required String hint, required bool touched, String? Function(String?)? validator, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters,}) {
    String? errorText = touched ? validator?.call(controller.text) : null;
    bool isInvalid = errorText != null;
    bool isValid = !isInvalid && touched && controller.text.isNotEmpty;
    Color getBorderColor() { if (isValid) return Colors.green; if (isInvalid) return Colors.red; return Colors.grey.shade400; }
    final Color finalBorderColor = getBorderColor();
    return TextFormField(
      controller: controller, focusNode: focusNode, keyboardType: keyboardType, inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: focusNode.hasFocus || controller.text.isNotEmpty ? null : hint, errorText: errorText, filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.red, width: 2.0)),
      ),
      onTap: () => setState(() {}), onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRadioGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 15),
        _buildRadioGroup<String>(label: _t('gender'), value: _gender, options: [_t('male'), _t('female')], originalOptions: ['Male', 'Female'], onChanged: (val) => setState(() => _gender = val)),
        _buildRadioGroup<String>(label: _t('maritalStatus'), value: _maritalStatus, options: [_t('married'), _t('single'), _t('widow'), _t('separated')], originalOptions: ['Married', 'Single', 'Widow', 'Separated'], onChanged: (val) => setState(() => _maritalStatus = val)),
        _buildRadioGroup<String>(label: _t('religion'), value: _religion, options: [_t('hindu'), _t('christianity'), _t('islam'), _t('other')], originalOptions: ['Hindu', 'Christianity', 'Islam', 'Other'], onChanged: (val) => setState(() => _religion = val)),
      ],
    );
  }

  Widget _buildRadioGroup<T>({ required String label, required T? value, required List<T> options, required List<T> originalOptions, required void Function(T?) onChanged }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Wrap(
          alignment: WrapAlignment.start, spacing: 10,
          children: List.generate(options.length, (index) {
            final displayOption = options[index];
            final valueOption = originalOptions[index];
            return Row(mainAxisSize: MainAxisSize.min, children: [ Radio<T>(value: valueOption, groupValue: value, onChanged: onChanged), Text(displayOption.toString()), ]);
          }),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _occupation, hint: Text(_t('occupation')), decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: [ DropdownMenuItem<String>(value: "Business", child: Text(_t('business'))), DropdownMenuItem<String>(value: "Agriculture", child: Text(_t('agriculture'))), DropdownMenuItem<String>(value: "Agri Labour", child: Text(_t('agriLabour'))), DropdownMenuItem<String>(value: "Skill Labour", child: Text(_t('skillLabour')))],
          onChanged: (val) { setState(() { _occupation = val; if (val == 'Skill Labour') { _showSkillDialog(); } else { _skill = null; } }); },
        ),
        if (_occupation == 'Skill Labour' && _skill != null && _skill!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8.0, left: 10.0), child: Text('${_t('enteredSkill')}: $_skill', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
      ],
    );
  }

  void _showSkillDialog() {
    final skillController = TextEditingController(text: _skill);
    showDialog(
      context: context, builder: (ctx) => AlertDialog(
        title: Text(_t('enterSkill')), content: TextField(controller: skillController, decoration: InputDecoration(hintText: _t('enterSkill'))),
        actions: [ TextButton(onPressed: () { setState(() => _skill = skillController.text); Navigator.of(ctx).pop(); }, child: Text(_t('ok'))), ],
      ),
    );
  }
}