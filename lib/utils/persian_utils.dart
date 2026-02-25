class PersianUtils {
  static const List<String> _ones = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
  static const List<String> _teens = ['ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'];
  static const List<String> _tens = ['', 'ده', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'];
  static const List<String> _hundreds = ['', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'];
  static const List<String> _thousands = ['', 'هزار', 'میلیون', 'میلیارد', 'تریلیون', 'کواتریلیون'];

  static String numberToWords(int number) {
    if (number == 0) return 'صفر';
    if (number < 0) return 'منفی ' + numberToWords(number.abs());

    List<String> parts = [];
    int i = 0;
    int tempNumber = number;
    while (tempNumber > 0) {
      int threeDigits = tempNumber % 1000;
      if (threeDigits != 0) {
        String s = _threeDigitsToWords(threeDigits);
        if (_thousands[i] != '') {
          s += ' ' + _thousands[i];
        }
        parts.insert(0, s);
      }
      tempNumber ~/= 1000;
      i++;
    }

    return parts.join(' و ');
  }

  static String _threeDigitsToWords(int number) {
    List<String> parts = [];
    int h = number ~/ 100;
    int t = (number % 100) ~/ 10;
    int o = number % 10;

    if (h != 0) parts.add(_hundreds[h]);

    int remainder = number % 100;
    if (remainder >= 10 && remainder < 20) {
      parts.add(_teens[remainder - 10]);
    } else {
      if (t != 0) parts.add(_tens[t]);
      if (o != 0) parts.add(_ones[o]);
    }

    return parts.join(' و ');
  }

  static String formatWithCommas(String input) {
    String s = input.replaceAll(',', '');
    if (s.isEmpty) return '';
    
    if (!RegExp(r'^\d+$').hasMatch(s)) return input;

    final chars = s.split('');
    String result = '';
    for (int i = chars.length - 1, count = 0; i >= 0; i--, count++) {
      if (count > 0 && count % 3 == 0) {
        result = ',' + result;
      }
      result = chars[i] + result;
    }
    return result;
  }
}
