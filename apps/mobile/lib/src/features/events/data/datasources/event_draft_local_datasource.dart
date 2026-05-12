import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_draft_model.dart';

/// Contract for local persistence of an in-progress event draft.
abstract class EventDraftLocalDatasource {
  /// Loads the persisted draft snapshot, or `null` when none exists or the
  /// stored data is corrupt / schema-version mismatched.
  Future<EventDraftModel?> load();

  /// Serialises [draft] and writes it to local storage.
  Future<void> save(EventDraftModel draft);

  /// Removes the persisted draft snapshot, if any.
  Future<void> clear();
}

/// [SharedPreferences]-backed implementation of [EventDraftLocalDatasource].
///
/// A single JSON snapshot is stored under [_key]. The resolved
/// [SharedPreferences] instance is injected via the constructor — callers
/// (DI registration in Brief 7) must await `SharedPreferences.getInstance()`
/// once at boot and pass it in. Never call `getInstance()` per method.
class EventDraftLocalDatasourceImpl implements EventDraftLocalDatasource {
  EventDraftLocalDatasourceImpl(this._prefs);

  final SharedPreferences _prefs;

  /// Versioned key — bump the suffix (e.g., `event_draft.v2`) together with a
  /// new [EventDraftModel._currentSchemaVersion] when the schema changes
  /// incompatibly, so stale v1 snapshots are automatically ignored on upgrade.
  static const _key = 'event_draft.v1';

  @override
  Future<EventDraftModel?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final model = EventDraftModel.fromJson(json);
      if (model == null) {
        log(
          'event_draft_local_datasource: schema version mismatch — '
          'treating as no draft',
          name: 'EventDraftLocalDatasource',
        );
      }
      return model;
    } catch (e, st) {
      // Corrupt draft — log and treat as no draft. Never brick the create flow.
      log(
        'event_draft_local_datasource: failed to load draft, treating as no draft',
        error: e,
        stackTrace: st,
        name: 'EventDraftLocalDatasource',
      );
      return null;
    }
  }

  @override
  Future<void> save(EventDraftModel draft) async {
    await _prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
