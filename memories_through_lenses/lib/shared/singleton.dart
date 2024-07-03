import 'package:flutter/material.dart';

class Singleton extends ChangeNotifier {
  static Singleton? _instance;

  Singleton._();

  factory Singleton() {
    _instance ??= Singleton._();
    return _instance!;
  }

  Map<String, dynamic> _userData = {
    'name': '',
    'age': 1,
    'friends': {},
    'friend_requests': {},
    'outgoing_requests': {},
  };

  Map<String, dynamic> get userData => _userData;

  void setUserData(Map<String, dynamic> data) {
    _userData = data;
    notifyListeners();
  }
}
