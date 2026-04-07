import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../config/constants.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  UserModel? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.authTokenKey);
    final userJson = prefs.getString(AppConstants.userDataKey);
    if (userJson != null) {
      _user = UserModel.fromJson(jsonDecode(userJson));
    }
    if (_token != null) ApiService.setToken(_token!);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await ApiService.login(email, password);
      await _saveAuth(result);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup(String email, String password, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await ApiService.signup(email, password, name);
      await _saveAuth(result);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await ApiService.forgotPassword(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userDataKey);
    _token = null;
    _user = null;
    ApiService.clearToken();
    notifyListeners();
  }

  Future<void> _saveAuth(Map<String, dynamic> result) async {
    _token = result['token'] as String;
    _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.authTokenKey, _token!);
    await prefs.setString(AppConstants.userDataKey, jsonEncode(_user!.toJson()));
    ApiService.setToken(_token!);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
