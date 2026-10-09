import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/sumi_themes.dart';
import 'sumi_widgets.dart';

/// Rename dialog for the profile name.
///
/// The name commits whenever the text field loses focus — not just on
/// keyboard-done or the Save button. So tapping elsewhere, dismissing the
/// keyboard, or tapping outside the dialog all persist the rename.
/// Cancel explicitly restores the original name (discard).
class NameEditDialog extends StatefulWidget {
  final SumiThemeDef theme;
  final SudoSettings settings;
  final SumiAudio audio;
  final String? hintText;
  const NameEditDialog({
    super.key,
    required this.theme,
    required this.settings,
    required this.audio,
    this.hintText,
  });

  @override
  State<NameEditDialog> createState() => _NameEditDialogState();
}

class _NameEditDialogState extends State<NameEditDialog> {
  late final TextEditingController _ctrl;
  late final FocusNode _node;
  late final String _original;

  @override
  void initState() {
    super.initState();
    _original = widget.settings.profileName;
    _ctrl = TextEditingController(text: _original);
    _node = FocusNode();
    _node.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Focus lost (tap elsewhere, keyboard dismissed, dialog barrier
    // dismissed): commit the rename instead of dropping it.
    if (!_node.hasFocus) {
      widget.settings.setProfileName(_ctrl.text);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _node.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _saveAndClose() {
    widget.settings.setProfileName(_ctrl.text);
    widget.audio.click();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AlertDialog(
      backgroundColor: theme.washi,
      title: Text('Your name', style: SumiType.display(20, theme)),
      content: TextField(
        controller: _ctrl,
        focusNode: _node,
        maxLength: 16,
        autofocus: true,
        style: SumiType.body(17, theme),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: SumiType.body(15, theme,
              color: theme.walnut.withValues(alpha: 0.5)),
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.bamboo)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.vermilion, width: 2)),
        ),
        onSubmitted: (_) => _saveAndClose(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Discard: restore the pre-edit name, then close.
            widget.settings.setProfileName(_original);
            Navigator.of(context).pop();
          },
          child: Text('Cancel', style: SumiType.label(13, theme)),
        ),
        TextButton(
          onPressed: _saveAndClose,
          child: Text('Save', style: SumiType.label(13, theme)),
        ),
      ],
    );
  }
}
