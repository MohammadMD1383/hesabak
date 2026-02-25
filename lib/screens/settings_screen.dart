import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../widgets/glass_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Currency _defaultCurrency = Currency.toman;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currency = await DatabaseHelper.instance.getDefaultCurrency();
    if (!mounted) return;

    setState(() {
      _defaultCurrency = currency;
      _isLoading = false;
    });
  }

  Future<void> _updateDefaultCurrency(Currency currency) async {
    await DatabaseHelper.instance.setDefaultCurrency(currency);
    if (!mounted) return;

    setState(() {
      _defaultCurrency = currency;
    });
  }

  Future<String?> _promptForPath({
    required String title,
    required String actionLabel,
    String? initialValue,
    String? helperText,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'مسیر فایل',
                  helperText: helperText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final defaultPath = await DatabaseHelper.instance.getSuggestedBackupPath();
    final path = await _promptForPath(
      title: 'خروجی گرفتن',
      actionLabel: 'ذخیره',
      initialValue: defaultPath,
      helperText: 'مثال: $defaultPath',
    );

    if (path == null || path.isEmpty) return;
    if (!mounted) return;

    setState(() => _isBusy = true);
    try {
      await DatabaseHelper.instance.exportDatabase(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فایل پشتیبان ذخیره شد: $path')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در خروجی گرفتن')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importData() async {
    final path = await _promptForPath(
      title: 'بازیابی',
      actionLabel: 'بازیابی',
      helperText: 'مسیر فایل پشتیبان را وارد کنید',
    );

    if (path == null || path.isEmpty) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تایید بازیابی'),
          content: const Text('تمامی داده‌های فعلی جایگزین خواهند شد. ادامه می‌دهید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بازیابی'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isBusy = true);
    try {
      await DatabaseHelper.instance.importDatabase(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بازیابی انجام شد. برنامه را دوباره باز کنید.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطا در بازیابی')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const GlassAppBar(
          title: Text('تنظیمات'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const ListTile(
                    title: Text('واحد پول پیش‌فرض'),
                  ),
                  RadioListTile<Currency>(
                    value: Currency.toman,
                    groupValue: _defaultCurrency,
                    onChanged: (value) {
                      if (value != null) {
                        _updateDefaultCurrency(value);
                      }
                    },
                    title: const Text('تومان'),
                  ),
                  RadioListTile<Currency>(
                    value: Currency.rial,
                    groupValue: _defaultCurrency,
                    onChanged: (value) {
                      if (value != null) {
                        _updateDefaultCurrency(value);
                      }
                    },
                    title: const Text('ریال'),
                  ),
                  const Divider(height: 24),
                  const ListTile(
                    title: Text('پشتیبان\u200cگیری و بازیابی'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('خروجی گرفتن (Backup)'),
                    onTap: _isBusy ? null : _exportData,
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload),
                    title: const Text('بازیابی (Restore)'),
                    onTap: _isBusy ? null : _importData,
                  ),
                  if (_isBusy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
      ),
    );
  }
}
