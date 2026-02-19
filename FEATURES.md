# Melody Feature Roadmap

This document tracks all planned features to enhance Melody's music player capabilities, inspired by Namida's feature set.

## 🟢 EASY WINS (Quick Implementation) ✅ COMPLETED

### 1. Enhanced Mini Player
- [x] Horizontal swipe gestures for track navigation
- [x] Double-tap on artwork to toggle play/pause
- [x] Long-press for quick actions menu
- [x] Badge counts on queue button

### 2. Sleep Timer Improvements
- [x] Add track-based timer (stop after X songs)
- [x] Add fade-out when timer ends (gradual volume decrease)
- [x] More preset options (5, 10, 45, 90 minutes)
- [x] Visual countdown with circular progress indicator

### 3. Queue Enhancements
- [x] Tap to jump to any track in queue
- [ ] Reorder tracks with drag-and-drop
- [ ] Remove individual tracks from queue
- [ ] Clear queue button
- [ ] Save queue as playlist

### 4. UI/UX Improvements
- [ ] Animated equalizer bars on play button (when playing)
- [x] Shuffle implementation (complete the existing button)
- [ ] Progress bar improvements - add buffer indicator
- [x] Time remaining display option (toggle between elapsed/remaining)

---

## 🟡 MEDIUM EFFORT (Requires Dedicated Work)

### 5. Real Waveform Visualization
- [ ] Replace simulated waveform with actual audio analysis
- [ ] Use `flutter_audio_waveforms` or similar package
- [ ] Extract amplitude data from audio files
- [ ] Cache waveform data per track

### 6. Advanced Color Extraction
- [ ] Extract more color variations from album art
- [ ] Dynamic text colors (auto black/white based on background luminance)
- [ ] Gradient backgrounds from palette
- [ ] Smooth color transitions between tracks

