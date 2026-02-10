import 'package:flutter/material.dart';

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({super.key});

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Playlist'),
      content: TextField(
        controller: _textController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          border: OutlineInputBorder(),
        ),
        maxLength: 50,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.pop(context, value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _textController.text.trim();
            if (name.isNotEmpty) {
              Navigator.pop(context, name);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
