import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import 'token_storage_interface.dart';

class AuthService {
  final Dio _dio;
  final TokenStorageInterface _tokenStorage;
  final Logger _logger = Logger();
  
  HttpServer? _redirectServer;
  String? _codeVerifier;
  String? _state;
  
  AuthService({
    required Dio dio,
    required TokenStorageInterface tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;
  
  // Generate random string for PKCE
  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Generate code challenge from verifier
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }
  
  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _tokenStorage.getAccessToken();
    if (token == null) return false;
    
    // TODO: Validate token expiry
    return true;
  }
  
  // Start OAuth flow with PKCE
  Future<bool> signIn() async {
    try {
      // Generate PKCE parameters
      _codeVerifier = _generateRandomString(128);
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);
      _state = _generateRandomString(32);
      
      // Start local redirect server
      await _startRedirectServer();
      
      // Build authorization URL
      final authUrl = Uri.parse(AppConstants.authorizationEndpoint).replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': AppConstants.clientId,
          'redirect_uri': AppConstants.redirectUri,
          'scope': AppConstants.scopes.join(' '),
          'state': _state,
          'code_challenge': codeChallenge,
          'code_challenge_method': 'S256',
        },
      );
      
      _logger.i('Starting OAuth flow with URL: $authUrl');
      
      // Open browser for authentication
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser for authentication');
      }
      
      // Wait for redirect with timeout
      final code = await _waitForAuthorizationCode().timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _stopRedirectServer();
          throw TimeoutException('Authentication timeout');
        },
      );
      
      // Exchange code for tokens
      final success = await _exchangeCodeForTokens(code);
      
      _stopRedirectServer();
      return success;
      
    } catch (e) {
      _logger.e('Authentication failed: $e');
      _stopRedirectServer();
      return false;
    }
  }
  
  // Start local server to handle OAuth redirect
  Future<void> _startRedirectServer() async {
    if (_redirectServer != null) {
      await _stopRedirectServer();
    }
    
    final uri = Uri.parse(AppConstants.redirectUri);
    _redirectServer = await HttpServer.bind('localhost', uri.port);
    _logger.i('Redirect server started on port ${uri.port}');
  }
  
  // Stop redirect server
  Future<void> _stopRedirectServer() async {
    if (_redirectServer != null) {
      await _redirectServer!.close();
      _redirectServer = null;
      _logger.i('Redirect server stopped');
    }
  }
  
  // Wait for authorization code from redirect
  Future<String> _waitForAuthorizationCode() async {
    final completer = Completer<String>();
    
    _redirectServer?.listen((request) async {
      final uri = request.uri;
      
      if (uri.path == '/callback') {
        final code = uri.queryParameters['code'];
        final state = uri.queryParameters['state'];
        final error = uri.queryParameters['error'];
        
        // Send success response to browser
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write('''
            <!DOCTYPE html>
            <html>
            <head>
              <title>Authentication Successful</title>
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  height: 100vh;
                  margin: 0;
                  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                }
                .container {
                  text-align: center;
                  background: white;
                  padding: 48px;
                  border-radius: 16px;
                  box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                }
                h1 { color: #333; margin-bottom: 16px; }
                p { color: #666; font-size: 18px; }
                .checkmark {
                  width: 80px;
                  height: 80px;
                  margin: 0 auto 24px;
                  background: #4CAF50;
                  border-radius: 50%;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                }
                .checkmark:after {
                  content: '✓';
                  color: white;
                  font-size: 48px;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="checkmark"></div>
                <h1>Authentication Successful!</h1>
                <p>You can now close this window and return to FlowHunt Desktop.</p>
              </div>
              <script>
                setTimeout(() => window.close(), 3000);
              </script>
            </body>
            </html>
          ''');
        await request.response.close();
        
        if (error != null) {
          completer.completeError(Exception('OAuth error: $error'));
        } else if (code != null && state == _state) {
          completer.complete(code);
        } else {
          completer.completeError(Exception('Invalid OAuth response'));
        }
      }
    });
    
    return completer.future;
  }
  
  // Exchange authorization code for tokens
  Future<bool> _exchangeCodeForTokens(String code) async {
    try {
      final response = await _dio.post(
        AppConstants.tokenEndpoint,
        data: {
          'grant_type': 'authorization_code',
          'client_id': AppConstants.clientId,
          'code': code,
          'redirect_uri': AppConstants.redirectUri,
          'code_verifier': _codeVerifier,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        await _tokenStorage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        
        _logger.i('Tokens saved successfully');
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e('Token exchange failed: $e');
      return false;
    }
  }
  
  // Refresh access token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        AppConstants.tokenEndpoint,
        data: {
          'grant_type': 'refresh_token',
          'client_id': AppConstants.clientId,
          'refresh_token': refreshToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        await _tokenStorage.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'] ?? refreshToken,
        );
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.e('Token refresh failed: $e');
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _tokenStorage.clearTokens();
    _logger.i('User signed out');
  }
  
  // Get current access token
  Future<String?> getAccessToken() async {
    return await _tokenStorage.getAccessToken();
  }
}