import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  final String message, code;
  final int status;
  ApiException(this.message, {this.code = '', this.status = 0});
  @override
  String toString() => message;
}

class MusaApi {
  final http.Client client;
  String baseUrl = '', token = '';
  MusaApi({http.Client? client}) : client = client ?? http.Client();
  bool get connected => baseUrl.isNotEmpty && token.isNotEmpty;
  Map<String, String> get headers => {'Authorization': 'Bearer $token'};
  String mediaUrl(String id) => '$baseUrl/v1/media/$id';
  static String normalizeUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['http', 'https'].contains(uri.scheme) ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ApiException(
        'Introduce la dirección completa de tu servidor, por ejemplo https://musa.tudominio.com',
      );
    }
    final h = uri.host;
    final local =
        h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '::1' ||
        h.startsWith('192.168.') ||
        h.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[01])\.').hasMatch(h) ||
        h.endsWith('.local');
    if (uri.scheme != 'https' && !local) {
      throw ApiException('Para un servidor en Internet utiliza HTTPS.');
    }
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static String requestKey() =>
      base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');
  Future<Json> request(
    String method,
    String path, {
    Json? data,
    bool idempotent = false,
    String? requestId,
    Duration timeout = const Duration(seconds: 75),
  }) async {
    if (baseUrl.isEmpty) {
      throw ApiException(
        'Conecta tu espacio desde el botón de perfil para usar tu armario y la IA.',
        code: 'NOT_CONNECTED',
      );
    }
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers.addAll({
        'Content-Type': 'application/json',
        if (token.isNotEmpty) ...headers,
        if (idempotent) 'Idempotency-Key': requestId ?? requestKey(),
      });
      if (data != null) req.body = jsonEncode(data);
      final response = await http.Response.fromStream(
        await client.send(req).timeout(timeout),
      ).timeout(timeout);
      final result = parseObject(response.body);
      if (response.statusCode >= 400) {
        throw ApiException(
          result['error']?['message'] ?? 'No se pudo completar la operación.',
          code: result['error']?['code'] ?? '',
          status: response.statusCode,
        );
      }
      return result;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'La conexión está tardando demasiado. Revisa tu conexión y vuelve a intentarlo.',
        code: 'TIMEOUT',
      );
    } catch (_) {
      throw ApiException(
        'No pude conectar con tu espacio. Revisa la dirección y tu conexión a Internet.',
        code: 'NETWORK',
      );
    }
  }

  Future<Uint8List> mediaBytes(String id) async {
    final result = await client
        .get(Uri.parse(mediaUrl(id)), headers: headers)
        .timeout(const Duration(seconds: 30));
    if (result.statusCode != 200) {
      throw ApiException('No se pudo cargar la fotografía.');
    }
    return result.bodyBytes;
  }
}
