import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/transaction.dart';
import '../utils/persian_utils.dart';
import '../services/database_helper.dart';
import 'settings_screen.dart';
import 'transaction_chat_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

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
    return _defaultCurrency == Currency.toman ? 'تومان' : 'ریال';
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
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('افزودن مخاطب جدید'),
            content: TextField(
              onChanged: (value) => name = value,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'نام مخاطب'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
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
                child: const Text('تایید'),
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
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف مخاطب'),
          content: Text('آیا از حذف "${contact.name}" و تمامی تراکنش‌های آن مطمئن هستید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteContact(contact.id);
                if (mounted) Navigator.pop(context);
                _refreshContacts();
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابک'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                ).then((_) => _refreshContacts());
              },
              icon: const Icon(Icons.settings),
              tooltip: 'تنظیمات',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
                ? const Center(child: Text('هنوز مخاطبی اضافه نشده است'))
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
                              ? 'تسویه'
                              : (balance > 0
                                  ? 'طلب شما: ${_formatAmount(balance.abs())} ${_currencyLabel()}'
                                  : 'بدهی شما: ${_formatAmount(balance.abs())} ${_currencyLabel()}'),
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
          tooltip: 'افزودن مخاطب',
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
