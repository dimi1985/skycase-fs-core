import 'dart:convert';
import 'package:http/http.dart' as http;

dynamic safeJsonDecode(http.Response response, {String? tag}) {
  final body = response.body.trim();
  final label = tag ?? 'HTTP';

  print('[$label] STATUS: ${response.statusCode}');
  print('[$label] CONTENT-TYPE: ${response.headers['content-type']}');
  print('[$label] BODY: $body');

  if (body.isEmpty) {
    throw Exception('[$label] Empty response body');
  }

  try {
    return jsonDecode(body);
  } catch (e) {
    throw Exception(
      '[$label] Invalid JSON response. '
      'Status=${response.statusCode}, '
      'Body="$body"',
    );
  }
}