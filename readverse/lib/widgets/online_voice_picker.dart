import 'package:flutter/material.dart';

/// Model for online voice
class OnlineVoice {
  final String id;
  final String name;
  final String language;
  final String gender;
  final String quality;
  final String description;

  const OnlineVoice({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
    required this.quality,
    required this.description,
  });
}

/// Available Piper voices
class PiperVoices {
  static const List<OnlineVoice> voices = [
    // High Quality Voices
    OnlineVoice(
      id: 'en_US-lessac-high',
      name: 'Lessac (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'high',
      description: 'Clear, professional American voice',
    ),
    OnlineVoice(
      id: 'en_US-amy-high',
      name: 'Amy (US)',
      language: 'English (US)',
      gender: 'Female',
      quality: 'high',
      description: 'Natural, friendly American voice',
    ),
    OnlineVoice(
      id: 'en_US-ryan-high',
      name: 'Ryan (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'high',
      description: 'Authoritative American voice',
    ),
    OnlineVoice(
      id: 'en_US-libritts-high',
      name: 'LibriTTS (US)',
      language: 'English (US)',
      gender: 'Neutral',
      quality: 'high',
      description: 'Expressive American voice',
    ),
    OnlineVoice(
      id: 'en_GB-alan-high',
      name: 'Alan (GB)',
      language: 'English (UK)',
      gender: 'Male',
      quality: 'high',
      description: 'British accent, clear',
    ),
    OnlineVoice(
      id: 'en_GB-alba-high',
      name: 'Alba (GB)',
      language: 'English (UK)',
      gender: 'Female',
      quality: 'high',
      description: 'British accent, elegant',
    ),
    OnlineVoice(
      id: 'en_GB-jenny_dioco-high',
      name: 'Jenny (GB)',
      language: 'English (UK)',
      gender: 'Female',
      quality: 'high',
      description: 'British accent, warm tone',
    ),

    // Medium Quality Voices
    OnlineVoice(
      id: 'en_US-lessac-medium',
      name: 'Lessac (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'medium',
      description: 'Clear American voice',
    ),
    OnlineVoice(
      id: 'en_US-amy-medium',
      name: 'Amy (US)',
      language: 'English (US)',
      gender: 'Female',
      quality: 'medium',
      description: 'Natural American voice',
    ),
    OnlineVoice(
      id: 'en_US-ryan-medium',
      name: 'Ryan (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'medium',
      description: 'Professional American voice',
    ),
    OnlineVoice(
      id: 'en_US-libritts-medium',
      name: 'LibriTTS (US)',
      language: 'English (US)',
      gender: 'Neutral',
      quality: 'medium',
      description: 'Expressive American voice',
    ),
    OnlineVoice(
      id: 'en_GB-alan-medium',
      name: 'Alan (GB)',
      language: 'English (UK)',
      gender: 'Male',
      quality: 'medium',
      description: 'British accent',
    ),
    OnlineVoice(
      id: 'en_GB-alba-medium',
      name: 'Alba (GB)',
      language: 'English (UK)',
      gender: 'Female',
      quality: 'medium',
      description: 'British accent',
    ),

    // Low Quality Voices
    OnlineVoice(
      id: 'en_US-lessac-low',
      name: 'Lessac (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'low',
      description: 'Fast, smaller model',
    ),
    OnlineVoice(
      id: 'en_US-amy-low',
      name: 'Amy (US)',
      language: 'English (US)',
      gender: 'Female',
      quality: 'low',
      description: 'Fast, smaller model',
    ),
    OnlineVoice(
      id: 'en_US-ryan-low',
      name: 'Ryan (US)',
      language: 'English (US)',
      gender: 'Male',
      quality: 'low',
      description: 'Fast, smaller model',
    ),
  ];

  static List<OnlineVoice> getHighQualityVoices() {
    return voices.where((v) => v.quality == 'high').toList();
  }

  static List<OnlineVoice> getMediumQualityVoices() {
    return voices.where((v) => v.quality == 'medium').toList();
  }

