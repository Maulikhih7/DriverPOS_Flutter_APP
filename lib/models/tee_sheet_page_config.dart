import 'package:flutter/material.dart';

/// Parses the backend page-config JSON for the tee sheet screen.
///
/// Backend shape (GET /api/v1/page/:pageId), screenKey "teeSheet-screen":
/// {
///   "data": {
///     "buttons": [
///       { "key", "label", "bgColor", "borderColor", "textColor", "hoverColor" }
///     ],
///     "search": { "placeholder", "enabled" },
///     "columns": [ { "key", "title" } ]
///   }
/// }
///
/// Note: the doc on the backend has been seen with the screen payload
/// double-wrapped (`data.data`) from an earlier update — [fromJson] unwraps
/// either shape.
class TeeSheetButtonConfig {
  final String key;
  final String label;
  final Color background;
  final Color accent; // shared by borderColor/textColor/hoverColor on the backend

  const TeeSheetButtonConfig({
    required this.key,
    required this.label,
    required this.background,
    required this.accent,
  });
}

class TeeSheetPageConfig {
  final List<TeeSheetButtonConfig> buttons;
  final String searchPlaceholder;
  final bool searchEnabled;
  final String timeColumnTitle;
  final String frontColumnTitle;
  final String backColumnTitle;

  const TeeSheetPageConfig({
    required this.buttons,
    required this.searchPlaceholder,
    required this.searchEnabled,
    required this.timeColumnTitle,
    required this.frontColumnTitle,
    required this.backColumnTitle,
  });

  /// Hard-coded defaults — matches the original hand-coded UI, used on
  /// first paint before the API responds and as a fallback per-field.
  static const TeeSheetPageConfig defaults = TeeSheetPageConfig(
    buttons: [
      TeeSheetButtonConfig(
        key: 'notes',
        label: 'Notes',
        background: Colors.white,
        accent: Color(0xFFF5A623),
      ),
      TeeSheetButtonConfig(
        key: 'toggleBack',
        label: 'Toggle Back',
        background: Colors.white,
        accent: Color(0xFF7B61FF),
      ),
      TeeSheetButtonConfig(
        key: 'sideBySide',
        label: 'Side By Side',
        background: Colors.white,
        accent: Color(0xFF244065),
      ),
    ],
    searchPlaceholder: 'Search here...',
    searchEnabled: true,
    timeColumnTitle: 'Time',
    frontColumnTitle: 'Front',
    backColumnTitle: 'Back',
  );

  factory TeeSheetPageConfig.fromJson(Map<String, dynamic> json) {
    var d = (json['data'] as Map<String, dynamic>?) ?? {};
    // Unwrap an accidental double-nested `data.data` from a past update.
    final nested = d['data'];
    if (nested is Map<String, dynamic> &&
        (nested.containsKey('buttons') ||
            nested.containsKey('search') ||
            nested.containsKey('columns'))) {
      d = nested;
    }

    final def = TeeSheetPageConfig.defaults;

    final rawButtons = d['buttons'];
    final buttons = rawButtons is List && rawButtons.isNotEmpty
        ? rawButtons
            .whereType<Map>()
            .map((b) => _buttonFromJson(Map<String, dynamic>.from(b)))
            .toList()
        : def.buttons;

    final search = (d['search'] as Map<String, dynamic>?) ?? {};

    final rawColumns = d['columns'];
    final columns = rawColumns is List
        ? rawColumns.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList()
        : <Map<String, dynamic>>[];
    final timeCol = columns.firstWhere(
      (c) => c['key'] == 'time',
      orElse: () => const {},
    );
    final frontCol = columns.firstWhere(
      (c) => c['key'] == 'front',
      orElse: () => const {},
    );
    // The backend's "Back" column entry is malformed (`{"back":"back",...}`
    // instead of `{"key":"back",...}`) — match on either shape defensively.
    final backCol = columns.firstWhere(
      (c) => c['key'] == 'back' || c.containsKey('back'),
      orElse: () => const {},
    );

    return TeeSheetPageConfig(
      buttons: buttons,
      searchPlaceholder: _str(search['placeholder'], def.searchPlaceholder),
      searchEnabled: search['enabled'] is bool ? search['enabled'] as bool : def.searchEnabled,
      timeColumnTitle: _str(timeCol['title'], def.timeColumnTitle),
      frontColumnTitle: _str(frontCol['title'], def.frontColumnTitle),
      backColumnTitle: _str(backCol['title'], def.backColumnTitle),
    );
  }

  static TeeSheetButtonConfig _buttonFromJson(Map<String, dynamic> b) {
    final fallback = TeeSheetPageConfig.defaults.buttons.firstWhere(
      (btn) => btn.key == b['key'],
      orElse: () => TeeSheetPageConfig.defaults.buttons.first,
    );
    return TeeSheetButtonConfig(
      key: _str(b['key'], fallback.key),
      label: _str(b['label'], fallback.label),
      background: _color(b['bgColor'], fallback.background),
      accent: _color(b['textColor'] ?? b['borderColor'], fallback.accent),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Color _color(dynamic raw, Color fallback) {
    if (raw is! String) return fallback;
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return fallback;
  }

  static String _str(dynamic raw, String fallback) =>
      raw is String && raw.isNotEmpty ? raw : fallback;
}
