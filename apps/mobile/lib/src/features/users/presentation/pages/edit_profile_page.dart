import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/users_providers.dart';
import '../state/edit_profile_state.dart';
import '../widgets/profile_picklists.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late List<String> _selectedLanguages;
  late List<String> _selectedInterests;
  String? _selectedTravelerType;
  bool _seeded = false;

  @override
  void dispose() {
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _seed(UserProfile profile) {
    if (_seeded) return;
    _seeded = true;
    _bioController.text = profile.bio ?? '';
    _cityController.text = profile.currentCity ?? '';
    _selectedLanguages = List<String>.from(profile.languages);
    _selectedInterests = List<String>.from(profile.interests);
    _selectedTravelerType = profile.travelerType;
  }

  Future<void> _save() async {
    final bio = _bioController.text.trim();
    final city = _cityController.text.trim();
    await ref
        .read(editProfileControllerProvider.notifier)
        .save(
          bio: bio.isEmpty ? null : bio,
          currentCity: city.isEmpty ? null : city,
          languages: _selectedLanguages,
          interests: _selectedInterests,
          travelerType: _selectedTravelerType,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Declarative side-effect: pop on save success, surface error UI on
    // failure. The controller is decoupled from navigation entirely.
    ref.listen<EditProfileState>(editProfileControllerProvider, (prev, next) {
      if (next is EditProfileSaved) {
        // Invalidate own profile so /profile refetches on return.
        ref.invalidate(myProfileControllerProvider);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      }
      // Error is already rendered via bannerMessage in the form body;
      // no additional navigation needed here.
    });
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final state = ref.watch(editProfileControllerProvider);

    final profile = switch (state) {
      EditProfileIdle(:final profile) => profile,
      EditProfileSaving(:final profile) => profile,
      EditProfileSaved(:final profile) => profile,
      EditProfileError(:final profile) => profile,
    };

    _seed(profile);

    final isSaving = state is EditProfileSaving;
    final fieldErrors = state is EditProfileError
        ? state.fieldErrors
        : <String, String>{};
    final bannerMessage = state is EditProfileError ? state.message : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit profile', style: TribelyType.headline(ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/profile');
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Save',
                      style: TribelyType.button(
                        dark
                            ? TribelyColors.nightPrimary
                            : TribelyColors.paperPrimary,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            if (bannerMessage != null)
              _ErrorBanner(message: bannerMessage, inkSecondary: inkSecondary),
            _FieldLabel('Bio', inkSecondary),
            const SizedBox(height: 6),
            TextFormField(
              controller: _bioController,
              enabled: !isSaving,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: 'Tell others a bit about yourself',
                errorText: fieldErrors['bio'],
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel('City', inkSecondary),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cityController,
              enabled: !isSaving,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'Where are you based?',
                errorText: fieldErrors['currentCity'],
              ),
            ),
            const SizedBox(height: 20),
            _FieldLabel('Currently', inkSecondary),
            const SizedBox(height: 6),
            _TravelerTypeSelector(
              selected: _selectedTravelerType,
              enabled: !isSaving,
              onChanged: (value) =>
                  setState(() => _selectedTravelerType = value),
            ),
            const SizedBox(height: 20),
            _FieldLabel('Languages', inkSecondary),
            if (fieldErrors['languages'] != null)
              _InlineError(fieldErrors['languages']!),
            const SizedBox(height: 6),
            _MultiSelectList(
              items: kLanguageLabels,
              selected: _selectedLanguages,
              enabled: !isSaving,
              onChanged: (updated) =>
                  setState(() => _selectedLanguages = updated),
            ),
            const SizedBox(height: 20),
            _FieldLabel('Interests', inkSecondary),
            if (fieldErrors['interests'] != null)
              _InlineError(fieldErrors['interests']!),
            const SizedBox(height: 6),
            _MultiSelectList(
              items: kInterestLabels,
              selected: _selectedInterests,
              enabled: !isSaving,
              onChanged: (updated) =>
                  setState(() => _selectedInterests = updated),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(label.toUpperCase(), style: TribelyType.caption(color));
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      message,
      style: TribelyType.caption(Theme.of(context).colorScheme.error),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.inkSecondary});
  final String message;
  final Color inkSecondary;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? TribelyColors.nightAccentSoft
            : TribelyColors.paperAccentSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TribelyType.bodyM(inkSecondary)),
    );
  }
}

class _TravelerTypeSelector extends StatelessWidget {
  const _TravelerTypeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: kTravelerTypeLabels.entries.map((entry) {
        final isSelected = selected == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: enabled
              ? (_) => onChanged(isSelected ? null : entry.key)
              : null,
        );
      }).toList(),
    );
  }
}

class _MultiSelectList extends StatelessWidget {
  const _MultiSelectList({
    required this.items,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final Map<String, String> items;
  final List<String> selected;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.entries.map((entry) {
        return CheckboxListTile(
          dense: true,
          title: Text(entry.value),
          value: selected.contains(entry.key),
          enabled: enabled,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (_) {
            final updated = List<String>.from(selected);
            if (updated.contains(entry.key)) {
              updated.remove(entry.key);
            } else {
              updated.add(entry.key);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
