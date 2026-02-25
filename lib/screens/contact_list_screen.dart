import 'package:flutter/material.dart';
import '../models/app_preferences.dart';
import '../models/contact.dart';
import '../models/transaction.dart';
import '../utils/app_text.dart';
import '../utils/persian_utils.dart';
import '../services/database_helper.dart';
import 'settings_screen.dart';
import 'transaction_chat_screen.dart';

class ContactListScreen extends StatefulWidget {
  final Future<void> Function(ThemeMode mode)? onThemeModeChanged;
  final Future<void> Function(AppLanguageMode mode)? onLanguageModeChanged;

  const ContactListScreen({
    super.key,
    this.onThemeModeChanged,
    this.onLanguageModeChanged,
  });

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
  Currency _defaultCurrency = Currency.toman;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  Future<void> _refreshContacts() async {
    final data = await DatabaseHelper.instance.getAllContacts();
    final currency = await DatabaseHelper.instance.getDefaultCurrency();
    setState(() {
      _contacts = data;
      _defaultCurrency = currency;
      _isLoading = false;
    });
  }

  String _currencyLabel() {
    return _defaultCurrency == Currency.toman
        ? AppText.t(context, 'تومان', 'Toman')
        : AppText.t(context, 'ریال', 'Rial');
  }

  String _formatAmount(double amount) {
    final bool isWhole = amount == amount.truncateToDouble();
    return PersianUtils.formatWithCommas(
      isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1),
    );
  }

  void _addNewContact() {
    showDialog(
      context: context,
      builder: (context) {
        String name = '';
        return Directionality(
          textDirection: AppText.direction(context),
          child: AlertDialog(
            title: Text(AppText.t(context, 'افزودن مخاطب جدید', 'Add New Contact')),
            content: TextField(
              onChanged: (value) => name = value,
              autofocus: true,
              decoration: InputDecoration(
                hintText: AppText.t(context, 'نام مخاطب', 'Contact name'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppText.t(context, 'انصراف', 'Cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (name.isNotEmpty) {
                    final newContact = Contact(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      transactions: [],
                    );
                    await DatabaseHelper.instance.insertContact(newContact);
                    if (mounted) Navigator.pop(context);
                    _refreshContacts();
                  }
                },
                child: Text(AppText.t(context, 'تایید', 'Confirm')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteContact(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'حذف مخاطب', 'Delete Contact')),
          content: Text(
            AppText.t(
              context,
              'آیا از حذف "${contact.name}" و تمامی تراکنش‌های آن مطمئن هستید؟',
              'Are you sure you want to delete "${contact.name}" and all its transactions?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteContact(contact.id);
                if (mounted) Navigator.pop(context);
                _refreshContacts();
              },
              child: Text(
                AppText.t(context, 'حذف', 'Delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppText.direction(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppText.t(context, 'حسابک', 'Hesabak')),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      onThemeModeChanged: widget.onThemeModeChanged,
                      onLanguageModeChanged: widget.onLanguageModeChanged,
                    ),
                  ),
                ).then((_) => _refreshContacts());
              },
              icon: const Icon(Icons.settings),
              tooltip: AppText.t(context, 'تنظیمات', 'Settings'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? Center(child: Text(AppText.t(context, 'هنوز مخاطبی اضافه نشده است', 'No contacts yet')))
                : ListView.separated(
                    itemCount: _contacts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final balance = contact.totalBalanceIn(_defaultCurrency);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(contact.name.isNotEmpty ? contact.name[0] : '?'),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(
                          balance == 0
                              ? AppText.t(context, 'تسویه', 'Settled')
                              : (balance > 0
                                  ? '${AppText.t(context, 'طلب شما', 'You are owed')}: ${_formatAmount(balance.abs())} ${_currencyLabel()}'
                                  : '${AppText.t(context, 'بدهی شما', 'You owe')}: ${_formatAmount(balance.abs())} ${_currencyLabel()}'),
                          style: TextStyle(
                            color: balance == 0
                                ? Colors.grey
                                : (balance > 0
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.green.shade300
                                        : Colors.green.shade700)
                                    : (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.red.shade300
                                        : Colors.red.shade700)),
                            fontWeight: balance != 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onLongPress: () => _deleteContact(contact),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TransactionChatScreen(contact: contact),
                            ),
                          ).then((_) => _refreshContacts());
                        },
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewContact,
          tooltip: AppText.t(context, 'افزودن مخاطب', 'Add contact'),
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
