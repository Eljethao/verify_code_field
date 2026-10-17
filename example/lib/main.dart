import 'package:flutter/material.dart';
import 'package:verify_code_field/verify_code_field.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF4F46E5);
    return MaterialApp(
      title: 'verify_code_field',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: const VerifyPage(),
    );
  }
}

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _controller = TextEditingController();
  int _length = 6;
  VerifyCodeShape _shape = VerifyCodeShape.outlined;
  bool _obscure = false;
  bool _checking = false;
  bool _verified = false;
  String? _error;
  String? _appSignature;

  /// The demo accepts 1234, 12345, 123456 or 12345678.
  String get _expected => '12345678'.substring(0, _length);

  @override
  void initState() {
    super.initState();
    // Android only: the hash to put at the end of the SMS for SmsAutofill.retriever.
    SmsCodeListener.appSignature().then((hash) {
      if (mounted && hash != null) setState(() => _appSignature = hash);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    setState(() {
      _checking = true;
      _error = null;
    });
    await Future<void>.delayed(
      const Duration(milliseconds: 700),
    ); // Your API call.
    if (!mounted) return;
    setState(() {
      _checking = false;
      if (code == _expected) {
        _verified = true;
      } else {
        _error = 'That code is not correct. Please try again.';
      }
    });
  }

  void _reset({int? length}) {
    _controller.clear();
    setState(() {
      if (length != null) _length = length;
      _error = null;
      _verified = false;
    });
  }

  void _resend() {
    _reset();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sms_outlined,
                        color: cs.onPrimaryContainer,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter verification code',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a $_length-digit code to +856 20 •••• 1234',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  VerifyCodeField(
                    length: _length,
                    controller: _controller,
                    autofocus: true,
                    obscureText: _obscure,
                    readOnly: _checking || _verified,
                    style: VerifyCodeStyle(shape: _shape),
                    errorText: _error,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onCompleted: _verify,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(height: 48, child: Center(child: _status(theme))),
                  const SizedBox(height: 8),
                  Text(
                    'Demo: the correct code is $_expected',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  _Option(
                    label: 'Boxes',
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 4, label: Text('4')),
                        ButtonSegment(value: 5, label: Text('5')),
                        ButtonSegment(value: 6, label: Text('6')),
                        ButtonSegment(value: 8, label: Text('8')),
                      ],
                      selected: {_length},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => _reset(length: s.first),
                    ),
                  ),
                  _Option(
                    label: 'Style',
                    child: SegmentedButton<VerifyCodeShape>(
                      segments: const [
                        ButtonSegment(
                          value: VerifyCodeShape.outlined,
                          label: Text('Outlined'),
                        ),
                        ButtonSegment(
                          value: VerifyCodeShape.filled,
                          label: Text('Filled'),
                        ),
                        ButtonSegment(
                          value: VerifyCodeShape.underline,
                          label: Text('Line'),
                        ),
                      ],
                      selected: {_shape},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _shape = s.first),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide code'),
                    value: _obscure,
                    onChanged: (v) => setState(() => _obscure = v),
                  ),
                  if (_appSignature != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('App hash for SMS Retriever'),
                      subtitle: SelectableText(_appSignature!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(ThemeData theme) {
    if (_checking) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (_verified) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Text('Verified', style: theme.textTheme.titleMedium),
          const SizedBox(width: 12),
          TextButton(onPressed: _reset, child: const Text('Start over')),
        ],
      );
    }
    return TextButton(
      onPressed: _resend,
      child: const Text("Didn't get a code? Resend"),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(child: child),
            ),
          ),
        ],
      ),
    );
  }
}
