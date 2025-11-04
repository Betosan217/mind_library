import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class CompactClockWidget extends StatefulWidget {
  const CompactClockWidget({super.key});

  @override
  State<CompactClockWidget> createState() => _CompactClockWidgetState();
}

class _CompactClockWidgetState extends State<CompactClockWidget> {
  late Timer _clockTimer;
  Timer? _pomodoroTimer;
  DateTime _currentTime = DateTime.now();
  bool _isExpanded = false;

  // Pomodoro variables
  int _pomodoroMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _pomodoroTimer?.cancel();
    super.dispose();
  }

  void _startPomodoro() {
    setState(() {
      _isRunning = true;
      _remainingSeconds = _pomodoroMinutes * 60;
    });

    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _stopPomodoro();
        }
      });
    });
  }

  void _stopPomodoro() {
    _pomodoroTimer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetPomodoro() {
    _pomodoroTimer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _pomodoroMinutes * 60;
    });
  }

  void _incrementMinutes() {
    if (_pomodoroMinutes < 60 && !_isRunning) {
      setState(() {
        _pomodoroMinutes++;
        _remainingSeconds = _pomodoroMinutes * 60;
      });
    }
  }

  void _decrementMinutes() {
    if (_pomodoroMinutes > 1 && !_isRunning) {
      setState(() {
        _pomodoroMinutes--;
        _remainingSeconds = _pomodoroMinutes * 60;
      });
    }
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        constraints: BoxConstraints(
          minWidth: 50,
          maxWidth: _isExpanded ? 200 : 50,
        ),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _isExpanded ? _buildExpandedPomodoro() : _buildCompactClock(),
      ),
    );
  }

  Widget _buildCompactClock() {
    return Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CustomPaint(painter: MiniClockPainter(_currentTime)),
      ),
    );
  }

  Widget _buildExpandedPomodoro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clock icon
          SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(painter: MiniClockPainter(_currentTime)),
          ),
          const SizedBox(width: 8),
          // Pomodoro controls
          if (!_isRunning) ...[
            // Decrement button
            _buildSmallButton(Icons.remove, _decrementMinutes),
            const SizedBox(width: 4),
          ],
          // Time display
          Text(
            _isRunning
                ? _formatTime(_remainingSeconds)
                : '$_pomodoroMinutes:00',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          if (!_isRunning) ...[
            // Increment button
            _buildSmallButton(Icons.add, _incrementMinutes),
            const SizedBox(width: 4),
          ],
          // Play/Pause button
          _buildSmallButton(
            _isRunning ? Icons.pause : Icons.play_arrow,
            _isRunning ? _stopPomodoro : _startPomodoro,
          ),
          if (_isRunning) ...[
            const SizedBox(width: 4),
            _buildSmallButton(Icons.stop, _resetPomodoro),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 14),
      ),
    );
  }
}

class MiniClockPainter extends CustomPainter {
  final DateTime time;

  MiniClockPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final center = Offset(centerX, centerY);
    final radius = min(centerX, centerY);

    // Clock background
    final fillBrush = Paint()..color = const Color(0xFF2A2A2A);
    canvas.drawCircle(center, radius, fillBrush);

    // Clock border
    final outlineBrush = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 1, outlineBrush);

    // Hour marks (only 12, 3, 6, 9)
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - 90) * pi / 180;
      final x1 = centerX + (radius - 3) * cos(angle);
      final y1 = centerY + (radius - 3) * sin(angle);
      final x2 = centerX + (radius - 5) * cos(angle);
      final y2 = centerY + (radius - 5) * sin(angle);

      final hourMarkBrush = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), hourMarkBrush);
    }

    // Hour hand
    final hourAngle =
        ((time.hour % 12) * 30 + time.minute * 0.5 - 90) * pi / 180;
    final hourHandBrush = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        centerX + (radius - 8) * cos(hourAngle),
        centerY + (radius - 8) * sin(hourAngle),
      ),
      hourHandBrush,
    );

    // Minute hand
    final minuteAngle = (time.minute * 6 - 90) * pi / 180;
    final minuteHandBrush = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        centerX + (radius - 5) * cos(minuteAngle),
        centerY + (radius - 5) * sin(minuteAngle),
      ),
      minuteHandBrush,
    );

    // Center dot
    final centerDotBrush = Paint()..color = Colors.red;
    canvas.drawCircle(center, 2, centerDotBrush);
  }

  @override
  bool shouldRepaint(MiniClockPainter oldDelegate) => true;
}
