import 'package:flutter/material.dart';
import 'package:zettaialarm222/services/alarm_service.dart';
import 'package:zettaialarm222/services/quiz_service.dart';

/// アラーム鳴動中に表示されるクイズ画面。
/// 正解するまで戻ることも音を止めることもできない。
class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage>
    with SingleTickerProviderStateMixin {
  Quiz? _quiz;
  bool _loading = true;
  bool _solved = false;
  int? _wrongIndex;
  int _wrongCount = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.92,
      upperBound: 1.08,
    )..repeat(reverse: true);
    _loadQuiz();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loading = true;
      _wrongIndex = null;
    });
    final quiz = await QuizService.instance.generate();
    if (mounted) {
      setState(() {
        _quiz = quiz;
        _loading = false;
      });
    }
  }

  Future<void> _answer(int index) async {
    final quiz = _quiz;
    if (_solved || _loading || quiz == null) return;
    if (index == quiz.correctIndex) {
      setState(() => _solved = true);
      _pulse.stop();
      await AlarmService.instance.stopRinging();
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _wrongIndex = index;
        _wrongCount++;
      });
      if (_wrongCount % 3 == 0) {
        // 3回間違えたら問題を切り替えて総当たりを防ぐ
        await _loadQuiz();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _solved,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _solved
                  ? const [Color(0xFF11301F), Color(0xFF0A1410)]
                  : const [Color(0xFF3B1020), Color(0xFF14090F)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _solved ? _solvedView() : _quizView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _solvedView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 96, color: Color(0xFF5DD39E)),
        const SizedBox(height: 24),
        const Text(
          'アラーム停止!',
          style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          'おはようございます ☀️',
          style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _quizView() {
    return Column(
      children: [
        const Spacer(),
        ScaleTransition(
          scale: _pulse,
          child: const Icon(Icons.alarm_rounded,
              size: 72, color: Color(0xFFFF6B6B)),
        ),
        const SizedBox(height: 16),
        const Text(
          '起きる時間です!',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          '問題に正解するとアラームが止まります',
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 28),
        _quizCard(),
        const Spacer(),
        TextButton.icon(
          onPressed: _loading ? null : _loadQuiz,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('別の問題にする'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _quizCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('問題を作成中...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _quiz!.question,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _quiz!.choices.length; i++)
                  _choiceButton(i),
                if (_wrongIndex != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '不正解!もう一度考えてみましょう',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFFF8A8A), fontSize: 13),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _choiceButton(int i) {
    final isWrong = _wrongIndex == i;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: FilledButton.tonal(
        onPressed: () => _answer(i),
        style: FilledButton.styleFrom(
          backgroundColor: isWrong
              ? const Color(0xFFB33A3A).withOpacity(0.45)
              : Colors.white.withOpacity(0.12),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          _quiz!.choices[i],
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
