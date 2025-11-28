import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:developer' as developer;

class AppConfig {
  static const String _defaultSupabaseUrl = 'https://hredzoouykvmoczrtugy.supabase.co';
  static const String _defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyZWR6b291eWt2bW9jenJ0dWd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIyNDI2MzAsImV4cCI6MjA3NzgxODYzMH0.4frhZ21FaYyEkrKap7XH74GsaREfbJts_xz77jULqoc';
  static const String _defaultGoogleClientId = '865540075455-569nkiendctrplbhvpenv8r996p1bhpo.apps.googleusercontent.com';

  static String _url = '';
  static String _anon = '';
  static String _googleWebClientId = '';
  static const String fcmServerKey = 'YOUR_FCM_SERVER_KEY'; // استبدلها بمفتاح FCM الخاص بك
  static bool _initialized = false;

  static String get supabaseUrl => _url;
  static String get supabaseAnonKey => _anon;
  static bool get supabaseReady => _initialized && _url.isNotEmpty && _anon.isNotEmpty;
  static String get googleWebClientId => _googleWebClientId.isNotEmpty ? _googleWebClientId : _defaultGoogleClientId;

  // Load configuration
  static Future<void> load() async {
    if (_initialized) return;
    
    try {
      developer.log('Loading Supabase configuration...', name: 'AppConfig');
      
      // Try to load from environment variables first
      _url = const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      _anon = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
      _googleWebClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
      
      developer.log('Environment variables loaded - URL: ${_url.isNotEmpty ? 'set' : 'not set'}', name: 'AppConfig');
      
      // If environment variables are not set, try to load from JSON file
      if (_url.isEmpty || _anon.isEmpty) {
        try {
          developer.log('Loading config from assets/config/supabase.json', name: 'AppConfig');
          final text = await rootBundle.loadString('assets/config/supabase.json');
          final json = jsonDecode(text) as Map<String, dynamic>;
          
          _url = (json['SUPABASE_URL'] as String?)?.trim() ?? '';
          _anon = (json['SUPABASE_ANON_KEY'] as String?)?.trim() ?? '';
          _googleWebClientId = (json['GOOGLE_WEB_CLIENT_ID'] as String?)?.trim() ?? _googleWebClientId;
          
          developer.log('Configuration loaded from JSON file', name: 'AppConfig');
        } catch (e) {
          developer.log('Failed to load config from assets: $e', name: 'AppConfig');
        }
      }
      
      // If still not set, use default values
      if (_url.isEmpty) _url = _defaultSupabaseUrl;
      if (_anon.isEmpty) _anon = _defaultSupabaseAnonKey;
      if (_googleWebClientId.isEmpty) _googleWebClientId = _defaultGoogleClientId;
      
      _initialized = true;
      
      developer.log('Supabase configuration loaded successfully', name: 'AppConfig');
      developer.log('Supabase URL: ${_url.substring(0, _url.length > 20 ? 20 : _url.length)}...', name: 'AppConfig');
      developer.log('Anon Key: ${_anon.substring(0, 10)}...', name: 'AppConfig');
      
    } catch (e) {
      developer.log('Error loading configuration: $e', name: 'AppConfig', error: e);
      // Fallback to default values
      _url = _defaultSupabaseUrl;
      _anon = _defaultSupabaseAnonKey;
      _googleWebClientId = _defaultGoogleClientId;
      _initialized = true;
    }
  }
}
