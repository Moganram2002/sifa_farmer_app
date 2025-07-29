import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/auth_storage.dart';
import '../models/user_data.dart';

class ApiService {
  final String _baseUrl = "http://localhost:3000/api";

    String getBaseUrlForImages() {
    return _baseUrl.replaceAll('/api', '');
  }

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final token = await AuthStorage.getToken();
    Map<String, String> headers = {};
    if (isJson) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> sendOtp(String mobile) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/send-otp'),
      headers: await _getHeaders(),
      body: jsonEncode({'mobile': mobile}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String mobile, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: await _getHeaders(),
      body: jsonEncode({'mobile': mobile, 'otp': otp}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['error'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> sendRegistrationOtp(String mobile) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register-send-otp'),
      headers: await _getHeaders(),
      body: jsonEncode({'mobile': mobile}),
    );
    return jsonDecode(response.body);
  }
  
  Future<List<String>> getAadharNumbers(String mobile) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/aadhar/$mobile'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['aadhar'] != null && data['aadhar'] is List) {
          return List<String>.from(data['aadhar']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching Aadhaar numbers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int userId, {
    required Map<String, String?> userData,
    Uint8List? profilePhoto,
    Uint8List? idDocumentBytes,
    String? idDocumentName,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/$userId');
    var request = http.MultipartRequest('PUT', uri); 

    request.headers.addAll(await _getHeaders(isJson: false));
    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    if (profilePhoto != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profilePhoto',
        profilePhoto,
        filename: 'profile_photo_updated.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (idDocumentBytes != null && idDocumentName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'idDocument',
        idDocumentBytes,
        filename: idDocumentName,
      ));
    }
    
    try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        final responseData = json.decode(response.body);

        if (response.statusCode >= 200 && response.statusCode < 300) {
            return responseData;
        } else {
            throw Exception('Failed to update user: ${responseData['error'] ?? response.body}');
        }
    } catch (e) {
        throw Exception('An error occurred: $e');
    }
  }

 Future<Map<String, dynamic>> register({
    required Map<String, String?> userData,
    Uint8List? profilePhotoBytes,
    Uint8List? idDocumentBytes,
    String? idDocumentName,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/register');
    var request = http.MultipartRequest('POST', uri);

    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    if (profilePhotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profile_photo',
        profilePhotoBytes,
        filename: 'profile_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (idDocumentBytes != null && idDocumentName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'id_document',
        idDocumentBytes,
        filename: idDocumentName,
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        return {'error': responseData['error'] ?? 'An unknown server error occurred.'};
      }
    } catch (e) {
      return {'error': 'Failed to connect to the server. Please check your connection.'};
    }
  }

  Future<UserData> getUserById(int id) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/$id'), headers: await _getHeaders());
    if (response.statusCode == 200) {
      return UserData.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load user details');
  }

 Future<Map<String, dynamic>> createUserByAdmin({
    required Map<String, String?> userData,
    Uint8List? profilePhoto,
    Uint8List? idDocumentBytes,
    String? idDocumentName,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/create-by-admin');
    var request = http.MultipartRequest('POST', uri);

    request.headers.addAll(await _getHeaders(isJson: false));
    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    if (profilePhoto != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profilePhoto',
        profilePhoto,
        filename: 'profile_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (idDocumentBytes != null && idDocumentName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'idDocument',
        idDocumentBytes,
        filename: idDocumentName,
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseData;
      } else {
        return {'error': responseData['error'] ?? 'Failed to create user.'};
      }
    } catch (e) {
      return {'error': 'A connection error occurred.'};
    }
  }

  Future<Map<String, dynamic>> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/users/$id'), headers: await _getHeaders());
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/users'), headers: await _getHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load all users');
  }

  Future<Map<String, dynamic>> updateUserStatus(int userId, int status) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/status');
    final response = await http.put(
      uri,
      headers: await _getHeaders(),
      body: json.encode({'status': status}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update user status');
    }
  }

  Future<Map<String, dynamic>> makeUserAdmin(int id) async {
    final response = await http.put(Uri.parse('$_baseUrl/users/$id/make-admin'), headers: await _getHeaders());
    if (response.statusCode != 200) throw Exception('Failed to promote user');
    return jsonDecode(response.body);
  }
  
  Future<List<dynamic>> getAdminUsers(int adminId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/admin/$adminId/users'), headers: await _getHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load users for admin');
  }
   Future<Map<String, dynamic>> removeAdmin(int id) async {
    final response = await http.put(Uri.parse('$_baseUrl/users/$id/remove-admin'), headers: await _getHeaders());
    if (response.statusCode != 200) throw Exception('Failed to remove admin role');
    return jsonDecode(response.body);
  }
   
  Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/settings'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load settings from server');
    }
  }

 
  Future<Map<String, dynamic>> updateSettings({
    String? title,
    String? copyright,
  }) async {
    final body = <String, String>{};
    if (title != null) body['app_title'] = title;
    if (copyright != null) body['copyright_text'] = copyright;

    final response = await http.post(
      Uri.parse('$_baseUrl/users/settings'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to update settings');
    }
  }


  Future<List<String>> getSkills() async {
    try {
   
      final response = await http.get(
        Uri.parse('$_baseUrl/skills'), 
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        
        List<dynamic> data = jsonDecode(response.body);
        return data.cast<String>();
      }
      return [];
    } catch (e) {
      print('Error fetching skills: $e');
      return []; 
    }
  }

}
