import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class MiighoTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? prefixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final bool obscureText;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  const MiighoTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.keyboardType,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.obscureText = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: MiighoColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          obscureText: obscureText,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
          style: const TextStyle(color: MiighoColors.textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: MiighoColors.textMuted, fontSize: 14),
            prefixText: prefixText,
            prefixStyle: const TextStyle(color: MiighoColors.gold, fontWeight: FontWeight.bold),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            errorText: errorText,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
