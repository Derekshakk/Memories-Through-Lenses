/// Username rules shared by registration, profile editing and display.
///
/// Older accounts may already hold names longer than [maxLength] (there was
/// no limit at registration before). Those names are never rewritten in
/// Firestore; [displayName] truncates them for the UI only.
class Username {
  static const int maxLength = 30;

  /// Hard cap for anything rendered from user-controlled name data. Keeps
  /// layout bounded even if a client bypassed validation.
  static const int maxDisplayLength = maxLength;

  /// Returns an error message, or null when [name] is acceptable.
  ///
  /// [previous] is the user's current stored name. Re-saving an unchanged
  /// legacy name that predates the limit is allowed so those users can still
  /// update their photo without being forced to rename.
  static String? validate(String name, {String? previous}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Username cannot be empty';
    if (previous != null && trimmed == previous.trim()) return null;
    if (trimmed.runes.length > maxLength) {
      return 'Username cannot exceed $maxLength characters';
    }
    return null;
  }

  /// Collapses whitespace/newlines and truncates to [maxDisplayLength]
  /// characters (by Unicode code point, so emoji are never split in half).
  static String displayName(Object? raw, {String fallback = 'Unknown User'}) {
    if (raw is! String) return fallback;
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return fallback;
    final runes = collapsed.runes;
    if (runes.length <= maxDisplayLength) return collapsed;
    return '${String.fromCharCodes(runes.take(maxDisplayLength)).trimRight()}…';
  }
}
