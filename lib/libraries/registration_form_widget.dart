import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../profile_picture_picker.dart';
import '../utils/auth_storage.dart';

class RegistrationPayload {
  final Map<String, String?> userData;
  final Uint8List? profilePhotoBytes;
  final Uint8List? idDocumentBytes;
  final String? idDocumentName;

  RegistrationPayload({
    required this.userData,
    this.profilePhotoBytes,
    this.idDocumentBytes,
    this.idDocumentName,
  });
}

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

class RegistrationForm extends StatefulWidget {
  final ApiService apiService;
  final Future<void> Function(RegistrationPayload payload) onFormSubmit;
  final String submitButtonText;
  final bool isOtpFieldVisible;
  final String formTitle;
  final Map<String, dynamic>? initialData;

  const RegistrationForm({
    Key? key,
    required this.apiService,
    required this.onFormSubmit,
    this.submitButtonText = 'Create User',
    this.isOtpFieldVisible = true,
    this.formTitle = 'Registration Form',
    this.initialData,
  }) : super(key: key);

  @override
  _RegistrationFormState createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<RegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isFetchingImage = false;

  Map<String, String> _translations = {};
  bool _isTranslating = false;
  final Map<String, String> _defaultTexts = {
    'formTitle': 'Registration Form', 'fullName': 'Full Name', 'mobile': 'Mobile Number', 'otp': 'OTP', 'aadhar': 'Aadhar Number', 'emergency': 'Emergency Contact',
    'location': 'Location', 'bloodGroup': 'Select Blood Group', 'uploadPhoto': 'Profile Photo', 'changePhoto': 'Change Photo', 'uploadID': 'ID Card', 
    'changeID': 'Change ID Document', 'createUser': 'Create User', 'gender': 'Gender', 'maritalStatus': 'Marital Status', 'religion': 'Religion', 
    'occupation': 'Select Occupation', 'enterSkill': 'Enter Occupation', 'enteredSkill': 'Entered Occupation', 'male': 'Male', 'female': 'Female', 'married': 'Married', 
    'single': 'Single', 'widow': 'Widow', 'separated': 'Separated', 'hindu': 'Hindu', 'christianity': 'Christianity', 'islam': 'Islam', 'other': 'Other', 
    'business': 'Business', 'agriculture': 'Agriculture', 'agriLabour': 'Agri Labour', 'skillLabour': 'Other', 'enterName': 'Enter Name', 
    'nameMinLength': 'Name must be more than 5 letters', 'nameOnlyAlphabets': 'Only alphabets and spaces allowed', 'enterMobile': 'Enter your mobile number',
    'mobileLength': 'Mobile number must be 10 digits', 'enterOTP': 'Enter OTP', 'enterAadhar': 'Enter your Aadhar number', 'aadharLength': 'Aadhar number must be 12 digits',
    'enterEmergency': 'Enter emergency contact', 'emergencyLength': 'Emergency contact must be 10 digits', 'enterLocation': 'Please enter location',
    'selectBloodGroup': 'Please select blood group', 'formSubmitted': 'Form submitted successfully!', 'ok': 'OK', 'uploadIdBtn': 'Generate ID',
  };

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _aadharController = TextEditingController();
  final _locationController = TextEditingController();
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
  
  Uint8List? _idDocumentBytes;
  String? _idDocumentName;

  String? _gender;
  String? _maritalStatus;
  String? _religion;
  String? _occupation;
  String? _skill;
  String? _bloodGroup;
  String _selectedLanguage = 'en';

  bool _otpSent = false;
  Timer? _timer;
  int _secondsRemaining = 0;

  List<String> _skillSuggestions = [];
  bool _isFetchingSkills = false;
  
  @override
  void initState() {
    super.initState();
    _initializeFormWithData();
    _addFocusListeners();
    _translateAll();
    _fetchSkills();
  }

  Future<void> _fetchSkills() async {
    if (_isFetchingSkills) return;
    setState(() => _isFetchingSkills = true);
    try {
      final skills = await widget.apiService.getSkills();
      if (mounted) {
        setState(() {
          _skillSuggestions = skills;
        });
      }
    } catch (e) {
      print("Failed to fetch skill suggestions: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingSkills = false);
      }
    }
  }

