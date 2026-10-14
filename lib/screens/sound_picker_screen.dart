import 'package:flutter/material.dart';

import '../models/sound_option.dart';
import '../providers/alarm_provider.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_motion.dart';
import '../theme/nothing_typography.dart';
import '../widgets/nothing_ui.dart';

/// What the user chose. [uri] null means "use the device default alarm sound".
class SoundPickerResult {
  const SoundPickerResult({
    required this.uri,
    required this.displayName,
    this.startPosition = 0.0,
    this.endPosition = 1.0,
    this.volume = 1.0,
  });

  final String? uri;
  final String displayName;
  final double startPosition; // 0.0 to 1.0
  final double endPosition; // 0.0 to 1.0
  final double volume; // 0.0 to 1.0
}

class SoundPickerScreen extends StatefulWidget {
  const SoundPickerScreen({
    super.key,
    required this.provider,
    this.selectedUri,
    this.initialVolume = 1.0,
    this.initialStartPosition = 0.0,
    this.initialEndPosition = 1.0,
  });

  final AlarmProvider provider;
  final String? selectedUri;
  final double initialVolume;
  final double initialStartPosition;
  final double initialEndPosition;

  @override
  State<SoundPickerScreen> createState() => _SoundPickerScreenState();
}

class _SoundPickerScreenState extends State<SoundPickerScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();

  List<SoundOption> _sounds = const [];
  bool _loading = true;
  Object? _error;

  String _query = '';
  SoundSort _sort = SoundSort.nameAsc;
  SoundKind? _kindFilter;
  String? _previewingUri;
  bool _isPlaying = false;

  // Playback controls for selected sound
  double _volume = 1.0;
  double _startPosition = 0.0;
  double _endPosition = 1.0;
  double _currentPlaybackPosition = 0.0;

  late final AnimationController _playbackAnimController;

  @override
  void initState() {
    super.initState();
    _volume = widget.initialVolume;
    _startPosition = widget.initialStartPosition;
    _endPosition = widget.initialEndPosition;
    _playbackAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // Will be updated per sound
    );
    _playbackAnimController.addListener(_updatePlaybackPosition);
    _load();
  }

  void _updatePlaybackPosition() {
    if (_isPlaying) {
      setState(() {
        _currentPlaybackPosition = _startPosition +
            (_endPosition - _startPosition) * _playbackAnimController.value;
      });
    }
  }

  @override
  void dispose() {
    widget.provider.stopSoundPreview();
    _searchController.dispose();
    _playbackAnimController.removeListener(_updatePlaybackPosition);
    _playbackAnimController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Don't set loading to true again if we already have sounds
    // This allows showing cached data while refreshing
    if (_sounds.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sounds = await widget.provider.listSounds();
      if (!mounted) return;
      setState(() {
        _sounds = sounds;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<SoundOption> get _visibleSounds {
    final query = _query.trim().toLowerCase();
    final filtered = _sounds.where((sound) {
      if (_kindFilter != null && sound.kind != _kindFilter) return false;
      if (query.isEmpty) return true;
      return sound.title.toLowerCase().contains(query);
    }).toList();

    switch (_sort) {
      case SoundSort.nameAsc:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case SoundSort.nameDesc:
        filtered.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
      case SoundSort.kind:
        filtered.sort((a, b) {
          final byKind = a.kind.index.compareTo(b.kind.index);
          if (byKind != 0) return byKind;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
    }
    return filtered;
  }

  Future<void> _togglePreview(SoundOption sound) async {
    if (_previewingUri == sound.uri && _isPlaying) {
      await _stopPreview();
      return;
    }

    // Stop any existing preview
    if (_previewingUri != null) {
      await widget.provider.stopSoundPreview();
    }

    await widget.provider.previewSound(sound.uri, volume: _volume);
    if (!mounted) return;

    setState(() {
      _previewingUri = sound.uri;
      _isPlaying = true;
      _currentPlaybackPosition = _startPosition;
    });

    _playbackAnimController.forward(from: 0);
  }

  Future<void> _stopPreview() async {
    await widget.provider.stopSoundPreview();
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
    });
    _playbackAnimController.stop();
    _playbackAnimController.reset();
  }

  void _choose(SoundPickerResult result) {
    widget.provider.stopSoundPreview();
    Navigator.of(context).pop(result);
  }

  Future<void> _browseFiles() async {
    final picked = await widget.provider.pickSound();
    if (picked == null || !mounted) return;
    _choose(SoundPickerResult(
      uri: picked.$1,
      displayName: picked.$2,
      volume: _volume,
      startPosition: _startPosition,
      endPosition: _endPosition,
    ));
  }

  void _selectSound(SoundOption? sound) {
    _choose(SoundPickerResult(
      uri: sound?.uri,
      displayName: sound?.title ?? 'Default',
      volume: _volume,
      startPosition: _startPosition,
      endPosition: _endPosition,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOUND'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: NothingCircleButton(
              icon: Icons.folder_open,
              tooltip: 'Browse files',
              onPressed: _browseFiles,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar - always visible
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search sounds',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter chips - always visible
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                NothingChoicePill(
                  label: 'ALL',
                  selected: _kindFilter == null,
                  onTap: () => setState(() => _kindFilter = null),
                ),
                for (final kind in SoundKind.values) ...[
                  const SizedBox(width: 8),
                  NothingChoicePill(
                    label: soundKindLabel(kind).toUpperCase(),
                    selected: _kindFilter == kind,
                    onTap: () => setState(() => _kindFilter = kind),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Section header - always visible
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: NothingSectionLabel(
                    'Library',
                    trailing: _loading
                        ? 'Loading...'
                        : '${_visibleSounds.length} shown',
                  ),
                ),
                const SizedBox(width: 10),
                _SortButton(
                  sort: _sort,
                  onChanged: (sort) => setState(() => _sort = sort),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Content area
          Expanded(child: _buildBody()),

          // Playback controls panel - shown when a sound is being previewed
          if (_previewingUri != null) _buildPlaybackControls(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Show skeleton while loading
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Default option skeleton
          NothingEntrance(
            index: 0,
            child: const NothingSkeletonPanel(height: 56, lines: 1),
          ),
          const SizedBox(height: 10),
          // Sound list skeletons
          for (var i = 1; i < 8; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NothingEntrance(
                index: i,
                child: const NothingSkeletonPanel(height: 56, lines: 1),
              ),
            ),
        ],
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: NothingPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NothingSectionLabel('Load failed'),
                const SizedBox(height: 14),
                Text(
                  'The device sound list could not be read. You can still pick '
                  'a file manually.',
                  style: NothingTypography.bodyMedium.copyWith(
                    color: NothingColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('RETRY'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final visible = _visibleSounds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        NothingEntrance(
          index: 0,
          child: _SoundRow(
            title: 'Default alarm sound',
            subtitle: 'Follows the device setting',
            selected: widget.selectedUri == null,
            onSelect: () => _selectSound(null),
          ),
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          NothingEntrance(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: NothingPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
                child: Column(
                  children: [
                    Text(
                      'NO MATCHES',
                      style: NothingTypography.labelLarge.copyWith(
                        color: NothingColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try a different search term or filter.',
                      textAlign: TextAlign.center,
                      style: NothingTypography.bodySmall.copyWith(
                        color: NothingColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NothingEntrance(
                index: i + 1,
                child: _SoundRow(
                  title: visible[i].title,
                  subtitle: soundKindLabel(visible[i].kind),
                  selected: widget.selectedUri == visible[i].uri,
                  playing: _previewingUri == visible[i].uri && _isPlaying,
                  onPreview: () => _togglePreview(visible[i]),
                  onSelect: () => _selectSound(visible[i]),
                ),
              ),
            ),
        // Add padding for playback controls
        if (_previewingUri != null) const SizedBox(height: 180),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    final sound = _sounds.firstWhere(
      (s) => s.uri == _previewingUri,
      orElse: () => SoundOption(
        uri: _previewingUri!,
        title: 'Custom',
        kind: SoundKind.alarm,
      ),
    );

    return AnimatedContainer(
      duration: NothingMotion.standard,
      curve: NothingMotion.curve,
      decoration: BoxDecoration(
        color: NothingColors.surface,
        border: const Border(
          top: BorderSide(color: NothingColors.outline),
        ),
        boxShadow: [
          BoxShadow(
            color: NothingColors.ink.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sound title and play/stop button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sound.title,
                          style: NothingTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PREVIEWING',
                          style: NothingTypography.labelSmall.copyWith(
                            color: NothingColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NothingCircleButton(
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    tooltip: _isPlaying ? 'Stop' : 'Play',
                    onPressed: () {
                      if (_isPlaying) {
                        _stopPreview();
                      } else {
                        _togglePreview(sound);
                      }
                    },
                    filled: true,
                    danger: _isPlaying,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Range selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SECTION',
                        style: NothingTypography.labelSmall.copyWith(
                          color: NothingColors.inkMuted,
                        ),
                      ),
                      Text(
                        '${(_startPosition * 100).toInt()}% - ${(_endPosition * 100).toInt()}%',
                        style: NothingTypography.labelSmall.copyWith(
                          color: NothingColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RangeSliderWidget(
                    start: _startPosition,
                    end: _endPosition,
                    currentPosition:
                        _isPlaying ? _currentPlaybackPosition : null,
                    onChanged: (start, end) {
                      setState(() {
                        _startPosition = start;
                        _endPosition = end;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Volume slider
              Row(
                children: [
                  Icon(
                    _volume == 0
                        ? Icons.volume_off
                        : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                    size: 18,
                    color: NothingColors.inkMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: NothingColors.red,
                        inactiveTrackColor: NothingColors.outline,
                        thumbColor: NothingColors.red,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                      ),
                      child: Slider(
                        value: _volume,
                        onChanged: (value) async {
                          setState(() => _volume = value);
                          // Update preview volume if playing
                          if (_isPlaying) {
                            await widget.provider
                                .setPreviewVolume(_volume);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(_volume * 100).toInt()}%',
                      style: NothingTypography.labelSmall.copyWith(
                        color: NothingColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Select button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _selectSound(sound),
                  child: const Text('USE THIS SOUND'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onSelect,
    this.onPreview,
    this.playing = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback? onPreview;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final primary = selected ? NothingColors.white : NothingColors.ink;
    final secondary = selected ? NothingColors.outline : NothingColors.inkMuted;

    return NothingPanel(
      color: selected ? NothingColors.ink : NothingColors.surface,
      borderColor: selected ? null : NothingColors.outline,
      onTap: onSelect,
      onTapSemanticLabel: 'Use $title',
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: NothingTypography.titleMedium.copyWith(color: primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle.toUpperCase(),
                  style: NothingTypography.labelSmall.copyWith(
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: NothingStatusPill(
                'IN USE',
                tone: NothingTone.active,
                onDark: true,
              ),
            ),
          if (onPreview != null)
            NothingCircleButton(
              icon: playing ? Icons.stop : Icons.play_arrow,
              tooltip: playing ? 'Stop preview' : 'Preview $title',
              onPressed: onPreview,
              onDark: selected,
              danger: playing,
            ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final SoundSort sort;
  final ValueChanged<SoundSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SoundSort>(
      tooltip: 'Sort order',
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final option in SoundSort.values)
          PopupMenuItem(value: option, child: Text(soundSortLabel(option))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NothingColors.outlineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 15),
            const SizedBox(width: 6),
            Text(
              soundSortLabel(sort).toUpperCase(),
              style: NothingTypography.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom range slider for selecting a section of the song
class _RangeSliderWidget extends StatelessWidget {
  const _RangeSliderWidget({
    required this.start,
    required this.end,
    required this.onChanged,
    this.currentPosition,
  });

  final double start;
  final double end;
  final double? currentPosition;
  final void Function(double start, double end) onChanged;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: NothingColors.red,
        inactiveTrackColor: NothingColors.outline,
        rangeThumbShape: const RoundRangeSliderThumbShape(
          enabledThumbRadius: 10,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      child: Stack(
        children: [
          RangeSlider(
            values: RangeValues(start, end),
            onChanged: (values) => onChanged(values.start, values.end),
            activeColor: NothingColors.red,
            inactiveColor: NothingColors.outline,
          ),
          // Playback position indicator
          if (currentPosition != null)
            Positioned(
              left: (currentPosition! * (MediaQuery.of(context).size.width - 64)),
              top: 16,
              child: Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: NothingColors.white,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: NothingColors.ink.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
