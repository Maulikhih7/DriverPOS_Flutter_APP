import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/dvpaylite_config.dart';
import '../../services/payment_service.dart';

class DvPayLiteSettingsScreen extends StatefulWidget {
  const DvPayLiteSettingsScreen({super.key});

  @override
  State<DvPayLiteSettingsScreen> createState() =>
      _DvPayLiteSettingsScreenState();
}

class _DvPayLiteSettingsScreenState extends State<DvPayLiteSettingsScreen> {
  DvPayLiteConfig _config = const DvPayLiteConfig();
  bool _loading = true;

  final _primaryCtrl = TextEditingController();
  final _secondaryCtrl = TextEditingController();
  final _negativeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await DvPayLiteConfig.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _primaryCtrl.text = config.primaryColor;
      _secondaryCtrl.text = config.secondaryColor;
      _negativeCtrl.text = config.negativeButtonColor;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _secondaryCtrl.dispose();
    _negativeCtrl.dispose();
    super.dispose();
  }

  void _update(DvPayLiteConfig updated) {
    setState(() => _config = updated);
    updated.save();
  }

  bool _testing = false;

  Future<void> _testPayment() async {
    final tpn = await PaymentService.getSavedTPN();
    if (!mounted) return;
    if (tpn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No terminal configured — set up a TPN in Terminal Setup first.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    setState(() => _testing = true);
    try {
      final result = await PaymentService.performSale(
        tpn: tpn,
        amount: 0.01,
        paymentType: 'CREDIT',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.approved
              ? 'Test approved — Auth: ${result.authCode}'
              : 'Test declined: ${result.responseMessage}'),
          backgroundColor:
              result.approved ? AppColors.primary : AppColors.danger,
        ),
      );
    } on PaymentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('DVPayLite error: ${e.message}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _resetDefaults() {
    const d = DvPayLiteConfig();
    _primaryCtrl.text = d.primaryColor;
    _secondaryCtrl.text = d.secondaryColor;
    _negativeCtrl.text = d.negativeButtonColor;
    _update(d);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to defaults')),
    );
  }

  static Color? _hex(String raw) {
    final h = raw.replaceAll('#', '').trim();
    if (h.length != 6) return null;
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final primary = _hex(_config.primaryColor) ?? AppColors.primary;
    final secondary = _hex(_config.secondaryColor) ?? AppColors.textPrimary;
    final negative = _hex(_config.negativeButtonColor) ?? AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('DVPayLite Terminal Style'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Reset'),
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live Preview ─────────────────────────────────────────
          _PreviewMockup(
            primaryColor: primary,
            secondaryColor: secondary,
            negativeColor: negative,
            fontFamily: _config.fontFamily,
          ),
          const SizedBox(height: 20),

          // ── Brand Colors ─────────────────────────────────────────
          _SectionLabel('Brand Colors'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _ColorRow(
              label: 'Primary',
              hint: 'Buttons, NFC indicator, OK key',
              controller: _primaryCtrl,
              onHexChanged: (hex) {
                if (_hex(hex) != null) {
                  _update(_config.copyWith(primaryColor: hex));
                }
              },
            ),
            _kDivider,
            _ColorRow(
              label: 'Secondary',
              hint: 'Text labels, toolbar, keypad numbers',
              controller: _secondaryCtrl,
              onHexChanged: (hex) {
                if (_hex(hex) != null) {
                  _update(_config.copyWith(secondaryColor: hex));
                }
              },
            ),
            _kDivider,
            _ColorRow(
              label: 'Negative',
              hint: 'Cancel, close & backspace buttons',
              controller: _negativeCtrl,
              onHexChanged: (hex) {
                if (_hex(hex) != null) {
                  _update(_config.copyWith(negativeButtonColor: hex));
                }
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── Typography ───────────────────────────────────────────
          _SectionLabel('Typography'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: _config.fontFamily,
                decoration: const InputDecoration(
                  labelText: 'Font Family',
                  isDense: true,
                ),
                items: DvPayLiteConfig.fontFamilies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _update(_config.copyWith(fontFamily: v));
                },
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Display Options ──────────────────────────────────────
          _SectionLabel('Display Options'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _SwitchRow(
              label: 'Remove Loader Logo',
              hint: 'Hides logo and left-aligns loader text',
              value: _config.removeLoaderLogo,
              onChanged: (v) => _update(_config.copyWith(removeLoaderLogo: v)),
            ),
            _kDivider,
            _SwitchRow(
              label: 'Require Address Verification (AVS)',
              hint: 'Shows street & ZIP fields during card entry',
              value: _config.requiredAvs,
              onChanged: (v) => _update(_config.copyWith(requiredAvs: v)),
            ),
            _kDivider,
            _SwitchRow(
              label: 'Show Amount Breakdown',
              hint: 'Displays subtotal, tip, and total separately',
              value: _config.showBreakupScreen,
              onChanged: (v) => _update(_config.copyWith(showBreakupScreen: v)),
            ),
            _kDivider,
            _SwitchRow(
              label: 'Show Tip Screen',
              hint: 'Customer selects or enters tip amount',
              value: _config.showTipScreen,
              onChanged: (v) => _update(_config.copyWith(showTipScreen: v)),
            ),
            _kDivider,
            _SwitchRow(
              label: 'Show Dual Pricing',
              hint: 'Presents cash vs. card pricing options',
              value: _config.showDualPriceScreen,
              onChanged: (v) => _update(_config.copyWith(showDualPriceScreen: v)),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Receipt & Status ─────────────────────────────────────
          _SectionLabel('Receipt & Status'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: DropdownButtonFormField<String>(
                initialValue: _config.receiptType,
                decoration: const InputDecoration(
                  labelText: 'Print Receipt',
                  isDense: true,
                ),
                items: DvPayLiteConfig.receiptTypes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _update(_config.copyWith(receiptType: v));
                },
              ),
            ),
            _kDivider,
            _SwitchRow(
              label: 'Show Transaction Status Screen',
              hint: 'Displays Approved / Declined after processing',
              value: _config.showTxnStatusScreen,
              onChanged: (v) =>
                  _update(_config.copyWith(showTxnStatusScreen: v)),
            ),
          ]),

          const SizedBox(height: 24),

          // ── Test Button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _testing ? null : _testPayment,
              icon: _testing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.play_circle_outline, size: 22),
              label: Text(
                _testing ? 'Opening DVPayLite…' : 'Test Payment  \$0.01',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Fires a real \$0.01 charge — cancel on the terminal to avoid a charge.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kDivider = Divider(height: 1, indent: 16, endIndent: 16);

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Color row: live color circle + hex text input
// ─────────────────────────────────────────────────────────────────────────────

class _ColorRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onHexChanged;

  const _ColorRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onHexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Live color preview — rebuilds whenever the text field changes
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, _) {
              final h = val.text.trim();
              Color preview = Colors.grey.shade300;
              if (h.length == 6) {
                try {
                  preview = Color(int.parse('FF$h', radix: 16));
                } catch (_) {}
              }
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: preview,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: preview.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          // Label + hint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(hint,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Hex input field
          SizedBox(
            width: 118,
            child: TextFormField(
              controller: controller,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(
                prefixText: '# ',
                isDense: true,
                counterText: '',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                letterSpacing: 1.2,
              ),
              onChanged: onHexChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Switch row
// ─────────────────────────────────────────────────────────────────────────────

class _SwitchRow extends StatelessWidget {
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(hint,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primaryLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live preview mockup — mini terminal UI rendering current colors
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewMockup extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color negativeColor;
  final String fontFamily;

  const _PreviewMockup({
    required this.primaryColor,
    required this.secondaryColor,
    required this.negativeColor,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.phone_android_outlined,
                    size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                const Text('Live Preview',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(fontFamily,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Terminal mockup
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFDDE1E7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toolbar (primary)
                      Container(
                        height: 42,
                        color: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_back_ios,
                                size: 13,
                                color: Colors.white),
                            Spacer(),
                            Text('DVPayLite',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Spacer(),
                            SizedBox(width: 13),
                          ],
                        ),
                      ),

                      // Amount (secondary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        color: Colors.white,
                        child: Column(
                          children: [
                            Text(
                              '\$ 42.00',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: secondaryColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    secondaryColor.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // NFC indicator (primary)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        color: const Color(0xFFF8F9FA),
                        child: Column(
                          children: [
                            Icon(Icons.nfc, size: 34, color: primaryColor),
                            const SizedBox(height: 6),
                            Text(
                              'Insert / Tap / Swipe',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action buttons
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(
                                color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Cancel (negative)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color: negativeColor
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  border: Border.all(
                                      color: negativeColor
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'CANCEL',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: negativeColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // OK (primary)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OK',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