  static List<OnlineVoice> getLowQualityVoices() {
    return voices.where((v) => v.quality == 'low').toList();
  }
}

/// Dialog for selecting online voice
class OnlineVoicePicker extends StatefulWidget {
  final String? selectedVoiceId;
  final Function(OnlineVoice) onVoiceSelected;

  const OnlineVoicePicker({
    super.key,
    this.selectedVoiceId,
    required this.onVoiceSelected,
  });

  @override
  State<OnlineVoicePicker> createState() => _OnlineVoicePickerState();

  /// Show the voice picker dialog
  static Future<OnlineVoice?> show(
    BuildContext context, {
    String? selectedVoiceId,
  }) async {
    OnlineVoice? selectedVoice;

    await showDialog(
      context: context,
      builder: (context) => OnlineVoicePicker(
        selectedVoiceId: selectedVoiceId,
        onVoiceSelected: (voice) => selectedVoice = voice,
      ),
    );

    return selectedVoice;
  }
}

class _OnlineVoicePickerState extends State<OnlineVoicePicker> {
  String? _selectedVoiceId;
  String _selectedQuality = 'high'; // 'high', 'medium', 'low'

  @override
  void initState() {
    super.initState();
    _selectedVoiceId = widget.selectedVoiceId ?? 'en_US-lessac-high';
  }

  @override
  Widget build(BuildContext context) {
    final highQualityVoices = PiperVoices.getHighQualityVoices();
    final mediumQualityVoices = PiperVoices.getMediumQualityVoices();
    final lowQualityVoices = PiperVoices.getLowQualityVoices();

    List<OnlineVoice> displayedVoices;
    String sectionTitle;
    String sectionSubtitle;

    switch (_selectedQuality) {
      case 'high':
        displayedVoices = highQualityVoices;
        sectionTitle = 'Premium Voices';
        sectionSubtitle = '~30-50MB each';
        break;
      case 'medium':
        displayedVoices = mediumQualityVoices;
        sectionTitle = 'Standard Voices';
        sectionSubtitle = '~10-15MB each';
        break;
      case 'low':
        displayedVoices = lowQualityVoices;
        sectionTitle = 'Fast Voices';
        sectionSubtitle = '~5MB each';
        break;
      default:
        displayedVoices = highQualityVoices;
        sectionTitle = 'Premium Voices';
        sectionSubtitle = '~30-50MB each';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.record_voice_over,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Voice',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Choose your preferred narrator',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quality Toggle
            Row(
              children: [
                Expanded(
                  child: _QualityChip(
                    label: 'High',
                    icon: Icons.star,
                    isSelected: _selectedQuality == 'high',
                    onTap: () => setState(() => _selectedQuality = 'high'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QualityChip(
                    label: 'Medium',
                    icon: Icons.speed,
                    isSelected: _selectedQuality == 'medium',
                    onTap: () => setState(() => _selectedQuality = 'medium'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QualityChip(
                    label: 'Low',
                    icon: Icons.flash_on,
                    isSelected: _selectedQuality == 'low',
                    onTap: () => setState(() => _selectedQuality = 'low'),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Voice List
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader(context, sectionTitle, sectionSubtitle),
                  ...displayedVoices.map((voice) => _VoiceCard(
                        voice: voice,
                        isSelected: _selectedVoiceId == voice.id,
                        onTap: () => setState(() => _selectedVoiceId = voice.id),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final selectedVoice = PiperVoices.voices
                          .firstWhere((v) => v.id == _selectedVoiceId);
                      Navigator.pop(context);
                      widget.onVoiceSelected(selectedVoice);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Start Reading'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

class _QualityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QualityChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.purple : Colors.grey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.purple : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final OnlineVoice voice;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoiceCard({
    required this.voice,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.purple.withOpacity(0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.purple : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: voice.gender == 'Male'
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  voice.gender == 'Male' ? Icons.man : Icons.woman,
                  color: voice.gender == 'Male' ? Colors.blue : Colors.pink,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              // Voice Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            voice.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            voice.language,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      voice.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.purple,
                  size: 24,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: Colors.grey[400],
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
