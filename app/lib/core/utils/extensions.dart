import 'package:flutter/material.dart';

extension DateTimeExtensions on DateTime {
  String toRelative() {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays == 1) return 'Hier';
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year}';
  }
}

extension StringExtensions on String {
  String initials() {
    if (isEmpty) return '';
    final words = trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return (length > 1 ? substring(0, 2) : this).toUpperCase();
  }

  bool isValidPhone() {
    final regex = RegExp(r'^\+[1-9]\d{1,14}$');
    return regex.hasMatch(this);
  }
}
