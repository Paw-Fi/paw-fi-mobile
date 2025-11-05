import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcnui;
import 'package:moneko/core/core.dart';
import 'package:moneko/core/l10n/l10n.dart';

class WhatsAppVerificationModal extends StatefulWidget {
  final String? otpFromUrl;
  final VoidCallback? onVerificationSuccess;

  const WhatsAppVerificationModal({
    super.key,
    this.otpFromUrl,
    this.onVerificationSuccess,
  });

  @override
  State<WhatsAppVerificationModal> createState() => _WhatsAppVerificationModalState();
}

class _WhatsAppVerificationModalState extends State<WhatsAppVerificationModal> {
  String _code = '';
  bool _isLoading = false;
  bool _isVerified = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill OTP if provided
    if (widget.otpFromUrl != null && widget.otpFromUrl!.length == 6) {
      _code = widget.otpFromUrl!;
      // Auto-verify if OTP is pre-filled
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyCode();
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_code.trim().isEmpty || _code.length != 6) {
      setState(() {
        _errorMessage = context.l10n.pleaseEnterThe6DigitVerificationCode;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase.functions.invoke(
        'verify-whatsapp-binding',
        body: {'code': _code},
      );

      if (!mounted) return;

      final data = response.data as Map<String, dynamic>?;

      if (response.status >= 400 || data == null) {
        final errorMessage = data?['error'] as String? ?? context.l10n.failedToVerifyCode;
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
        return;
      }

      if (data['success'] == true) {
        setState(() {
          _isVerified = true;
          _errorMessage = null;
          _isLoading = false;
        });
        
        // Call success callback if provided
        widget.onVerificationSuccess?.call();
      } else {
        setState(() {
          _errorMessage = data['error'] as String? ?? context.l10n.invalidVerificationCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error verifying WhatsApp code: $e');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = context.l10n.failedToVerifyCodePleaseTryAgain;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = shadcnui.Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isVerified ? context.l10n.whatsappVerified : context.l10n.whatsappVerification,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.foreground,
                ),
              ),
              if (!_isVerified && !_isLoading)
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.mutedForeground),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Description or success message
          if (_isVerified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.yourWhatsAppNumberIsSuccessfullyLinked,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              widget.otpFromUrl != null
                  ? context.l10n.verifyingYourWhatsAppNumber
                  : context.l10n.enterThe6DigitCodeFromWhatsApp,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.mutedForeground,
              ),
            ),
          
          const SizedBox(height: 24),

          // OTP Input (show if not verified)
          if (!_isVerified) ...[
            Center(
              child: AbsorbPointer(
                absorbing: _isLoading || widget.otpFromUrl != null,
                child: shadcnui.InputOTP(
                  initialValue: _code.codeUnits,
                  onChanged: (value) {
                    setState(() {
                      // Convert code points back to string, filtering out nulls
                      _code = String.fromCharCodes(value.where((c) => c != null).cast<int>());
                      _errorMessage = null;
                    });
                  },
                  children: [
                    shadcnui.InputOTPChild.character(allowDigit: true),
                    shadcnui.InputOTPChild.character(allowDigit: true),
                    shadcnui.InputOTPChild.character(allowDigit: true),
                    shadcnui.InputOTPChild.character(allowDigit: true),
                    shadcnui.InputOTPChild.character(allowDigit: true),
                    shadcnui.InputOTPChild.character(allowDigit: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Helper text or error
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.otpFromUrl != null)
              Center(
                child: Text(
                  context.l10n.codeAutoFilledFromVerificationLink,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  context.l10n.enterThe6DigitCodeFromWhatsApp,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.mutedForeground,
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Verify button
            if (!_isLoading)
              shadcnui.PrimaryButton(
                onPressed: _code.length == 6 ? _verifyCode : null,
                child: Text(context.l10n.verify),
              )
            else
              shadcnui.PrimaryButton(
                onPressed: null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(context.l10n.verifying),
                  ],
                ),
              ),
          ],

          // Close button for success state
          if (_isVerified) ...[
            const SizedBox(height: 24),
            shadcnui.PrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(context.l10n.done),
            ),
          ],
        ],
      ),
    );
  }
}

/// Show WhatsApp verification modal
Future<void> showWhatsAppVerificationModal(
  BuildContext context, {
  String? otpFromUrl,
  VoidCallback? onVerificationSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final colorScheme = shadcnui.Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: WhatsAppVerificationModal(
          otpFromUrl: otpFromUrl,
          onVerificationSuccess: onVerificationSuccess,
        ),
      );
    },
  );
}
