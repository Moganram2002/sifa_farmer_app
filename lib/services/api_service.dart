// lib/services/api_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/auth_storage.dart';
import '../models/user_data.dart';

class ApiService {
  final String _baseUrl = "http://localhost:3000/api";

  // ### FIX: Added the missing helper method ###
  String getBaseUrlForImages() {
    // Returns the base part of the URL (e.g., "http://localhost:3000")
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

  // --- Authentication Methods ---
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

  // --- Public Registration ---
  Future<Map<String, dynamic>> register(
    Map<String, String?> userData,
    Uint8List? profilePhotoBytes,
    XFile? idDocument,
  ) async {
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

    if (idDocument != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'id_document',
        idDocument.path,
        filename: idDocument.name,
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

  // --- User Management (Admin/SuperAdmin) ---

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
    XFile? idDocument,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/create-by-admin');
    var request = http.MultipartRequest('POST', uri);

    request.headers.addAll(await _getHeaders(isJson: false));
    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    if (profilePhoto != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profilePhoto', // Must match backend key
        profilePhoto,
        filename: 'profile_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (idDocument != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'idDocument', // Must match backend key
        idDocument.path,
        filename: idDocument.name,
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

  Future<Map<String, dynamic>> updateUser(
    int userId, {
    required Map<String, String?> userData,
    Uint8List? profilePhoto,
    XFile? idDocument,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/$userId');
    var request = http.MultipartRequest('PUT', uri);

    request.headers.addAll(await _getHeaders(isJson: false));
    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    if (profilePhoto != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profilePhoto', // Must match backend key
        profilePhoto,
        filename: 'profile_photo_updated.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    if (idDocument != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'idDocument', // Must match backend key
        idDocument.path,
        filename: idDocument.name,
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

  // Other admin methods
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
}