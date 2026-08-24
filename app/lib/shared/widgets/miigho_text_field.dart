import 'package:flutter/material.dart';

class MiighoTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? prefixText;
  final int? maxLength;
  final bool obscureText;

  const MiighoTextField({
    super.key,
    required this.label,
    this.controller,
    this.keyboardType,
    this.prefixText,
    this.maxLength,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        counterText: '',
      ),
    );
  }
}