### 7. Playback Speed Control ✅ COMPLETED
- [x] Add speed button (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
- [x] Integrate with `just_audio` native support
- [ ] Preserve pitch option

### 8. Sleep Timer Actions
- [ ] Different actions: Pause / Stop / Close app
- [ ] Fade out duration setting
- [ ] Gentle wake option (gradual volume increase)

### 9. Track Info Improvements ✅ COMPLETED
- [x] Show bitrate and file format in player
- [x] File size display
- [ ] Download date in track details
- [ ] Audio quality indicator

### 10. Search & Filter
- [ ] Multi-field search (title, artist, album)
- [ ] Filter by duration (short <3min, medium, long >10min)
- [ ] Filter by quality (bitrate ranges)
- [ ] Recent searches history

---

## 🟠 COMPLEX (Significant Refactoring)

### 11. Gapless Playback
- [ ] Buffer management between tracks
- [ ] Pre-load next track while current plays
- [ ] Handle format transitions smoothly
- [ ] Crossfade option (configurable duration)

### 12. Persistent Queue
- [ ] Save queue state to database
- [ ] Restore on app restart
- [ ] Save playback position per track
- [ ] Session history (resume previous sessions)

### 13. Listening History
- [ ] Track every play with timestamp
- [ ] Recently played section
- [ ] Play count per track
- [ ] Most played statistics
- [ ] Listening trends (daily/weekly stats)

### 14. Lyrics Support
- [ ] Display synced lyrics
- [ ] Parse LRC files or fetch from APIs
- [ ] Auto-scroll with playback
- [ ] Full-screen lyrics mode

### 15. Advanced Queue Management
- [ ] Queue from here option (play selected + remaining)
- [ ] Add to queue (next / last)
- [ ] Smart shuffle (avoid recently played)
- [ ] Repeat queue segment

### 16. Audio Normalization
- [ ] Implement ReplayGain
- [ ] Analyze track loudness
- [ ] Adjust playback volume per track
- [ ] Batch processing for downloaded tracks

---

## 🔴 VERY COMPLEX (Major Architecture Changes)

### 17. Equalizer (10-band)
- [ ] Native audio processing integration
- [ ] Use `just_audio` with custom DSP
- [ ] Or integrate `equalizer_flutter`
- [ ] Preset configurations (Rock, Pop, Jazz, etc.)

### 18. Metadata Tag Editor
- [ ] Read/write ID3 tags (MP3)
- [ ] Read/write MP4 metadata
- [ ] Edit: Title, Artist, Album, Genre, Year, Track number
- [ ] Batch editing for multiple files
- [ ] Album art embedding

### 19. Video Player Integration
- [ ] Separate video player widget
- [ ] Support MP4/WebM playback
- [ ] Picture-in-picture mode
- [ ] Fullscreen gestures (swipe for volume/brightness)

### 20. Advanced Library Indexing
- [ ] Scan local device folders
- [ ] Watch folders for changes
- [ ] Folder exclusions
- [ ] Folder tree view
- [ ] Multiple library sources

### 21. Waveform Extraction Library
- [ ] Native integration with Amplituda
- [ ] Extract real waveform from audio binary
- [ ] Cache waveform data efficiently
- [ ] Support all major formats

### 22. Smart Downloads
- [ ] Download queue with priorities
- [ ] Parallel downloads (2-3 concurrent)
- [ ] Pause/resume downloads
- [ ] Wi-Fi only option
- [ ] Auto-download favorites

### 23. Offline Caching
- [ ] Cache streamed audio temporarily
- [ ] Smart cache management (LRU eviction)
- [ ] Cache size limits
- [ ] Prefetch next tracks in queue

### 24. Scrobbling (Last.fm)
- [ ] Track playback events
- [ ] Send to Last.fm API
- [ ] Offline scrobbling (queue when offline)
- [ ] User authentication flow

---

## 🎨 VISUAL/ANIMATION FEATURES

### 25. Micro-Animations
- [ ] Ripple effects on buttons
- [ ] Scale animations on press
- [ ] Slide transitions between pages
- [ ] Staggered animations for lists
- [ ] Skeleton loading screens

### 26. Advanced Mini Player
- [ ] Parallax scrolling with artwork
- [ ] Blur intensity based on scroll position
- [ ] Spring physics for snap animations
- [ ] Haptic feedback on gestures

### 27. Party Mode Enhancements
- [ ] Beat detection from audio (basic)
- [ ] Particle effects overlay
- [ ] Strobe mode (flash screen to beat)
- [ ] Visualizer themes (bars, circle, wave)

### 28. Custom Themes
- [ ] Accent color picker
- [ ] Font size adjustments
- [ ] Layout density (compact/comfortable)
- [ ] Dark mode variants (amoled, dark gray)

---

## ⚙️ SETTINGS & CUSTOMIZATION

### 29. Audio Settings
- [ ] Audio focus handling (pause on calls)
- [ ] Bluetooth auto-play
- [ ] Headset controls
- [ ] Notification actions customization

### 30. Behavior Settings
- [ ] Resume playback on app launch
- [ ] Remember position per track
- [ ] Auto-play on download complete
- [ ] Skip threshold (how much to skip)

### 31. Data & Storage
- [ ] Clear cache option
- [ ] Export/import library
- [ ] Backup playlists
- [ ] Storage usage breakdown

---

## 📱 PLATFORM INTEGRATION

### 32. Android Features
- [ ] Media style notification (expandable)
- [ ] Lock screen controls
- [ ] Android Auto support
- [ ] Quick settings tile
- [ ] App shortcuts (long-press menu)

### 33. iOS Features
- [ ] Control Center integration
- [ ] AirPlay support
- [ ] Siri shortcuts
- [ ] CarPlay support

---

## Implementation Priority

### Phase 1: Quick Wins (1-2 weeks)
- [ ] Sleep timer improvements (#2)
- [ ] Shuffle implementation (#4)
- [ ] Queue tap-to-jump (#3)
- [ ] Playback speed control (#7)
- [ ] Track info display (#9)

### Phase 2: Core Features (3-4 weeks)
- [ ] Real waveform visualization (#5)
- [ ] Persistent queue (#12)
- [ ] Listening history (#13)
- [ ] Enhanced color theming (#6)
- [ ] Search improvements (#10)

### Phase 3: Advanced Features (2-3 months)
- [ ] Gapless playback (#11)
- [ ] Lyrics support (#14)
- [ ] Metadata tag editor (#18)
- [ ] Equalizer (#17)
- [ ] Video player (#19)

### Phase 4: Polish (Ongoing)
- [ ] Micro-animations (#25)
- [ ] Advanced theming (#28)
- [ ] Platform integrations (#32, #33)
- [ ] Performance optimizations

---

## Progress Tracker

**Completed:** 13/33 features

**Current Phase:** Phase 1 Complete - Quick Wins Implemented

**Last Updated:** 2026-02-18

### Completed Features Summary:
- ✅ Sleep timer improvements (track-based, fade-out, more presets, visual countdown)
- ✅ Shuffle implementation with toggle
- ✅ Queue tap-to-jump functionality
- ✅ Playback speed control (0.5x to 2.0x)
- ✅ Track info display (bitrate, format, file size)
- ✅ Time remaining toggle (elapsed vs remaining)
- ✅ Enhanced mini player controls

---

## Notes

- Features are organized by implementation complexity
- Each feature includes implementation hints where applicable
- Check off items as they are completed
- Update progress tracker regularly
- Consider user feedback when prioritizing