  void _initializeFormWithData() {
    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameController.text = data['name'] ?? '';
      _mobileController.text = data['mobile'] ?? '';
      _aadharController.text = data['aadhar_number'] ?? '';
      _emergencyContactController.text = data['emergency_contact'] ?? '';
      _locationController.text = data['location'] ?? 'salem';
      _skillController.text = data['skill'] ?? '';
      
      _gender = data['gender'];
      _maritalStatus = data['marital_status'];
      _religion = data['religion'];
      _occupation = data['occupation'];
      _skill = data['skill'];
      _bloodGroup = data['blood_group'];
      
      final photoUrl = data['profile_photo_url'];
      if (photoUrl != null && photoUrl.isNotEmpty) {
        _loadInitialImage(photoUrl);
      }

    } else {
      _locationController.text = "salem";
      _gender = 'Male';
      _maritalStatus = 'Married';
      _religion = 'Hindu';
    }
  }

  Future<void> _loadInitialImage(String imagePath) async {
    const String baseUrl = "http://localhost:3000/uploads/";
    final String fullUrl = baseUrl + imagePath;

    setState(() => _isFetchingImage = true);
    try {
      final String? token = await AuthStorage.getToken();
      if (token == null) {
        _showMessage('Authentication error.', isError: true);
        return;
      }
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _finalProfileImageBytes = response.bodyBytes;
          });
        }
      } else {
        _showMessage('Failed to load existing profile picture.', isError: true);
      }
    } catch (e) {
      _showMessage('Error retrieving profile picture.', isError: true);
      print("Error loading image from URL: $e");
    } finally {
      if (mounted) {
        setState(() => _isFetchingImage = false);
      }
    }
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _idDocumentBytes = bytes;
        _idDocumentName = pickedFile.name;
      });
    }
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

  Future<void> _handleFormSubmission() async {
    setState(() {
      _nameTouched = true; _mobileTouched = true; _otpTouched = true;
      _aadharTouched = true; _locationTouched = true; _emergencyTouched = true;
    });

    if (_formKey.currentState?.validate() ?? false) {
      if (_finalProfileImageBytes == null && widget.initialData?['profile_photo_url'] == null) {
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
        idDocumentBytes: _idDocumentBytes,
        idDocumentName: _idDocumentName,
      );
      
      await widget.onFormSubmit(payload);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      _showMessage('Please correct the errors in the form.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_t('formTitle'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 93, 213, 97))),
          const SizedBox(height: 20),
          _buildTextFields(),
          _buildRadioGroups(),
          _buildDropdownAndUploads(),
          const SizedBox(height: 30),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _handleFormSubmission,
                  child: Text(_t('createUser'), style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 93, 213, 97),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
        ],
      ),
    );
  }

  // --- MODIFIED: This dialog now has an OK button ---
  void _showSkillDialog() {
    // Create a controller here to access the text field's value in the actions.
    final skillInputController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('enterSkill')),
        content: Autocomplete<String>(
          // This builder creates the text field.
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            // We need to sync our external controller with the Autocomplete's internal one.
            skillInputController.text = controller.text;
            return TextFormField(
              controller: controller, // Use Autocomplete's controller for its internal logic
              focusNode: focusNode,
              autofocus: true,
              decoration: InputDecoration(hintText: _t('enterSkill')),
              onChanged: (value) {
                // Keep our external controller updated as the user types
                skillInputController.text = value;
              },
              onFieldSubmitted: (value) {
                // If user presses enter, confirm and close.
                setState(() => _skill = value);
                Navigator.of(ctx).pop();
              },
            );
          },
          // This builder provides the suggestion list.
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return _skillSuggestions.where((option) =>
                option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          // This is called when a user taps a suggestion.
          onSelected: (String selection) {
            setState(() => _skill = selection);
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          // This is the new "OK" button.
          TextButton(
            child: Text(_t('ok')),
            onPressed: () {
              // When pressed, it takes the text from our external controller,
              // sets the state, and closes the dialog.
              setState(() => _skill = skillInputController.text);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _occupation,
          hint: Text(_t('occupation')),
          decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: [ 
             const DropdownMenuItem<String>(value: "Business", child: Text('Business')), 
             const DropdownMenuItem<String>(value: "Agriculture", child: Text('Agriculture')), 
             const DropdownMenuItem<String>(value: "Agri Labour", child: Text('Agri Labour')), 
             const DropdownMenuItem<String>(value: "Skill Labour", child: Text('Others'))
          ],
          onChanged: (val) {
            setState(() {
              _occupation = val;
              if (val == 'Skill Labour') {
                _showSkillDialog(); // Use the new dialog
              } else {
                _skill = null;
              }
            });
          },
        ),
        if (_occupation == 'Skill Labour' && _skill != null && _skill!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 10.0),
            child: Text('${_t('enteredSkill')}: $_skill', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
          ),
      ],
    );
  }

  Widget _buildTextFields() {
    return Column(
      children: [
        _buildBoxedTextField(controller: _nameController, focusNode: _nameFocus, hint: _t('fullName'), touched: _nameTouched, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterName'); if (value.length < 5) return _t('nameMinLength'); return null; },
        ),
        const SizedBox(height: 15),
        _buildMobileFieldWithButton(),
        if (widget.isOtpFieldVisible) ...[
          const SizedBox(height: 15),
          _buildBoxedTextField(controller: _otpController, focusNode: _otpFocus, hint: _t('otp'), touched: _otpTouched, keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            validator: (value) => value!.isEmpty ? _t('enterOTP') : null,
          ),
        ],
        const SizedBox(height: 15),
        _buildBoxedTextField(controller: _aadharController, focusNode: _aadharFocus, hint: _t('aadhar'), touched: _aadharTouched, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterAadhar'); if (value.length != 12) return _t('aadharLength'); return null; },
        ),
        const SizedBox(height: 15),
        _buildBoxedTextField(controller: _emergencyContactController, focusNode: _emergencyContactFocus, hint: _t('emergency'), touched: _emergencyTouched, keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          validator: (value) { if (value == null || value.isEmpty) return _t('enterEmergency'); if (value.length != 10) return _t('emergencyLength'); return null; },
        ),
        const SizedBox(height: 15),
        _buildBoxedTextField(controller: _locationController, focusNode: _locationFocus, hint: _t('location'), touched: _locationTouched,
          validator: (value) => value!.isEmpty ? _t('enterLocation') : null,
        ),
      ],
    );
  }

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
      readOnly: widget.initialData != null,
      decoration: InputDecoration(
        hintText: hasFocus || _mobileController.text.isNotEmpty ? null : _t('mobile'), errorText: errorText, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 2.0)),
        suffixIcon: widget.isOtpFieldVisible ? (_isLoading && !_otpSent
            ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
            : (_secondsRemaining > 0
                ? Center(widthFactor: 1, child: Text('$_secondsRemaining s', style: const TextStyle(color: Colors.grey)))
                : TextButton(onPressed: _sendOtp, child: Text(_otpSent ? "Resend" : "Send OTP"), style: TextButton.styleFrom(foregroundColor: Colors.green.shade700)))) : null,
      ),
      onTap: () => setState(() {}), onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDropdownAndUploads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        _buildDropdownField(),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          value: _bloodGroup, hint: Text(_t('bloodGroup')), decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((val) => DropdownMenuItem<String>(value: val, child: Text(val))).toList(),
          onChanged: (val) => setState(() => _bloodGroup = val), validator: (value) => value == null ? _t('selectBloodGroup') : null,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(_t('uploadPhoto'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  _isFetchingImage
                    ? const CircularProgressIndicator()
                    : _finalProfileImageBytes != null 
                      ? Column(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_finalProfileImageBytes!, height: 100, width: 100, fit: BoxFit.cover)),
                            TextButton(onPressed: () => setState(() => _finalProfileImageBytes = null), child: Text(_t('changePhoto')), style: TextButton.styleFrom(foregroundColor: Colors.green.shade700)),
                          ],
                        )
                      : ProfilePicturePicker(
                          onImageSelected: (file) async { final bytes = await file.readAsBytes(); setState(() => _finalProfileImageBytes = bytes); },
                          onWebImageSelected: (bytes) { setState(() => _finalProfileImageBytes = bytes); },
                        ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(_t('uploadID'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _pickIdDocument, 
                    icon: const Icon(Icons.attach_file), 
                    label: Text(_idDocumentBytes == null ? _t('uploadIdBtn') : _t('changeID')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                  if (_idDocumentBytes != null) Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_idDocumentBytes!, height: 100, width: 100, fit: BoxFit.cover),
                        ),
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
        hintText: focusNode.hasFocus || controller.text.isNotEmpty ? null : hint, errorText: errorText, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: finalBorderColor, width: 2.0)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 2.0)),
      ),
      onTap: () => setState(() {}), onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildRadioGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
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
        Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 4.0), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        Wrap(
          alignment: WrapAlignment.start, spacing: 10,
          children: List.generate(options.length, (index) {
            final displayOption = options[index];
            final valueOption = originalOptions[index];
            return Row(mainAxisSize: MainAxisSize.min, children: [ Radio<T>(value: valueOption, groupValue: value, onChanged: onChanged, activeColor: Colors.green), Text(displayOption.toString()), ]);
          }),
        ),
      ],
    );
  }
}