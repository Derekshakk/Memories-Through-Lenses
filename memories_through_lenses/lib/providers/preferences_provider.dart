import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feed ordering on the home screen.
enum FeedSort { recent, popular }

/// Device-local display preferences (text size, feed ordering).
///
/// Values are read once before runApp so the first frame already reflects
/// them; writes are fire-and-forget and never block the UI.
class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider({
    SharedPreferences? prefs,
    double textScale = defaultTextScale,
    FeedSort feedSort = FeedSort.popular,
  })  : _prefs = prefs,
        _textScale = _clampScale(textScale),
        _feedSort = feedSort;

  static const String textScaleKey = 'textScale';
  static const String feedSortKey = 'feedSort';

  /// 1.0 keeps the current design (the user's system text size still applies
  /// on top of this).
  static const double defaultTextScale = 1.0;

  /// Selectable sizes. Kept modest at the top end: much of the layout uses
  /// fixed-height rows sized for the default text.
  static const List<(double, String)> textScaleOptions = [
    (0.9, 'Small'),
    (1.0, 'Default'),
    (1.15, 'Large'),
    (1.3, 'Extra Large'),
  ];

  final SharedPreferences? _prefs;
  double _textScale;
  FeedSort _feedSort;

  double get textScale => _textScale;
  FeedSort get feedSort => _feedSort;

  static Future<PreferencesProvider> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return PreferencesProvider(
        prefs: prefs,
        textScale: prefs.getDouble(textScaleKey) ?? defaultTextScale,
        feedSort: _parseSort(prefs.getString(feedSortKey)),
      );
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      return PreferencesProvider();
    }
  }

  static FeedSort _parseSort(String? raw) => FeedSort.values
      .firstWhere((s) => s.name == raw, orElse: () => FeedSort.popular);

  static double _clampScale(double value) {
    if (!value.isFinite) return defaultTextScale;
    return value.clamp(0.9, 1.3).toDouble();
  }

  Future<void> setTextScale(double value) async {
    final next = _clampScale(value);
    if (next == _textScale) return;
    _textScale = next;
    notifyListeners();
    await _write((p) => p.setDouble(textScaleKey, next));
  }

  Future<void> setFeedSort(FeedSort value) async {
    if (value == _feedSort) return;
    _feedSort = value;
    notifyListeners();
    await _write((p) => p.setString(feedSortKey, value.name));
  }

  Future<void> _write(Future<bool> Function(SharedPreferences) op) async {
    try {
      await op(_prefs ?? await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  /// Applies the chosen size on top of the system text scale. Installed in
  /// MaterialApp.builder so every route and dialog inherits it.
  Widget applyTextScale(BuildContext context, Widget child) {
    if (_textScale == defaultTextScale) return child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _ScaledTextScaler(media.textScaler, _textScale),
      ),
      child: child,
    );
  }
}

class _ScaledTextScaler extends TextScaler {
  const _ScaledTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _ScaledTextScaler &&
      other.base == base &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
