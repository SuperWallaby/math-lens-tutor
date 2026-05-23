import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class AuthSession extends ChangeNotifier {
  AuthSession();

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  static const _linkedStudentsKey = 'linked_students';
  static const _viewAsStudentKey = 'view_as_student_id';

  String? _token;
  AppUser? _user;
  List<LinkedStudent> _linkedStudents = const [];
  String? _viewAsStudentId;

  String? get token => _token;
  AppUser? get user => _user;
  List<LinkedStudent> get linkedStudents => _linkedStudents;
  String? get viewAsStudentId => _viewAsStudentId;

  bool get isSignedIn => _token != null && _token!.isNotEmpty;
  bool get isProfileComplete => _user?.profileComplete ?? false;

  LinkedStudent? get selectedStudent {
    if (_viewAsStudentId == null) return null;
    for (final student in _linkedStudents) {
      if (student.id == _viewAsStudentId) {
        return student;
      }
    }
    return null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null && userJson.isNotEmpty) {
      _user = AppUser.fromJson(
        (jsonDecode(userJson) as Map).cast<String, dynamic>(),
      );
    }
    final linkedJson = prefs.getString(_linkedStudentsKey);
    if (linkedJson != null && linkedJson.isNotEmpty) {
      _linkedStudents = (jsonDecode(linkedJson) as List)
          .whereType<Map>()
          .map((item) => LinkedStudent.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    _viewAsStudentId = prefs.getString(_viewAsStudentKey);
    notifyListeners();
  }

  Future<void> setSession({
    required String token,
    required AppUser user,
    List<LinkedStudent>? linkedStudents,
  }) async {
    _token = token;
    _user = user;
    if (linkedStudents != null) {
      _linkedStudents = linkedStudents;
      if (_viewAsStudentId != null &&
          !_linkedStudents.any((s) => s.id == _viewAsStudentId)) {
        _viewAsStudentId = _linkedStudents.isNotEmpty
            ? _linkedStudents.first.id
            : null;
      } else if (_viewAsStudentId == null && _linkedStudents.isNotEmpty) {
        _viewAsStudentId = _linkedStudents.first.id;
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateUser(AppUser user, {List<LinkedStudent>? linkedStudents}) async {
    _user = user;
    if (linkedStudents != null) {
      _linkedStudents = linkedStudents;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setLinkedStudents(List<LinkedStudent> students) async {
    _linkedStudents = students;
    if (_viewAsStudentId != null &&
        !students.any((student) => student.id == _viewAsStudentId)) {
      _viewAsStudentId = students.isNotEmpty ? students.first.id : null;
    } else if (_viewAsStudentId == null && students.isNotEmpty) {
      _viewAsStudentId = students.first.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setViewAsStudentId(String? studentId) async {
    _viewAsStudentId = studentId;
    final prefs = await SharedPreferences.getInstance();
    if (studentId == null) {
      await prefs.remove(_viewAsStudentKey);
    } else {
      await prefs.setString(_viewAsStudentKey, studentId);
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    _linkedStudents = const [];
    _viewAsStudentId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_linkedStudentsKey);
    await prefs.remove(_viewAsStudentKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_tokenKey, _token!);
    }
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    }
    await prefs.setString(
      _linkedStudentsKey,
      jsonEncode(_linkedStudents.map((s) => s.toJson()).toList()),
    );
    if (_viewAsStudentId != null) {
      await prefs.setString(_viewAsStudentKey, _viewAsStudentId!);
    }
  }
}
