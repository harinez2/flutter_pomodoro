import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ポモドーロタイマー',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const TimerSettingsScreen(),
    );
  }
}

class TimerSettingsScreen extends StatefulWidget {
  const TimerSettingsScreen({super.key});

  @override
  State<TimerSettingsScreen> createState() => _TimerSettingsScreenState();
}

class _TimerSettingsScreenState extends State<TimerSettingsScreen>
    with SingleTickerProviderStateMixin {
  int workDuration = 25;
  int breakDuration = 5;
  int pomodorosUntilLongBreak = 4;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          PomodoroTimer(
            workDuration: workDuration * 60,
            shortBreakDuration: breakDuration * 60,
            longBreakDuration: breakDuration * 2 * 60,
            pomodorosUntilLongBreak: pomodorosUntilLongBreak,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('作業時間'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (workDuration > 5) {
                                  setState(() {
                                    workDuration -= 5;
                                  });
                                }
                              },
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: workDuration.toString()),
                                onChanged: (value) {
                                  final newValue = int.tryParse(value);
                                  if (newValue != null && newValue > 0) {
                                    setState(() {
                                      workDuration = newValue;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  suffixText: '分',
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  workDuration += 5;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('休憩時間'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (breakDuration > 1) {
                                  setState(() {
                                    breakDuration -= 1;
                                  });
                                }
                              },
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(
                                    text: breakDuration.toString()),
                                onChanged: (value) {
                                  final newValue = int.tryParse(value);
                                  if (newValue != null && newValue > 0) {
                                    setState(() {
                                      breakDuration = newValue;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  suffixText: '分',
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  breakDuration += 1;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.timer)),
          Tab(icon: Icon(Icons.settings)),
        ],
      ),
    );
  }
}

class PomodoroTimer extends StatefulWidget {
  final int workDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final int pomodorosUntilLongBreak;

  const PomodoroTimer({
    super.key,
    required this.workDuration,
    required this.shortBreakDuration,
    required this.longBreakDuration,
    required this.pomodorosUntilLongBreak,
  });

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer>
    with SingleTickerProviderStateMixin {
  late int _timeLeft;
  int _pomodoroCount = 0;
  bool _isRunning = false;
  Timer? _timer;
  bool _isWorkTime = true;
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _todayCompletedCount = 0;
  int _yesterdayCompletedCount = 0;
  String _lastCompletedDate = '';
  final List<String> _encouragingMessages = [
    'がんばろう！',
    '集中しよう！',
    'あと少し！',
    '頑張って！',
    '集中力が高まってる！',
    '素晴らしい！',
    'その調子！',
    '一歩一歩進もう！',
  ];
  String _currentMessage = '';

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.workDuration;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.workDuration),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);
    _loadCompletedCount();
    _updateMessage();
  }

  Future<void> _loadCompletedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    setState(() {
      _lastCompletedDate = prefs.getString('lastCompletedDate') ?? '';
      if (_lastCompletedDate == today) {
        _todayCompletedCount = prefs.getInt('todayCompletedCount') ?? 0;
      } else if (_lastCompletedDate == yesterday) {
        _yesterdayCompletedCount = prefs.getInt('todayCompletedCount') ?? 0;
        _todayCompletedCount = 0;
      } else {
        _todayCompletedCount = 0;
        _yesterdayCompletedCount = 0;
      }
    });
  }

  Future<void> _saveCompletedCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await prefs.setString('lastCompletedDate', today);
    await prefs.setInt('todayCompletedCount', _todayCompletedCount);
  }

  void _updateMessage() {
    if (!_isRunning) {
      _currentMessage = 'Ready';
    } else if (!_isWorkTime) {
      _currentMessage = '休憩中';
    } else {
      _currentMessage = _encouragingMessages[
          math.Random().nextInt(_encouragingMessages.length)];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _updateMessage();
    });

    _animationController.duration = Duration(seconds: _timeLeft);
    _animationController.forward(
        from: 1 -
            (_timeLeft /
                (_isWorkTime
                    ? widget.workDuration
                    : widget.shortBreakDuration)));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          _handleTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
      _animationController.stop();
      _updateMessage();
    });
    _timer?.cancel();
  }

  void _resetTimer() {
    setState(() {
      _isRunning = false;
      _timeLeft = _isWorkTime ? widget.workDuration : widget.shortBreakDuration;
      _animationController.reset();
      _updateMessage();
    });
    _timer?.cancel();
  }

  void _handleTimerComplete() {
    if (_isWorkTime) {
      _pomodoroCount++;
      setState(() {
        _todayCompletedCount++;
      });
      _saveCompletedCount();
      if (_pomodoroCount % widget.pomodorosUntilLongBreak == 0) {
        _timeLeft = widget.longBreakDuration;
      } else {
        _timeLeft = widget.shortBreakDuration;
      }
      _isWorkTime = false;
    } else {
      _timeLeft = widget.workDuration;
      _isWorkTime = true;
    }

    _animationController.duration = Duration(seconds: _timeLeft);
    _animationController.reset();
    _updateMessage();

    if (!_isRunning) {
      _startTimer();
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _animation.value,
                      strokeWidth: 10,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isWorkTime ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(_timeLeft),
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentMessage,
                        style: TextStyle(
                          fontSize: 20,
                          color: _isRunning
                              ? (_isWorkTime ? Colors.red : Colors.green)
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                onPressed: _isRunning ? _pauseTimer : _startTimer,
                iconSize: 48,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetTimer,
                iconSize: 48,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '本日の完了数: $_todayCompletedCount',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '昨日の完了数: $_yesterdayCompletedCount',
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}
