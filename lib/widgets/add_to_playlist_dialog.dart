import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../services/database_service.dart';

class AddToPlaylistDialog extends StatefulWidget {
  final String trackId;

  const AddToPlaylistDialog({super.key, required this.trackId});

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final _dbService = DatabaseService.instance;
  List<Playlist> _playlists = [];
  Set<String> _selectedPlaylists = {};
  Set<String> _initiallyInPlaylists = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await _dbService.getAllPlaylists();
      final trackPlaylists = await _dbService.getPlaylistsForTrack(
        widget.trackId,
      );

      if (mounted) {
        setState(() {
          _playlists = playlists;
          _selectedPlaylists = Set.from(trackPlaylists);
          _initiallyInPlaylists = Set.from(trackPlaylists);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading playlists: $e')));
      }
    }
  }

  Future<void> _saveChanges() async {
    try {
      // Add to newly selected playlists
      for (final playlistId in _selectedPlaylists) {
        if (!_initiallyInPlaylists.contains(playlistId)) {
          await _dbService.addTrackToPlaylist(playlistId, widget.trackId);
        }
      }

      // Remove from unselected playlists
      for (final playlistId in _initiallyInPlaylists) {
        if (!_selectedPlaylists.contains(playlistId)) {
          await _dbService.removeTrackFromPlaylist(playlistId, widget.trackId);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Playlist'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _playlists.isEmpty
            ? const Center(
                child: Text(
                  'No playlists yet.\nCreate one first!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  final isSelected = _selectedPlaylists.contains(playlist.id);

                  return CheckboxListTile(
                    title: Text(playlist.name),
                    subtitle: Text(
                      '${playlist.trackCount ?? 0} ${(playlist.trackCount ?? 0) == 1 ? 'song' : 'songs'}',
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedPlaylists.add(playlist.id);
                        } else {
                          _selectedPlaylists.remove(playlist.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _playlists.isEmpty ? null : _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
