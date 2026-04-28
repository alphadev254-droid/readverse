import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalContent(sections: _privacyPolicySections),
      ),
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _LegalContent(sections: _termsSections),
      ),
    );
  }
}

class _LegalContent extends StatelessWidget {
  final List<_Section> sections;
  const _LegalContent({required this.sections});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last updated: April 2026',
          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 20),
        ...sections.map((s) => _SectionWidget(section: s)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.mail_outline, color: cs.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Questions?', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('contact@readverse.app',
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final _Section section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.primary)),
          const SizedBox(height: 8),
          Text(section.body,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _Section {
  final String title;
  final String body;
  const _Section(this.title, this.body);
}

// ─── Privacy Policy Content ───────────────────────────────────────────────────

const _privacyPolicySections = [
  _Section(
    'Introduction',
    'ReadVerse ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use the ReadVerse mobile application.',
  ),
  _Section(
    'Information We Collect',
    'Account Information: When you register, we collect your name and email address.\n\n'
    'Documents: Files you import are stored locally on your device. We do not upload your documents to our servers unless you explicitly use online features.\n\n'
    'Usage Data: We may collect anonymised usage statistics such as app crashes and feature usage to improve the app.\n\n'
    'Audio Data: When you use the online Text-to-Speech feature, the text content of your document is sent to our TTS server to generate audio. This data is processed in real time and not stored.',
  ),
  _Section(
    'How We Use Your Information',
    '• To provide and maintain the ReadVerse service\n'
    '• To authenticate your account and keep it secure\n'
    '• To generate audio via our online TTS service\n'
    '• To improve app performance and fix bugs\n'
    '• To respond to your support requests',
  ),
  _Section(
    'Data Storage',
    'Your documents, bookmarks, highlights, and recordings are stored locally on your device using encrypted local storage. Account credentials are stored securely using platform-standard secure storage.\n\n'
    'We do not sell, trade, or transfer your personal information to third parties.',
  ),
  _Section(
    'Online TTS Service',
    'When you use the Online Reading feature, the text of your document is transmitted to our Piper TTS server over an encrypted HTTPS connection to generate speech audio. The text is processed in memory and is not logged or stored on our servers.',
  ),
  _Section(
    'Third-Party Services',
    'ReadVerse uses the following third-party services:\n\n'
    '• Piper TTS (self-hosted) — for neural text-to-speech synthesis\n'
    '• Flutter framework — for the app interface\n\n'
    'These services operate under their own privacy policies.',
  ),
  _Section(
    'Data Retention',
    'Account data is retained as long as your account is active. You may delete your account at any time, which will remove all associated data from our servers. Locally stored data (documents, recordings) remains on your device until you uninstall the app or delete it manually.',
  ),
  _Section(
    'Children\'s Privacy',
    'ReadVerse is not directed to children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with personal information, please contact us.',
  ),
  _Section(
    'Your Rights',
    'Depending on your location, you may have the right to:\n\n'
    '• Access the personal data we hold about you\n'
    '• Request correction of inaccurate data\n'
    '• Request deletion of your data\n'
    '• Object to processing of your data\n\n'
    'To exercise these rights, contact us at contact@readverse.app.',
  ),
  _Section(
    'Changes to This Policy',
    'We may update this Privacy Policy from time to time. We will notify you of significant changes by updating the "Last updated" date at the top of this page. Continued use of the app after changes constitutes acceptance of the updated policy.',
  ),
];

// ─── Terms of Service Content ─────────────────────────────────────────────────

const _termsSections = [
  _Section(
    'Acceptance of Terms',
    'By downloading, installing, or using ReadVerse, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.',
  ),
  _Section(
    'Description of Service',
    'ReadVerse is a document reading application that allows you to:\n\n'
    '• Import and read PDF, EPUB, DOCX, TXT, and Markdown files\n'
    '• Listen to documents using offline and online text-to-speech\n'
    '• Generate and save audio recordings of documents\n'
    '• Bookmark, highlight, and organise your reading library',
  ),
  _Section(
    'User Accounts',
    'You must create an account to use ReadVerse. You are responsible for:\n\n'
    '• Maintaining the confidentiality of your account credentials\n'
    '• All activity that occurs under your account\n'
    '• Providing accurate and current information\n\n'
    'You must be at least 13 years old to create an account.',
  ),
  _Section(
    'Acceptable Use',
    'You agree not to:\n\n'
    '• Use the app for any unlawful purpose\n'
    '• Import or process documents that infringe on third-party copyrights\n'
    '• Attempt to reverse engineer, decompile, or hack the app\n'
    '• Use the online TTS service to generate audio for commercial redistribution\n'
    '• Overload or abuse our TTS servers',
  ),
  _Section(
    'Intellectual Property',
    'The ReadVerse app, including its design, code, and branding, is owned by ReadVerse and protected by intellectual property laws. You are granted a limited, non-exclusive, non-transferable licence to use the app for personal, non-commercial purposes.\n\n'
    'Documents you import remain your property. We claim no ownership over your content.',
  ),
  _Section(
    'Online TTS Service',
    'The online TTS feature is provided as-is. We reserve the right to:\n\n'
    '• Limit usage to prevent abuse\n'
    '• Modify or discontinue the service with reasonable notice\n'
    '• Apply rate limits to ensure fair access for all users',
  ),
  _Section(
    'Disclaimer of Warranties',
    'ReadVerse is provided "as is" without warranties of any kind, either express or implied. We do not warrant that the app will be error-free, uninterrupted, or free of viruses or other harmful components.',
  ),
  _Section(
    'Limitation of Liability',
    'To the maximum extent permitted by law, ReadVerse shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the app, including loss of data or documents.',
  ),
  _Section(
    'Termination',
    'We reserve the right to suspend or terminate your account if you violate these Terms of Service. You may also delete your account at any time through the app settings.',
  ),
  _Section(
    'Changes to Terms',
    'We may update these Terms of Service from time to time. Continued use of the app after changes constitutes acceptance of the updated terms. We will notify you of material changes via the app.',
  ),
  _Section(
    'Governing Law',
    'These Terms of Service are governed by applicable law. Any disputes arising from these terms shall be resolved through good-faith negotiation before pursuing legal remedies.',
  ),
];
