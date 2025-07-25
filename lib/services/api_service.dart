import 'dart:convert';
import 'dart:typed_data'; // Required for Uint8List
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // Required for XFile
import 'package:http_parser/http_parser.dart'; // Required for MediaType
import '../utils/auth_storage.dart';
import 'dart:io'; // Keep for other methods if they use File

class ApiService {
  // IMPORTANT: For mobile testing, replace 'localhost' with your computer's local network IP address.
  // Example: final String _baseUrl = "http://192.168.1.10:3000/api";
  final String _baseUrl = "http://localhost:3000/api";

  
  // --- NEW: Updated register method for file uploads ---
  Future<Map<String, dynamic>> register(
    Map<String, String?> userData,
    Uint8List? profilePhotoBytes,
    XFile? idDocument,
  ) async {
    // Note: The backend route is '/users/register'
    final uri = Uri.parse('$_baseUrl/users/register');
    var request = http.MultipartRequest('POST', uri);

    // Add authorization headers
    final authHeaders = await _getHeaders(isJson: false); // Headers for multipart are set differently
    request.headers.addAll(authHeaders);

    // Add all the text fields from userData to the request
    userData.forEach((key, value) {
      if (value != null) {
        request.fields[key] = value;
      }
    });

    // Add the profile photo file from bytes
    if (profilePhotoBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profile_photo', // This key must match the one expected by the backend
        profilePhotoBytes,
        filename: 'profile_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    // Add the ID document file from its path (if it exists)
    if (idDocument != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'id_document', // This key must match the one expected by the backend
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
        // Return a map with an error key if the request fails
        return {'error': responseData['error'] ?? 'An unknown server error occurred.'};
      }
    } catch (e) {
      // Handle network errors or other exceptions
      return {'error': 'Failed to connect to the server. Please check your connection.'};
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

  

  Future<String?> uploadFile(File file) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/files/upload'));
    request.headers.addAll(await _getHeaders(isJson: false));
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    var res = await request.send();
    if (res.statusCode == 200) {
      final responseBody = await res.stream.bytesToString();
      return jsonDecode(responseBody)['filePath'];
    }
    return null;
  }
 

  Future<Map<String, dynamic>> deleteUser(int id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/users/$id'), headers: await _getHeaders());
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> adminDeleteUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/admin/delete-user/$userId'),
      headers: await _getHeaders(),
    );
    return jsonDecode(response.body);
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
      Uri.parse('$_baseUrl/auth/send-otp'), // Assuming you have an auth.js for this
      headers: await _getHeaders(),
      body: jsonEncode({'mobile': mobile}),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> login(String mobile, String otp) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'), // Assuming you have an auth.js for this
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

  Future<List<String>> getAadharNumbers(String mobile) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/aadhar/$mobile'), // Assuming this is in users.js
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body)['aadhar']);
    } else {
      throw Exception('Failed to load Aadhaar numbers');
    }
  }
  
  // --- User Management (Admin & Super Admin) ---

  // UPDATED: This is now the single method for creating users. It now includes the auth token.
  Future<Map<String, dynamic>> createUserByAdmin({
    required Map<String, String?> userData,
    Uint8List? profilePhoto,
    XFile? idDocument,
  }) async {
    final uri = Uri.parse('$_baseUrl/users/create-by-admin');
    var request = http.MultipartRequest('POST', uri);

    // Add authentication token to the request headers
    request.headers.addAll(await _getHeaders(isJson: false));

    // Add text fields from the payload
    request.fields.addAll(userData.map((key, value) => MapEntry(key, value ?? '')));

    // Add profile photo file
    if (profilePhoto != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'profilePhoto',
        profilePhoto,
        filename: 'profile_photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    // Add ID document file
    if (idDocument != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'idDocument',
        idDocument.path,
        filename: idDocument.name,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create user: ${response.body}');
    }
  }

  // --- Super Admin Methods ---

  Future<List<dynamic>> getAllUsers() async {
    final response = await http.get(Uri.parse('$_baseUrl/users'), headers: await _getHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load all users');
  }

  // UPDATED: Now correctly includes the auth token
  Future<Map<String, dynamic>> updateUserStatus(int userId, int status) async {
    final uri = Uri.parse('$_baseUrl/users/$userId/status');
    final response = await http.put(
      uri,
      headers: await _getHeaders(), // Correctly adds auth token
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
  

  // --- Admin-Specific Methods ---

  Future<List<dynamic>> getAdminUsers(int adminId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/admin/$adminId/users'), headers: await _getHeaders());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load users for admin');
  }

  // NOTE: This method assumes a specific backend route for admins to update users they created.
  Future<Map<String, dynamic>> adminUpdateUser(int userId, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/admin/update-user/$userId'),
      headers: await _getHeaders(),
      body: jsonEncode(userData),
    );
    if (response.statusCode != 200) throw Exception('Failed to update user');
    return jsonDecode(response.body);
  }
}
