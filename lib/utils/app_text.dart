import 'package:flutter/material.dart';

class AppText {
  static bool isFa(BuildContext context) {
    return Localizations.localeOf(context).languageCode.toLowerCase().startsWith('fa');
  }

  static TextDirection direction(BuildContext context) {
    return isFa(context) ? TextDirection.rtl : TextDirection.ltr;
  }

  static String t(BuildContext context, String fa, String en) {
    return isFa(context) ? fa : en;
  }
}
