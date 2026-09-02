import 'package:flutter/material.dart';
import 'package:zettaialarm222/services/quiz_service.dart';

/// OpenAI APIキーの設定画面。
/// キーは端末内(SharedPreferences)にのみ保存され、リポジトリには含めない。
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await QuizService.instance.loadApiKey();
    if (mounted) setState(() => _controller.text = key);
  }

  Future<void> _save() async {
    await QuizService.instance.saveApiKey(_controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('APIキーを保存しました')),
    );
  }

  Future<void> _clear() async {
    _controller.clear();
    await QuizService.instance.saveApiKey('');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('APIキーを削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'AIクイズ(OpenAI APIキー)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'APIキーを設定すると、アラーム停止時にAIが毎回新しいクイズを出題します。'
                  '未設定・オフラインのときは計算問題が出題されます。',
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.white.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'sk- から始まるAPIキー',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('保存'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('削除'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline,
                  size: 16, color: Colors.white.withOpacity(0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'APIキーはこの端末の中にだけ保存されます。他人と共有したり、コードやリポジトリに書き込んだりしないでください。',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.white.withOpacity(0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
