import 'package:meta/meta.dart';

/// How settled a single answer in the mission spec is.
///
/// The distinction that matters is [confirmed] versus [proposed]: a value the
/// model inferred during the interview is never allowed to satisfy a required
/// field on its own. Letting it do so is how a hallucinated requirement ends up
/// discovered nine hours into an unattended run.
enum FieldResolution {
  /// Nothing has been said about this yet.
  unresolved,

  /// A value exists but came from the model or a preset and has not been
  /// accepted by the user. Does not satisfy the readiness gate.
  proposed,

  /// The user explicitly accepted this value. Satisfies the readiness gate.
  confirmed,

  /// The user deliberately declined to decide and handed the choice to the
  /// building agent. Satisfies the readiness gate, and is recorded in the
  /// compiled prompt as an authorised assumption.
  waived;

  bool get satisfiesGate =>
      this == FieldResolution.confirmed || this == FieldResolution.waived;
}

/// Where a value came from. Kept separately from [FieldResolution] so that a
/// model-suggested value the user later confirmed still remembers its origin.
enum FieldProvenance { user, model, preset, defaultValue }

/// One answer in the mission spec, carrying its own confidence and history.
@immutable
class SpecField<T> {
  const SpecField({
    this.value,
    this.resolution = FieldResolution.unresolved,
    this.provenance = FieldProvenance.defaultValue,
    this.note,
    this.updatedAt,
  });

  /// An empty field, ready to be filled by the interview.
  const SpecField.empty()
    : value = null,
      resolution = FieldResolution.unresolved,
      provenance = FieldProvenance.defaultValue,
      note = null,
      updatedAt = null;

  final T? value;
  final FieldResolution resolution;
  final FieldProvenance provenance;

  /// For a waived field this is the reason, which the compiler emits so the
  /// agent knows the assumption was authorised rather than invented.
  final String? note;

  final DateTime? updatedAt;

  bool get hasValue => value != null;

  /// True when this field can no longer block compilation.
  bool get isSettled => resolution.satisfiesGate && (hasValue || isWaived);

  bool get isWaived => resolution == FieldResolution.waived;

  /// Record a value the user stated or accepted.
  SpecField<T> confirm(T newValue, {DateTime? at}) => SpecField<T>(
    value: newValue,
    resolution: FieldResolution.confirmed,
    provenance: FieldProvenance.user,
    note: note,
    updatedAt: at ?? DateTime.now().toUtc(),
  );

  /// Record a value the model suggested. Deliberately does *not* satisfy the
  /// readiness gate; it must be promoted by [confirm].
  SpecField<T> propose(
    T newValue, {
    FieldProvenance from = FieldProvenance.model,
    DateTime? at,
  }) => SpecField<T>(
    value: newValue,
    resolution: FieldResolution.proposed,
    provenance: from,
    note: note,
    updatedAt: at ?? DateTime.now().toUtc(),
  );

  /// Hand the decision to the building agent, on the record.
  SpecField<T> waive(String reason, {T? fallback, DateTime? at}) =>
      SpecField<T>(
        value: fallback ?? value,
        resolution: FieldResolution.waived,
        provenance: provenance,
        note: reason,
        updatedAt: at ?? DateTime.now().toUtc(),
      );

  SpecField<T> copyWith({
    T? value,
    FieldResolution? resolution,
    FieldProvenance? provenance,
    String? note,
    DateTime? updatedAt,
  }) => SpecField<T>(
    value: value ?? this.value,
    resolution: resolution ?? this.resolution,
    provenance: provenance ?? this.provenance,
    note: note ?? this.note,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson(Object? Function(T) encode) => <String, Object?>{
    if (value != null) 'value': encode(value as T),
    'resolution': resolution.name,
    'provenance': provenance.name,
    if (note != null) 'note': note,
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  static SpecField<T> fromJson<T>(
    Map<String, Object?>? json,
    T Function(Object?) decode,
  ) {
    if (json == null) return SpecField<T>.empty();
    final Object? raw = json['value'];
    return SpecField<T>(
      value: raw == null ? null : decode(raw),
      resolution: _enumByName(
        FieldResolution.values,
        json['resolution'],
        FieldResolution.unresolved,
      ),
      provenance: _enumByName(
        FieldProvenance.values,
        json['provenance'],
        FieldProvenance.defaultValue,
      ),
      note: json['note'] as String?,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt']! as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SpecField<T> &&
      other.value == value &&
      other.resolution == resolution &&
      other.provenance == provenance &&
      other.note == note;

  @override
  int get hashCode => Object.hash(value, resolution, provenance, note);

  @override
  String toString() => 'SpecField<$T>($value, ${resolution.name})';
}

E _enumByName<E extends Enum>(List<E> values, Object? name, E fallback) {
  for (final E v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
