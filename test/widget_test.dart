// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hesabak/main.dart';
import 'package:hesabak/models/contact.dart';
import 'package:hesabak/models/transaction.dart';
import 'package:hesabak/services/database_helper.dart';

class MockDatabaseHelper extends DatabaseHelper {
  MockDatabaseHelper() : super.internal();
  final List<Contact> _mockContacts = [];

  @override
  Future<List<Contact>> getAllContacts() async => _mockContacts;

  @override
  Future<int> insertContact(Contact contact) async {
    _mockContacts.add(contact);
    return 1;
  }
}

void main() {
  setUp(() {
    DatabaseHelper.instance = MockDatabaseHelper();
  });

  testWidgets('App starts and shows empty state', (WidgetTester tester) async {
    await tester.pumpWidget(const HesabakApp());
    await tester.pumpAndSettle();

    expect(find.text('حسابک'), findsOneWidget);
    expect(find.text('هنوز مخاطبی اضافه نشده است'), findsOneWidget);
    expect(find.byIcon(Icons.person_add), findsOneWidget);
  });

  testWidgets('Add contact dialog opens', (WidgetTester tester) async {
    await tester.pumpWidget(const HesabakApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();

    expect(find.text('افزودن مخاطب جدید'), findsOneWidget);
  });
}
