import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'api_service.dart';

class ZaloAuthService {
  static const MethodChannel _channel = MethodChannel('com.smartelec/zalo');

  /// Gọi MethodChannel để mở giao diện đăng nhập Zalo (App hoặc Web)
  /// Trả về oauthCode nếu thành công, throw Exception nếu thất bại.
  static Future<String?> authenticate(String codeChallenge) async {
    try {
      final String? oauthCode = await _channel.invokeMethod('authenticate', {
        'codeChallenge': codeChallenge,
      });
      return oauthCode;
    } on PlatformException catch (e) {
      debugPrint("Lỗi đăng nhập Zalo: ${e.message}");
      throw Exception(e.message ?? 'Lỗi đăng nhập Zalo');
    }
  }

  /// Lấy AccessToken và RefreshToken từ oauthCode
  static Future<Map<String, dynamic>?> getAccessToken(String oauthCode, String codeVerifier) async {
    try {
      final String? jsonString = await _channel.invokeMethod('getAccessToken', {
        'oauthCode': oauthCode,
        'codeVerifier': codeVerifier,
      });
      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("Lỗi lấy Zalo Token: ${e.message}");
      throw Exception(e.message ?? 'Lỗi lấy Zalo Token');
    }
  }

  /// Lấy thông tin Profile (id, name, picture) từ Zalo bằng AccessToken
  static Future<Map<String, dynamic>?> getProfile(String accessToken) async {
    try {
      final String? jsonString = await _channel.invokeMethod('getProfile', {
        'accessToken': accessToken,
      });
      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("Lỗi lấy Zalo Profile: ${e.message}");
      throw Exception(e.message ?? 'Lỗi lấy Zalo Profile');
    }
  }

  // --- TẠO CODE CHALLENGE/VERIFIER (PKCE) ---
  static String generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(43, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  static String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Orchestrate the entire Zalo Login flow
  static Future<Map<String, dynamic>> loginWithZalo() async {
    try {
      final verifier = generateCodeVerifier();
      final challenge = generateCodeChallenge(verifier);

      debugPrint("Bắt đầu Zalo Auth Flow...");
      final oauthCode = await authenticate(challenge);
      if (oauthCode == null) throw Exception("Không nhận được OAuth Code");

      debugPrint("Lấy Access Token...");
      final tokenData = await getAccessToken(oauthCode, verifier);
      if (tokenData == null || !tokenData.containsKey('access_token')) {
        throw Exception("Không nhận được Access Token");
      }
      final accessToken = tokenData['access_token'];

      debugPrint("Lấy thông tin Profile Zalo...");
      final profile = await getProfile(accessToken);
      if (profile == null || !profile.containsKey('id')) {
        throw Exception("Không lấy được Zalo Profile");
      }

      final zaloId = profile['id'];
      final name = profile['name'];
      final avatarUrl = profile['picture']?['data']?['url'];

      debugPrint("Gửi thông tin Zalo lên Backend: $zaloId, $name");
      final backendResponse = await ApiService.zaloLogin(
        zaloId: zaloId,
        name: name,
        avatarUrl: avatarUrl,
      );

      return backendResponse;
    } catch (e) {
      throw Exception("Đăng nhập Zalo thất bại: $e");
    }
  }
}

