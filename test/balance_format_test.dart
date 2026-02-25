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

  @override
  Future<int> insertTransaction(FinancialTransaction transaction, String contactId) async {
    // In the mock, we don't need to add it here because the screen adds it to the same object
    return 1;
  }
}

void main() {
  setUp(() {
    DatabaseHelper.instance = MockDatabaseHelper();
  });

  testWidgets('Balance format check in ContactListScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const HesabakApp());
    await tester.pumpAndSettle();

    // Add a contact first
    await tester.tap(find.byIcon(Icons.person_add));
    await tester.pumpAndSettle();
    
    // Find the TextField in the dialog
    final nameField = find.byType(TextField);
    expect(nameField, findsOneWidget);
    await tester.enterText(nameField, 'محمد');
    
    await tester.tap(find.text('تایید'));
    await tester.pumpAndSettle();

    // Check if the contact 'محمد' is shown
    expect(find.text('محمد'), findsOneWidget);
    
    // Tap on the contact (محمد)
    await tester.tap(find.text('محمد'));
    await tester.pumpAndSettle();

    // Now on TransactionChatScreen
    // Find amount field
    final amountField = find.byType(TextField).at(0);
    await tester.enterText(amountField, '10000');
    
    // Tap send button
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    // Check if message is in the chat
    // It appears twice: once in the bubble and once in the balance summary in AppBar
    expect(find.textContaining('10,000'), findsNWidgets(2));

    // Go back
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Check if balance is formatted correctly
    expect(find.textContaining('10,000'), findsOneWidget);
    expect(find.textContaining('بدهی شما'), findsOneWidget);
  });
}
