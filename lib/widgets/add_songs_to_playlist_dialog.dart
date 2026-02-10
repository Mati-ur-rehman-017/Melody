import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/database_service.dart';

class AddSongsToPlaylistDialog extends StatefulWidget {
  final String playlistId;

  const AddSongsToPlaylistDialog({super.key, required this.playlistId});

  @override
  State<AddSongsToPlaylistDialog> createState() =>
      _AddSongsToPlaylistDialogState();
}

class _AddSongsToPlaylistDialogState extends State<AddSongsToPlaylistDialog> {
  final _dbService = DatabaseService.instance;
  final _searchController = TextEditingController();

  List<Track> _allAvailableTracks = [];
  List<Track> _filteredTracks = [];
  final Set<String> _selectedTrackIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableTracks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTracks() async {
    try {
      final tracks = await _dbService.getTracksNotInPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _allAvailableTracks = tracks;
          _filteredTracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTracks = List.from(_allAvailableTracks);
      } else {
        _filteredTracks = _allAvailableTracks.where((track) {
          return track.title.toLowerCase().contains(query) ||
              track.author.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _addSelectedSongs() async {
    try {
      for (final trackId in _selectedTrackIds) {
        await _dbService.addTrackToPlaylist(widget.playlistId, trackId);
      }
      if (mounted) {
        Navigator.pop(context, _selectedTrackIds.length);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding songs: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedTrackIds.length;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Add Songs to Playlist',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search songs...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Track count
              Text(
                '${_filteredTracks.length} ${_filteredTracks.length == 1 ? 'song' : 'songs'} available',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),

              // Track list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTracks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _allAvailableTracks.isEmpty
                                  ? 'All songs are already in this playlist'
                                  : 'No songs match your search',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredTracks.length,
                        itemBuilder: (context, index) {
                          final track = _filteredTracks[index];
                          final isSelected = _selectedTrackIds.contains(
                            track.id,
                          );

                          return CheckboxListTile(
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: const Icon(Icons.music_note),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedTrackIds.add(track.id);
                                } else {
                                  _selectedTrackIds.remove(track.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Selected count and buttons
              Row(
                children: [
                  Text(
                    '$selectedCount selected',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: selectedCount > 0 ? _addSelectedSongs : null,
                    child: Text(
                      selectedCount > 0
                          ? 'Add $selectedCount ${selectedCount == 1 ? 'Song' : 'Songs'}'
                          : 'Add Songs',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
