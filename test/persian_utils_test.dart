import 'package:flutter_test/flutter_test.dart';
import 'package:hesabak/utils/persian_utils.dart';

void main() {
  group('PersianUtils Tests', () {
    test('numberToWords converts correctly', () {
      expect(PersianUtils.numberToWords(0), 'صفر');
      expect(PersianUtils.numberToWords(123), 'صد و بیست و سه');
      expect(PersianUtils.numberToWords(1000), 'یک هزار');
      expect(PersianUtils.numberToWords(1001), 'یک هزار و یک');
      expect(PersianUtils.numberToWords(1100), 'یک هزار و صد');
      expect(PersianUtils.numberToWords(1234567), 'یک میلیون و دویست و سی و چهار هزار و پانصد و شصت و هفت');
    });

    test('formatWithCommas formats correctly', () {
      expect(PersianUtils.formatWithCommas('123'), '123');
      expect(PersianUtils.formatWithCommas('1234'), '1,234');
      expect(PersianUtils.formatWithCommas('1234567'), '1,234,567');
      expect(PersianUtils.formatWithCommas(''), '');
    });
  });
}
