import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recording_model.dart';
import '../../providers/recording_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/extensions.dart';

class RecordingsScreen extends StatelessWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Consumer<RecordingProvider>(
      builder: (_, provider, __) {
        final recordings = provider.recordings;
        if (recordings.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_none, size: 64,
                    color: cs.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No recordings yet',
                    style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Text('Tap the mic button while reading to record',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: recordings.length,
          itemBuilder: (_, i) => _RecordingCard(
            recording: recordings[i],
            provider: provider,
          ),
        );
      },
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final RecordingModel recording;
  final RecordingProvider provider;

  const _RecordingCard({required this.recording, required this.provider});

  bool get _isActive => provider.activeRecordingId == recording.id;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isPlaying = _isActive && provider.state == RecordingState.playing;
    final isPaused = _isActive && provider.state == RecordingState.playerPaused;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isActive ? cs.primary : cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isActive ? Icons.graphic_eq : Icons.mic,
                    size: 20,
                    color: _isActive ? cs.onPrimary : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recording.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${recording.formattedDuration}  •  ${recording.formattedSize}  •  ${Formatters.date(recording.createdAt)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      size: 20,
                      color: cs.onSurface.withValues(alpha: 0.5)),
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'rename',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Rename'),
                        ])),
                    const PopupMenuItem(
                        value: 'info',
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Info'),
                        ])),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                ),
              ],
            ),

            // ── Playback progress ──
            if (_isActive) ...[
              const SizedBox(height: 10),
              StreamBuilder<Duration>(
                stream: provider.positionStream,
                builder: (_, posSnap) => StreamBuilder<Duration?>(
                  stream: provider.durationStream,
                  builder: (_, durSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    final dur = durSnap.data ?? Duration.zero;
                    final frac = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds / dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac,
                            minHeight: 4,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(_fmt(pos),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5))),
                            const Spacer(),
                            Text(_fmt(dur),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5))),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],

            // ── Controls ──
            const SizedBox(height: 10),
            Row(
              children: [
                if (!isPlaying)
                  FilledButton.icon(
                    onPressed: () => isPaused
                        ? provider.resumePlayback()
                        : provider.playRecording(recording),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text(isPaused ? 'Resume' : 'Play'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                  )
                else
                  FilledButton.icon(
                    onPressed: provider.pausePlayback,
                    icon: const Icon(Icons.pause_rounded, size: 18),
                    label: const Text('Pause'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                if (_isActive) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: provider.stopPlayback,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _onMenu(BuildContext context, String action) {
    switch (action) {
      case 'rename':
        _renameDialog(context);
        break;
      case 'info':
        _infoDialog(context);
        break;
      case 'delete':
        _deleteDialog(context);
        break;
    }
  }

  void _renameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: recording.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Recording'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              provider.renameRecording(recording.id, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _infoDialog(BuildContext context) {
    final cs = context.colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recording Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow('Name', recording.name, cs),
            _buildInfoRow('Duration', recording.formattedDuration, cs),
            _buildInfoRow('Size', recording.formattedSize, cs),
            _buildInfoRow('Created', Formatters.dateTime(recording.createdAt), cs),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Recording'),
        content: Text('Delete "${recording.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteRecording(recording.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

Widget _buildInfoRow(String label, String value, ColorScheme cs) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
