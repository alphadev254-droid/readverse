import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../utils/extensions.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.forgotPassword(_emailCtrl.text.trim());
    if (!mounted) return;
    if (success) {
      setState(() => _sent = true);
    } else {
      context.showSnackBar(auth.error ?? 'Failed to send reset email', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSuccessView(cs) : _buildFormView(cs),
        ),
      ),
    );
  }

  Widget _buildFormView(ColorScheme cs) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_reset, size: 48, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text('Forgot Password?', style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: context.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          CustomTextField(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: Validators.email,
          ),
          const SizedBox(height: 24),
          Consumer<AuthProvider>(
            builder: (_, auth, __) => CustomButton(
              label: 'Send Reset Link',
              onPressed: _submit,
              isLoading: auth.isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(ColorScheme cs) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 80, color: cs.primary),
        const SizedBox(height: 24),
        Text('Check your email', style: context.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a password reset link to ${_emailCtrl.text}',
          style: context.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withOpacity(0.6)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        CustomButton(
          label: 'Back to Login',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
