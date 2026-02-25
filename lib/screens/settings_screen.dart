import 'package:flutter/material.dart';
import '../models/app_preferences.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';
import '../utils/app_text.dart';
import '../widgets/glass_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  final Future<void> Function(ThemeMode mode)? onThemeModeChanged;
  final Future<void> Function(AppLanguageMode mode)? onLanguageModeChanged;

  const SettingsScreen({
    super.key,
    this.onThemeModeChanged,
    this.onLanguageModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Currency _defaultCurrency = Currency.toman;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguageMode _languageMode = AppLanguageMode.system;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final currency = await DatabaseHelper.instance.getDefaultCurrency();
    final themeMode = await DatabaseHelper.instance.getThemeMode();
    final languageMode = await DatabaseHelper.instance.getLanguageMode();
    if (!mounted) return;

    setState(() {
      _defaultCurrency = currency;
      _themeMode = themeMode;
      _languageMode = languageMode;
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

  Future<void> _updateThemeMode(ThemeMode mode) async {
    await DatabaseHelper.instance.setThemeMode(mode);
    await widget.onThemeModeChanged?.call(mode);
    if (!mounted) return;

    setState(() {
      _themeMode = mode;
    });
  }

  Future<void> _updateLanguageMode(AppLanguageMode mode) async {
    await DatabaseHelper.instance.setLanguageMode(mode);
    await widget.onLanguageModeChanged?.call(mode);
    if (!mounted) return;

    setState(() {
      _languageMode = mode;
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
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: AppText.t(context, 'مسیر فایل', 'File path'),
                  helperText: helperText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
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
      title: AppText.t(context, 'خروجی گرفتن', 'Export'),
      actionLabel: AppText.t(context, 'ذخیره', 'Save'),
      initialValue: defaultPath,
      helperText: '${AppText.t(context, 'مثال', 'Example')}: $defaultPath',
    );

    if (path == null || path.isEmpty) return;
    if (!mounted) return;

    setState(() => _isBusy = true);
    try {
      await DatabaseHelper.instance.exportDatabase(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppText.t(context, 'فایل پشتیبان ذخیره شد', 'Backup saved')}: $path')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t(context, 'خطا در خروجی گرفتن', 'Export failed'))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _importData() async {
    final path = await _promptForPath(
      title: AppText.t(context, 'بازیابی', 'Restore'),
      actionLabel: AppText.t(context, 'بازیابی', 'Restore'),
      helperText: AppText.t(context, 'مسیر فایل پشتیبان را وارد کنید', 'Enter backup file path'),
    );

    if (path == null || path.isEmpty) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: AppText.direction(context),
        child: AlertDialog(
          title: Text(AppText.t(context, 'تایید بازیابی', 'Confirm Restore')),
          content: Text(
            AppText.t(
              context,
              'تمامی داده‌های فعلی جایگزین خواهند شد. ادامه می‌دهید؟',
              'All current data will be replaced. Continue?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppText.t(context, 'انصراف', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppText.t(context, 'بازیابی', 'Restore')),
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
        SnackBar(
          content: Text(
            AppText.t(
              context,
              'بازیابی انجام شد. برنامه را دوباره باز کنید.',
              'Restore completed. Reopen the app.',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.t(context, 'خطا در بازیابی', 'Restore failed'))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppText.direction(context),
      child: Scaffold(
        appBar: GlassAppBar(
          title: Text(AppText.t(context, 'تنظیمات', 'Settings')),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  ListTile(
                    title: Text(AppText.t(context, 'زبان برنامه', 'App Language')),
                  ),
                  RadioListTile<AppLanguageMode>(
                    value: AppLanguageMode.system,
                    groupValue: _languageMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateLanguageMode(value);
                      }
                    },
                    title: Text(AppText.t(context, 'پیش‌فرض سیستم', 'System Default')),
                  ),
                  RadioListTile<AppLanguageMode>(
                    value: AppLanguageMode.en,
                    groupValue: _languageMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateLanguageMode(value);
                      }
                    },
                    title: const Text('English'),
                  ),
                  RadioListTile<AppLanguageMode>(
                    value: AppLanguageMode.fa,
                    groupValue: _languageMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateLanguageMode(value);
                      }
                    },
                    title: const Text('فارسی'),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    title: Text(AppText.t(context, 'تم برنامه', 'Theme')),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: _themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateThemeMode(value);
                      }
                    },
                    title: Text(AppText.t(context, 'پیش‌فرض سیستم', 'System Default')),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: _themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateThemeMode(value);
                      }
                    },
                    title: Text(AppText.t(context, 'روشن', 'Light')),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: _themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        _updateThemeMode(value);
                      }
                    },
                    title: Text(AppText.t(context, 'تاریک', 'Dark')),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    title: Text(AppText.t(context, 'واحد پول پیش‌فرض', 'Default Currency')),
                  ),
                  RadioListTile<Currency>(
                    value: Currency.toman,
                    groupValue: _defaultCurrency,
                    onChanged: (value) {
                      if (value != null) {
                        _updateDefaultCurrency(value);
                      }
                    },
                    title: Text(AppText.t(context, 'تومان', 'Toman')),
                  ),
                  RadioListTile<Currency>(
                    value: Currency.rial,
                    groupValue: _defaultCurrency,
                    onChanged: (value) {
                      if (value != null) {
                        _updateDefaultCurrency(value);
                      }
                    },
                    title: Text(AppText.t(context, 'ریال', 'Rial')),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    title: Text(AppText.t(context, 'پشتیبان‌گیری و بازیابی', 'Backup and Restore')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(AppText.t(context, 'خروجی گرفتن (Backup)', 'Export (Backup)')),
                    onTap: _isBusy ? null : _exportData,
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload),
                    title: Text(AppText.t(context, 'بازیابی (Restore)', 'Import (Restore)')),
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
