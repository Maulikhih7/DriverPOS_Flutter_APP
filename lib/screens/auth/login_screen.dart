import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/page_config_provider.dart';
import '../../services/page_config_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/pos');
    } else {
      final pending = ref.read(authProvider).pendingPasswordChangeEmail;
      if (pending != null) _showChangePasswordDialog(pending);
    }
  }

  void _showChangePasswordDialog(String username) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePasswordDialog(username: username),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(loginPageConfigProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/drv_lgintab_bck.png', fit: BoxFit.cover),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      configState.config.logoAsset,
                      height: configState.config.logoHeight,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(
                        'driver.io',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF24497A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildCard(authState, configState),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(dynamic authState, dynamic configState) {
    final cfg = configState.config;
    return Container(
      width: 340,
      padding: EdgeInsets.only(
        top: cfg.cardPaddingTop,
        bottom: cfg.cardPaddingBottom,
        left: cfg.cardPaddingLeft,
        right: cfg.cardPaddingRight,
      ),
      decoration: BoxDecoration(
        color: cfg.cardBackground,
        borderRadius: BorderRadius.circular(cfg.cardBorderRadius),
        border: Border.all(color: const Color(0xFFF4F8F3), width: 15),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cfg.subtitleText,
              style: GoogleFonts.nunito(
                fontSize: cfg.subtitleFontSize,
                fontWeight: cfg.subtitleFontWeight,
                color: cfg.subtitleColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cfg.headingText,
              style: GoogleFonts.nunito(
                fontSize: cfg.headingFontSize,
                fontWeight: cfg.headingFontWeight,
                color: cfg.headingColor,
              ),
            ),
            const SizedBox(height: 26),

            _buildField(
              label: cfg.usernameLabel,
              controller: _emailCtrl,
              hint: cfg.usernamePlaceholder,
              labelColor: cfg.usernameLabelColor,
              borderColor: cfg.fieldBorderColor,
              focusBorderColor: cfg.fieldFocusBorderColor,
              keyboardType: TextInputType.emailAddress,
              action: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            ),
            const SizedBox(height: 18),

            _buildField(
              label: cfg.passwordLabel,
              controller: _passCtrl,
              hint: cfg.passwordPlaceholder,
              labelColor: cfg.passwordLabelColor,
              borderColor: cfg.fieldBorderColor,
              focusBorderColor: cfg.fieldFocusBorderColor,
              obscure: _obscure,
              action: TextInputAction.done,
              suffix: IconButton(
                iconSize: 20,
                icon: Icon(
                  _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.grey.shade400,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),

            if (authState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  authState.error!,
                  style: GoogleFonts.nunito(
                    fontSize: cfg.errorTextFontSize,
                    color: cfg.errorTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            _SocketStatusBadge(
              status: configState.socketStatus,
              error: configState.socketError,
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cfg.loginButtonBackground,
                  foregroundColor: cfg.loginButtonTextColor,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                      vertical: cfg.loginButtonHeight / 4),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(cfg.loginButtonBorderRadius),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        cfg.loginButtonText,
                        style: GoogleFonts.nunito(
                          fontSize: cfg.loginButtonFontSize,
                          fontWeight: FontWeight.w600,
                          color: cfg.loginButtonTextColor,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    Color labelColor = const Color(0xFF244065),
    Color borderColor = const Color(0xFFE0E5E9),
    Color focusBorderColor = const Color(0xFF244065),
    TextInputType keyboardType = TextInputType.text,
    TextInputAction action = TextInputAction.next,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: action,
          obscureText: obscure,
          obscuringCharacter: '•',
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: GoogleFonts.nunito(fontSize: 13, color: const Color(0xFF244065)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade400),
            errorStyle: GoogleFonts.nunito(
              fontSize: 11,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: suffix,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: _border(color: borderColor),
            enabledBorder: _border(color: borderColor),
            focusedBorder: _border(color: focusBorderColor, width: 1.5),
            errorBorder: _border(color: Colors.red),
            focusedErrorBorder: _border(color: Colors.red, width: 1.5),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border({
    Color color = const Color(0xFFE0E5E9),
    double width = 1.0,
  }) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}

// ── Socket status badge ───────────────────────────────────────────────────────

class _SocketStatusBadge extends StatelessWidget {
  final SocketStatus status;
  final String? error;

  const _SocketStatusBadge({
    required this.status,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      SocketStatus.connected    => ('● Socket connected', const Color(0xFF4CAF50)),
      SocketStatus.connecting   => ('◌ Socket connecting...', const Color(0xFFFFA726)),
      SocketStatus.disconnected => ('○ Socket disconnected', const Color(0xFF9E9E9E)),
      SocketStatus.error        => ('✕ Socket error', const Color(0xFFC01C2D)),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          if (error != null) ...[
            const SizedBox(height: 2),
            Text(error!,
                style: TextStyle(
                    fontSize: 10, color: color.withValues(alpha: 0.8))),
          ],
        ],
      ),
    );
  }
}

// ── Change Password Dialog ────────────────────────────────────────────────────

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  final String username;
  const _ChangePasswordDialog({required this.username});

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).changePassword(
          newPassword: _newPassCtrl.text,
          confirmPassword: _confirmPassCtrl.text,
        );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Set New Password',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'First login detected for "${widget.username}". Please set a new password to continue.',
              style: GoogleFonts.nunito(
                  fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                isDense: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                isDense: true,
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newPassCtrl.text) return 'Passwords do not match';
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (authState.error != null) ...[
              const SizedBox(height: 12),
              Text(
                authState.error!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: authState.isLoading
              ? null
              : () {
                  ref
                      .read(authProvider.notifier)
                      .dismissPasswordChange();
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: authState.isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA8C59E),
          ),
          child: authState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  'Set Password',
                  style: GoogleFonts.nunito(color: Colors.white),
                ),
        ),
      ],
    );
  }
}
