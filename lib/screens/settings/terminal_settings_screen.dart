import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/payment_service.dart';

class TerminalSettingsScreen extends StatefulWidget {
  const TerminalSettingsScreen({super.key});

  @override
  State<TerminalSettingsScreen> createState() => _TerminalSettingsScreenState();
}

class _TerminalSettingsScreenState extends State<TerminalSettingsScreen> {
  final _tpnCtrl = TextEditingController();
  bool _loading = true;
  bool _registering = false;
  String? _currentTPN;
  String? _statusMsg;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tpn = await PaymentService.getSavedTPN();
    if (mounted) {
      setState(() {
        _currentTPN = tpn;
        if (tpn != null) _tpnCtrl.text = tpn;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tpnCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final tpn = _tpnCtrl.text.trim();
    if (tpn.isEmpty) return;
    setState(() {
      _registering = true;
      _statusMsg = null;
    });
    try {
      await PaymentService.registerTerminal(tpn);
      await PaymentService.saveTPN(tpn);
      if (mounted) {
        setState(() {
          _currentTPN = tpn;
          _statusMsg = 'Terminal registered successfully.';
          _statusOk = true;
          _registering = false;
        });
      }
    } on PaymentException catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = e.message;
          _statusOk = false;
          _registering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = e.toString();
          _statusOk = false;
          _registering = false;
        });
      }
    }
  }

  Future<void> _clear() async {
    await PaymentService.clearTPN();
    if (mounted) {
      setState(() {
        _currentTPN = null;
        _tpnCtrl.clear();
        _statusMsg = 'Terminal removed.';
        _statusOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Terminal Setup'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _currentTPN != null
                              ? AppColors.primaryLight
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _currentTPN != null
                              ? Icons.credit_card
                              : Icons.credit_card_off_outlined,
                          color: _currentTPN != null
                              ? AppColors.primary
                              : AppColors.danger,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentTPN != null
                                  ? 'Terminal Active'
                                  : 'No Terminal Configured',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _currentTPN != null
                                    ? AppColors.primary
                                    : AppColors.danger,
                              ),
                            ),
                            if (_currentTPN != null)
                              Text(
                                'TPN: $_currentTPN',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TPN input card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terminal TPN',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter the Terminal Payment Number from your Dejavoo device.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _tpnCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: const InputDecoration(
                          hintText: '000000000000',
                          prefixIcon: Icon(Icons.dialpad),
                          labelText: 'TPN',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _registering ? null : _register,
                          icon: _registering
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _registering ? 'Registering…' : 'Register Terminal',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_statusMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _statusOk
                          ? AppColors.primaryLight
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusOk
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: _statusOk ? AppColors.primary : AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMsg!,
                            style: TextStyle(
                              color: _statusOk ? AppColors.primary : AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_currentTPN != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    label: const Text(
                      'Remove Terminal',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // DVPayLite appearance customization
                GestureDetector(
                  onTap: () => context.push('/dvpay-settings'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.palette_outlined, color: AppColors.primary, size: 22),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DVPayLite Terminal Style',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14)),
                              SizedBox(height: 2),
                              Text('Customize colors, font & display options',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
