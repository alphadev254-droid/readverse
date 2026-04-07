import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../utils/extensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildProfileSection(context),
          _buildDivider('Reading Preferences'),
          _buildReadingSection(context),
          _buildDivider('Theme'),
          _buildThemeSection(context),
          _buildDivider('Text-to-Speech'),
          _buildTtsSection(context),
          _buildDivider('Storage & Cache'),
          _buildStorageSection(context),
          _buildDivider('Account'),
          _buildAccountSection(context),
          _buildDivider('About'),
          _buildAboutSection(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDivider(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final cs = context.colorScheme;
    final initials = user?.name.isNotEmpty == true ? user!.name.substring(0, 1).toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primary,
                child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.camera_alt, size: 14, color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(user?.email ?? '', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.showSnackBar('Edit profile coming soon'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, theme, __) => Column(
        children: [
          ListTile(
            title: const Text('Font Size'),
            subtitle: Row(
              children: [
                const Text('A', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: theme.fontSize,
                    min: AppConstants.minFontSize,
                    max: AppConstants.maxFontSize,
                    divisions: 10,
                    label: '${theme.fontSize.round()}px',
                    onChanged: theme.setFontSize,
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 22)),
              ],
            ),
          ),
          ListTile(
            title: const Text('Font Family'),
            trailing: DropdownButton<String>(
              value: theme.fontFamily,
              underline: const SizedBox(),
              items: ['Serif', 'Sans-serif', 'Monospace']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) { if (v != null) theme.setFontFamily(v); },
            ),
          ),
          ListTile(
            title: const Text('Line Height'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Compact', label: Text('Compact', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'Normal', label: Text('Normal', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'Relaxed', label: Text('Relaxed', style: TextStyle(fontSize: 11))),
              ],
              selected: {theme.lineHeight},
              onSelectionChanged: (s) => theme.setLineHeight(s.first),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          ListTile(
            title: const Text('Reading Background'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _BgColorOption(color: AppColors.readingWhite, label: 'White', selected: theme.readingBackground == AppColors.readingWhite, onTap: () => theme.setReadingBackground(AppColors.readingWhite)),
                  const SizedBox(width: 12),
                  _BgColorOption(color: AppColors.readingSepia, label: 'Sepia', selected: theme.readingBackground == AppColors.readingSepia, onTap: () => theme.setReadingBackground(AppColors.readingSepia)),
                  const SizedBox(width: 12),
                  _BgColorOption(color: AppColors.readingDark, label: 'Dark', selected: theme.readingBackground == AppColors.readingDark, onTap: () => theme.setReadingBackground(AppColors.readingDark)),
                  const SizedBox(width: 12),
                  _BgColorOption(color: AppColors.readingBlack, label: 'Black', selected: theme.readingBackground == AppColors.readingBlack, onTap: () => theme.setReadingBackground(AppColors.readingBlack)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, theme, __) => Column(
        children: [
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 16), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 16), label: Text('System')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 16), label: Text('Dark')),
                ],
                selected: {theme.themeMode},
                onSelectionChanged: (s) => theme.setThemeMode(s.first),
              ),
            ),
          ),
          ListTile(
            title: const Text('Accent Color'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Colors.deepPurple,
                  Colors.blue,
                  Colors.teal,
                  Colors.green,
                  Colors.orange,
                  Colors.red,
                  Colors.pink,
                ].map((color) => GestureDetector(
                  onTap: () => theme.setAccentColor(color),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: theme.accentColor.toARGB32() == color.toARGB32()
                          ? Border.all(color: context.colorScheme.onSurface, width: 2)
                          : null,
                    ),
                    child: theme.accentColor.toARGB32() == color.toARGB32()
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                )).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtsSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, settings, __) => Column(
        children: [
          ListTile(
            title: const Text('Default Speed'),
            subtitle: Row(
              children: [
                const Icon(Icons.slow_motion_video, size: 18),
                Expanded(
                  child: Slider(
                    value: settings.ttsDefaultSpeed,
                    min: AppConstants.minTtsSpeed,
                    max: AppConstants.maxTtsSpeed,
                    divisions: 6,
                    label: '${settings.ttsDefaultSpeed}x',
                    onChanged: settings.setTtsSpeed,
                  ),
                ),
                const Icon(Icons.fast_forward, size: 18),
              ],
            ),
          ),
          ListTile(
            title: const Text('Default Language'),
            trailing: DropdownButton<String>(
              value: settings.ttsDefaultVoice,
              underline: const SizedBox(),
              items: AppConstants.ttsLanguages.map((lang) => DropdownMenuItem(
                value: lang,
                child: Text(AppConstants.ttsLanguageNames[lang] ?? lang, style: const TextStyle(fontSize: 14)),
              )).toList(),
              onChanged: (v) { if (v != null) settings.setTtsVoice(v); },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Preview Voice'),
            onTap: () => context.showSnackBar('Voice preview: "Hello, welcome to ReadVerse!"'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSection(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (_, settings, __) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage Used'),
            trailing: Text(settings.formattedStorage, style: TextStyle(color: context.colorScheme.primary, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear Cache'),
            onTap: () => _confirmClearCache(context, settings),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_delete_outlined),
            title: const Text('Auto-delete Read Documents'),
            subtitle: const Text('Remove documents after 100% completion'),
            value: settings.autoDeleteRead,
            onChanged: settings.setAutoDeleteRead,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.orange),
          title: const Text('Logout'),
          onTap: () => _confirmLogout(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
          onTap: () => context.showSnackBar('Account deletion coming soon'),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final cs = context.colorScheme;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Version'),
          trailing: Text(AppConstants.appVersion, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => context.showSnackBar('Opening Privacy Policy...'),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.open_in_new, size: 16),
          onTap: () => context.showSnackBar('Opening Terms of Service...'),
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('Open Source Licenses'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(context: context, applicationName: 'ReadVerse', applicationVersion: AppConstants.appVersion),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _confirmClearCache(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear temporary files. Your documents will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await settings.clearCache();
              if (context.mounted) context.showSnackBar('Cache cleared', isSuccess: true);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _BgColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BgColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? context.colorScheme.primary : context.colorScheme.outline.withValues(alpha: 0.3),
                width: selected ? 2 : 1,
              ),
            ),
            child: selected ? Icon(Icons.check, size: 20, color: color.isLight ? Colors.black : Colors.white) : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
