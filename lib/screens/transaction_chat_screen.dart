import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact.dart';
import '../models/transaction.dart';
import '../utils/app_text.dart';
import '../utils/persian_utils.dart';
import '../utils/currency_formatter.dart';
import '../services/database_helper.dart';

class TransactionChatScreen extends StatefulWidget {
  final Contact contact;

  const TransactionChatScreen({super.key, required this.contact});

  @override
  State<TransactionChatScreen> createState() => _TransactionChatScreenState();
}

class _TransactionChatScreenState extends State<TransactionChatScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  TransactionType _selectedType = TransactionType.debt;
  Currency _selectedCurrency = Currency.toman;
  Currency _defaultCurrency = Currency.toman;
  bool _isSettingsLoading = true;
  String _amountInWords = '';

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateAmountInWords);
    _loadDefaultCurrency();
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateAmountInWords);
    _amountController.dispose();
    _descriptionController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_messagesScrollController.hasClients) return;
    _messagesScrollController.animateTo(
      _messagesScrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _updateAmountInWords() {
    final String text = _amountController.text.replaceAll(',', '');
    if (text.isEmpty) {
      setState(() => _amountInWords = '');
      return;
    }

    final int? amount = int.tryParse(text);
    if (amount != null) {
      setState(() {
        _amountInWords =
            PersianUtils.numberToWords(amount) + _selectedCurrencyLabelWithSpace();
      });
    } else {
      setState(() => _amountInWords = '');
    }
  }

  Future<void> _loadDefaultCurrency() async {
    final currency = await DatabaseHelper.instance.getDefaultCurrency();
    if (!mounted) return;

    setState(() {
      _defaultCurrency = currency;
      _selectedCurrency = currency;
      _isSettingsLoading = false;
    });
    _updateAmountInWords();
  }

  String _currencyLabel() {
    return _defaultCurrency == Currency.toman
        ? AppText.t(context, 'تومان', 'Toman')
        : AppText.t(context, 'ریال', 'Rial');
  }

  String _currencyLabelWithSpace() {
    return _defaultCurrency == Currency.toman ? ' تومان' : ' ریال';
  }

  String _selectedCurrencyLabelWithSpace() {
    return _selectedCurrency == Currency.toman
        ? ' ${AppText.t(context, 'تومان', 'Toman')}'
        : ' ${AppText.t(context, 'ریال', 'Rial')}';
  }

  String _formatAmount(double amount) {
    final bool isWhole = amount == amount.truncateToDouble();
    return PersianUtils.formatWithCommas(
      isWhole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1),
    );
  }

  List<FinancialTransaction> _sortedTransactions() {
    final sorted = List<FinancialTransaction>.from(widget.contact.transactions)
      ..sort((a, b) {
        final byDate = a.dateTime.compareTo(b.dateTime);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  void _addTransaction() async {
    FinancialTransaction? newTransaction;

    if (_selectedType == TransactionType.event) {
      if (_descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.t(context, 'لطفاً متن رویداد را وارد کنید', 'Please enter event text'))),
        );
        return;
      }

      newTransaction = FinancialTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: TransactionType.event,
        description: _descriptionController.text.trim(),
        dateTime: DateTime.now(),
      );
    } else {
      final String text = _amountController.text.replaceAll(',', '');
      final double? enteredAmount = double.tryParse(text);
      if (enteredAmount == null || enteredAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.t(context, 'لطفاً مبلغ معتبری وارد کنید', 'Please enter a valid amount'))),
        );
        return;
      }

      final convertedAmount = convertCurrencyAmount(
        enteredAmount,
        _selectedCurrency,
        Currency.rial,
      );

      newTransaction = FinancialTransaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: convertedAmount,
        currency: Currency.rial,
        type: _selectedType,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        dateTime: DateTime.now(),
      );
    }

    if (newTransaction != null) {
      await DatabaseHelper.instance.insertTransaction(newTransaction, widget.contact.id);
      setState(() {
        widget.contact.transactions.add(newTransaction!);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    _amountController.clear();
    _descriptionController.clear();
    FocusScope.of(context).unfocus();
  }

  void _deleteTransaction(FinancialTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'حذف تراکنش', 'Delete Transaction')),
          content: Text(AppText.t(context, 'آیا از حذف این تراکنش مطمئن هستید؟', 'Are you sure you want to delete this transaction?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
            ),
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteTransaction(transaction.id);
                setState(() {
                  widget.contact.transactions.removeWhere((t) => t.id == transaction.id);
                });
                if (mounted) Navigator.pop(context);
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

  void _showTransactionMenu(FinancialTransaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(AppText.t(context, 'حذف', 'Delete')),
                onTap: () {
                  Navigator.pop(context);
                  _deleteTransaction(transaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(AppText.t(context, 'ویرایش', 'Edit')),
                onTap: () {
                  Navigator.pop(context);
                  _editTransaction(transaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: Text(AppText.t(context, 'نمایش وضعیت تا اینجا', 'View State Up To Here')),
                onTap: () {
                  Navigator.pop(context);
                  _showStateUpTo(transaction);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editTransaction(FinancialTransaction transaction) async {
    if (transaction.type == TransactionType.event) {
      await _editEventTransaction(transaction);
      return;
    }

    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController(
      text: transaction.description ?? '',
    );

    Currency editCurrency = _defaultCurrency;
    final double initialAmount = transaction.amountInCurrency(editCurrency);
    amountController.text = _formatAmount(initialAmount);
    String amountInWords = '';

    void updateAmountInWords() {
      final raw = amountController.text.replaceAll(',', '');
      if (raw.isEmpty) {
        amountInWords = '';
        return;
      }

      final int? value = int.tryParse(raw);
      if (value == null) {
        amountInWords = '';
        return;
      }

      amountInWords = PersianUtils.numberToWords(value) +
          (editCurrency == Currency.toman
              ? ' ${AppText.t(context, 'تومان', 'Toman')}'
              : ' ${AppText.t(context, 'ریال', 'Rial')}');
    }

    updateAmountInWords();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'ویرایش تراکنش', 'Edit Transaction')),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (amountInWords.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      amountInWords,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.teal.shade300
                            : Colors.teal.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyTextInputFormatter(),
                  ],
                  onChanged: (_) {
                    setDialogState(() {
                      updateAmountInWords();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: AppText.t(context, 'مبلغ', 'Amount'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<Currency>(
                  value: editCurrency,
                  underline: Container(),
                  onChanged: (Currency? newValue) {
                    if (newValue != null) {
                      setDialogState(() {
                        editCurrency = newValue;
                        updateAmountInWords();
                      });
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: Currency.toman,
                      child: Text(AppText.t(context, 'تومان', 'Toman')),
                    ),
                    DropdownMenuItem(
                      value: Currency.rial,
                      child: Text(AppText.t(context, 'ریال', 'Rial')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    hintText: AppText.t(context, 'توضیحات اختیاری...', 'Optional description...'),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.t(context, 'ذخیره', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final String raw = amountController.text.replaceAll(',', '');
    final double? enteredAmount = double.tryParse(raw);
    if (enteredAmount == null || enteredAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t(context, 'لطفاً مبلغ معتبری وارد کنید', 'Please enter a valid amount'))),
      );
      return;
    }

    final convertedAmount =
        convertCurrencyAmount(enteredAmount, editCurrency, Currency.rial);

    final updated = FinancialTransaction(
      id: transaction.id,
      amount: convertedAmount,
      currency: Currency.rial,
      type: transaction.type,
      description: descriptionController.text.isEmpty ? null : descriptionController.text,
      dateTime: transaction.dateTime,
    );

    await DatabaseHelper.instance.updateTransaction(updated, widget.contact.id);
    setState(() {
      final index = widget.contact.transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        widget.contact.transactions[index] = updated;
      }
    });
  }

  Future<void> _editEventTransaction(FinancialTransaction transaction) async {
    final TextEditingController descriptionController = TextEditingController(
      text: transaction.description ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'ویرایش رویداد', 'Edit Event')),
          content: TextField(
            controller: descriptionController,
            decoration: InputDecoration(
              hintText: AppText.t(context, 'متن رویداد...', 'Event text...'),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.t(context, 'ذخیره', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final text = descriptionController.text.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t(context, 'لطفاً متن رویداد را وارد کنید', 'Please enter event text'))),
      );
      return;
    }

    final updated = FinancialTransaction(
      id: transaction.id,
      amount: transaction.amount,
      currency: transaction.currency,
      type: transaction.type,
      description: text,
      dateTime: transaction.dateTime,
    );

    await DatabaseHelper.instance.updateTransaction(updated, widget.contact.id);
    setState(() {
      final index = widget.contact.transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        widget.contact.transactions[index] = updated;
      }
    });
  }

  void _showStateUpTo(FinancialTransaction transaction) {
    final sorted = _sortedTransactions();
    final index = sorted.indexWhere((t) => t.id == transaction.id);
    if (index == -1) return;

    double totalCredit = 0;
    double totalDebt = 0;
    for (var i = 0; i <= index; i++) {
      final t = sorted[i];
      if (t.type == TransactionType.event) continue;
      final amount = t.amountInCurrency(_defaultCurrency);
      if (t.type == TransactionType.credit) {
        totalCredit += amount;
      } else {
        totalDebt += amount;
      }
    }

    final net = totalCredit - totalDebt;
    final netLabel = net == 0
        ? AppText.t(context, 'تسویه', 'Settled')
        : (net > 0 ? AppText.t(context, 'طلب شما', 'You are owed') : AppText.t(context, 'بدهی شما', 'You owe'));
    final netValue = net == 0 ? '' : '${_formatAmount(net.abs())} ${_currencyLabel()}';

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'وضعیت تا اینجا', 'State Up To Here')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${AppText.t(context, 'جمع بستانکاری', 'Total credit')}: ${_formatAmount(totalCredit)} ${_currencyLabel()}'),
              const SizedBox(height: 6),
              Text('${AppText.t(context, 'جمع بدهکاری', 'Total debt')}: ${_formatAmount(totalDebt)} ${_currencyLabel()}'),
              const Divider(height: 16),
              Text(
                net == 0 ? netLabel : '$netLabel: $netValue',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.t(context, 'بستن', 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> _getGroupedItems() {
    final List<dynamic> items = [];
    String? previousDate;

    // Newest first for reversed chat list.
    final sortedTransactions = List<FinancialTransaction>.from(widget.contact.transactions)
      ..sort((a, b) {
        final byDate = b.dateTime.compareTo(a.dateTime);
        if (byDate != 0) return byDate;
        return b.id.compareTo(a.id);
      });

    for (int i = 0; i < sortedTransactions.length; i++) {
      final t = sortedTransactions[i];
      final dateStr = _getDateString(t.dateTime);
      if (previousDate == null || previousDate == dateStr) {
        items.add(t);
      } else {
        // Place date separator between day groups in bottom-to-top layout.
        items.add(previousDate);
        items.add(t);
      }
      previousDate = dateStr;
    }

    if (previousDate != null) {
      items.add(previousDate);
    }

    return items;
  }

  String _getDateString(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return AppText.t(context, 'امروز', 'Today');
    if (d == yesterday) return AppText.t(context, 'دیروز', 'Yesterday');
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingsLoading) {
      return Directionality(
        textDirection: AppText.direction(context),
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final groupedItems = _getGroupedItems();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = widget.contact.totalBalanceIn(_defaultCurrency);

    return Directionality(
      textDirection: AppText.direction(context),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.contact.name),
              Text(
                balance == 0
                    ? AppText.t(context, 'تسویه', 'Settled')
                    : (balance > 0
                        ? '${AppText.t(context, 'طلب شما', 'You are owed')}: ${_formatAmount(balance.abs())} ${_currencyLabel()}'
                        : '${AppText.t(context, 'بدهی شما', 'You owe')}: ${_formatAmount(balance.abs())} ${_currencyLabel()}'),
                style: TextStyle(
                  fontSize: 11,
                  color: balance == 0
                      ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
                      : (balance > 0
                          ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                          : (isDark ? Colors.red.shade300 : Colors.red.shade700)),
                  fontWeight: balance != 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: widget.contact.transactions.isEmpty
                  ? Center(
                      child: Text(
                        AppText.t(context, 'هنوز تراکنشی ثبت نشده است', 'No transactions yet'),
                        style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      controller: _messagesScrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: groupedItems.length,
                      itemBuilder: (context, index) {
                        final item = groupedItems[index];

                        if (item is String) {
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blueGrey.withOpacity(0.3)
                                    : Colors.blueGrey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.blueGrey.shade200
                                      : Colors.blueGrey.shade700,
                                ),
                              ),
                            ),
                          );
                        }

                        final t = item as FinancialTransaction;

                        if (t.type == TransactionType.event) {
                          return Center(
                            child: GestureDetector(
                              onTap: () => _showTransactionMenu(t),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey.withOpacity(0.2)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  t.description ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final isDebt = t.type == TransactionType.debt;

                        final bubbleBg = isDebt
                            ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50)
                            : (isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50);
                        final bubbleBorder = isDebt
                            ? (isDark ? Colors.red.shade800 : Colors.red.shade200)
                            : (isDark ? Colors.green.shade800 : Colors.green.shade200);
                        final amountColor = isDebt
                            ? (isDark ? Colors.red.shade200 : Colors.red.shade900)
                            : (isDark ? Colors.green.shade200 : Colors.green.shade900);
                        final textColor = isDark ? Colors.white70 : Colors.black87;
                        final timeColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

                        return Align(
                          alignment: isDebt ? Alignment.centerLeft : Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _showTransactionMenu(t),
                            child: UnconstrainedBox(
                              alignment: isDebt ? Alignment.centerLeft : Alignment.centerRight,
                              constrainedAxis: Axis.vertical,
                              child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                                minWidth: 80,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bubbleBg,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isDebt ? Radius.zero : const Radius.circular(16),
                                  bottomRight: isDebt ? const Radius.circular(16) : Radius.zero,
                                ),
                                border: Border.all(
                                  color: bubbleBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_formatAmount(t.amountInCurrency(_defaultCurrency))} ${_currencyLabel()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: amountColor,
                                    ),
                                  ),
                                  if (t.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      t.description!,
                                      style: TextStyle(fontSize: 14, color: textColor),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Text(
                                      '${t.dateTime.hour.toString().padLeft(2, '0')}:${t.dateTime.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 10, color: timeColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_amountInWords.isNotEmpty && _selectedType != TransactionType.event)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                _amountInWords,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.teal.shade300 : Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            children: [
              if (_selectedType != TransactionType.event) ...[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyTextInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: AppText.t(context, 'مبلغ', 'Amount'),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<Currency>(
                  value: _selectedCurrency,
                  underline: Container(),
                  onChanged: (Currency? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCurrency = newValue);
                      _updateAmountInWords();
                    }
                  },
                  items: [
                    DropdownMenuItem(
                      value: Currency.toman,
                      child: Text(AppText.t(context, 'تومان', 'Toman')),
                    ),
                    DropdownMenuItem(
                      value: Currency.rial,
                      child: Text(AppText.t(context, 'ریال', 'Rial')),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              DropdownButton<TransactionType>(
                value: _selectedType,
                underline: Container(),
                onChanged: (TransactionType? newValue) {
                  if (newValue != null) setState(() => _selectedType = newValue);
                },
                items: [
                  DropdownMenuItem(
                    value: TransactionType.debt,
                    child: Text(AppText.t(context, 'بدهکار', 'Debt'),
                        style: TextStyle(
                            color: isDark ? Colors.red.shade300 : Colors.red)),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.credit,
                    child: Text(AppText.t(context, 'بستانکار', 'Credit'),
                        style: TextStyle(
                            color: isDark ? Colors.green.shade300 : Colors.green)),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.event,
                    child: Text(AppText.t(context, 'رویداد', 'Event'),
                        style: TextStyle(
                            color: isDark ? Colors.grey.shade400 : Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: _selectedType == TransactionType.event
                        ? AppText.t(context, 'متن رویداد...', 'Event text...')
                        : AppText.t(context, 'توضیحات اختیاری...', 'Optional description...'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: IconButton(
                  onPressed: _addTransaction,
                  icon: const Icon(Icons.send),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
