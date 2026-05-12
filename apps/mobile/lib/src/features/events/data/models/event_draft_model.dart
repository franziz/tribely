import '../../domain/entities/event_category.dart';
import '../../domain/entities/event_draft.dart';

/// JSON ⇄ [EventDraft] conversion model for draft persistence.
///
/// Schema versioning: [toJson] always writes `schemaVersion: 1`. [fromJson]
/// rejects any snapshot whose `schemaVersion` does not equal 1 by returning
/// `null`, preventing stale/incompatible data from reaching the domain.
class EventDraftModel {
  const EventDraftModel({
    required this.schemaVersion,
    this.title,
    this.category,
    this.venueName,
    this.latitude,
    this.longitude,
    this.startsAt,
    this.endsAt,
    this.capacity,
    this.costNotes,
    this.approvalMode,
    this.description,
    required this.currentStep,
    required this.lastUpdatedAt,
  });

  factory EventDraftModel.fromEntity(EventDraft entity) {
    return EventDraftModel(
      schemaVersion: _currentSchemaVersion,
      title: entity.title,
      category: entity.category?.wireValue,
      venueName: entity.venueName,
      latitude: entity.latitude,
      longitude: entity.longitude,
      startsAt: entity.startsAt?.toIso8601String(),
      endsAt: entity.endsAt?.toIso8601String(),
      capacity: entity.capacity,
      costNotes: entity.costNotes,
      approvalMode: entity.approvalMode,
      description: entity.description,
      currentStep: entity.currentStep,
      lastUpdatedAt:
          (entity.lastUpdatedAt ?? DateTime.now()).toIso8601String(),
    );
  }

  /// Returns `null` when `schemaVersion` does not match [_currentSchemaVersion].
  /// Callers should treat null as "no draft" and log accordingly.
  static EventDraftModel? fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != _currentSchemaVersion) {
      return null;
    }

    final currentStep = json['currentStep'];
    final lastUpdatedAt = json['lastUpdatedAt'];
    if (currentStep is! int || lastUpdatedAt is! String) {
      return null;
    }

    return EventDraftModel(
      schemaVersion: version as int,
      title: json['title'] as String?,
      category: json['category'] as String?,
      venueName: json['venueName'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startsAt: json['startsAt'] as String?,
      endsAt: json['endsAt'] as String?,
      capacity: json['capacity'] as int?,
      costNotes: json['costNotes'] as String?,
      approvalMode: json['approvalMode'] as String?,
      description: json['description'] as String?,
      currentStep: currentStep,
      lastUpdatedAt: lastUpdatedAt,
    );
  }

  static const int _currentSchemaVersion = 1;

  final int schemaVersion;
  final String? title;
  final String? category;
  final String? venueName;
  final double? latitude;
  final double? longitude;
  final String? startsAt;
  final String? endsAt;
  final int? capacity;
  final String? costNotes;
  final String? approvalMode;
  final String? description;
  final int currentStep;
  final String lastUpdatedAt;

  EventDraft toEntity() {
    return EventDraft(
      title: title,
      category: category != null ? EventCategory.fromWire(category!) : null,
      venueName: venueName,
      latitude: latitude,
      longitude: longitude,
      startsAt: startsAt != null ? DateTime.tryParse(startsAt!) : null,
      endsAt: endsAt != null ? DateTime.tryParse(endsAt!) : null,
      capacity: capacity,
      costNotes: costNotes,
      approvalMode: approvalMode,
      description: description,
      currentStep: currentStep,
      lastUpdatedAt: DateTime.tryParse(lastUpdatedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (venueName != null) 'venueName': venueName,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (startsAt != null) 'startsAt': startsAt,
      if (endsAt != null) 'endsAt': endsAt,
      if (capacity != null) 'capacity': capacity,
      if (costNotes != null) 'costNotes': costNotes,
      if (approvalMode != null) 'approvalMode': approvalMode,
      if (description != null) 'description': description,
      'currentStep': currentStep,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
}
