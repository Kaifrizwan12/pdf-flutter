import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/logging_http_client.dart';

/// Thin HTTP wrapper. Sends `x-company-id` on every request — no auth tokens.
class ApiService {
  final String baseUrl;
  final String companyId;
  final http.Client _client;

  ApiService({
    required this.baseUrl,
    required this.companyId,
    http.Client? client,
  }) : _client = client ?? LoggingHttpClient();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-company-id': companyId,
      };

  Future<Map<String, dynamic>> get(String path) async {
    final separator = path.contains('?') ? '&' : '?';
    final cacheBuster = '_t=${DateTime.now().millisecondsSinceEpoch}';
    final url = Uri.parse('$baseUrl$path$separator$cacheBuster');
    final res = await _client.get(url, headers: _headers);
    return _parse(res, path);
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic> body = const {}}) async {
    final res = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res, path);
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic> body = const {}}) async {
    final res = await _client.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res, path);
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic> body = const {}}) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res, path);
  }

  Future<void> delete(String path) async {
    final res =
        await _client.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    _parse(res, path);
  }

  Map<String, dynamic> _parse(http.Response res, String path) {
    if (res.statusCode >= 400) {
      final body = res.body.isNotEmpty ? res.body : '{}';
      final msg = (jsonDecode(body) as Map)['error'] ?? res.reasonPhrase;
      debugPrint('[api] $path → ${res.statusCode}: $msg');
      throw ApiException(res.statusCode, msg.toString());
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
