import 'package:flutter/material.dart';

enum ProfileEmptyFieldType { bio, languages, interests, city }

/// Displays PM-locked empty-state copy for a profile field.
/// All empty-state strings are defined here — do not inline them in other widgets.
class ProfileEmptyField extends StatelessWidget {
  const ProfileEmptyField({required this.type, super.key});

  final ProfileEmptyFieldType type;

  @override
  Widget build(BuildContext context) {
    return Text(
      _copy(type),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  static String _copy(ProfileEmptyFieldType type) => switch (type) {
    ProfileEmptyFieldType.bio => 'No bio yet',
    ProfileEmptyFieldType.languages => 'No languages set',
    ProfileEmptyFieldType.interests => 'No interests set',
    ProfileEmptyFieldType.city => 'No city set',
  };
}
