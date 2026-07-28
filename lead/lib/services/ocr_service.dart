import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OCRService {
  static String get baseUrl => AuthService.baseUrl;

  static Future<Map<String, dynamic>> processVisitingCard(
    List<int> bytes,
  ) async {
    final url = Uri.parse('$baseUrl/api/ocr/tesseract');
    final request = http.MultipartRequest('POST', url);

    // Add token if needed (assuming public for now based on current app pattern or added if auth middleware requires it)
    final token = await AuthService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: 'card.jpg'),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('OCR Failed: ${response.statusCode} - ${response.body}');
    }
  }
}
