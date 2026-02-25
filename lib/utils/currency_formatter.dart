import 'package:flutter/services.dart';
import 'persian_utils.dart';

class CurrencyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Get digits only
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format with commas
    String formatted = PersianUtils.formatWithCommas(digitsOnly);

    // Calculate new selection position
    int newSelectionOffset = formatted.length;
    
    // Attempt to keep cursor position if possible (optional, but let's keep it simple for now)
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelectionOffset),
    );
  }
}
