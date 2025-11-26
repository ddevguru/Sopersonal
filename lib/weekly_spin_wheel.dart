import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WeeklySpinWheelDialog extends StatefulWidget {
  final Map<String, dynamic> eligibility;
  final Function(String, String?) onSpinComplete;

  const WeeklySpinWheelDialog({
    Key? key,
    required this.eligibility,
    required this.onSpinComplete,
  }) : super(key: key);

  @override
  State<WeeklySpinWheelDialog> createState() => _WeeklySpinWheelDialogState();
}

class _WeeklySpinWheelDialogState extends State<WeeklySpinWheelDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;

  // Rewards list (8 segments)
  final List<String> visualRewards = [
    "Alexa",
    "Gift Card",
    "Bag Pack",
    "Mini \nDrone",
    "Smart \nWatch",
    "Better Luck\nNext Time",
    "Mobile\nRecharge",
    "Bluetooth",
  ];

  // Custom list of colors (8 colors for 8 segments)
  final List<Color> segmentColors = [
    const Color(0xFF00CED1), // Bright Cyan/Blue for Alexa
    const Color(0xFF2C7D64), // Dark Green (Gift Card)
    const Color(0xFF4C87C2), // Blue (Bag Pack)
    const Color(0xFF903B91), // Purple (Mini Drone)
    const Color(0xFFC42D3B), // Red (Smart Watch)
    const Color(0xFFC8821B), // Orange/Gold (Better Luck)
    const Color(0xFF4C87C2), // Blue (Mobile Recharge)
    const Color(0xFF523387), // Deep Purple (Bluetooth)
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _updateSpinWheel(String rewardType, String? rewardValue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');
      if (token == null) throw Exception('No session token');

      final response = await http.post(
        Uri.parse('https://sopersonal.in/backend/update_weekly_spin_wheel.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'reward_type': rewardType,
          'reward_value': rewardValue ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          widget.onSpinComplete(rewardType, rewardValue);
        } else {
          throw Exception(data['message'] ?? 'Failed to update spin wheel');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating weekly spin wheel: $e');
      rethrow;
    }
  }

  void spinWheel() {
    if (_isSpinning || !widget.eligibility['can_spin']) return;

    final random = Random();
    double baseRotations = (4 + random.nextDouble() * 4) * 2 * pi;
    double segmentAngle = 2 * pi / visualRewards.length;
    int targetSegmentIndex = random.nextInt(visualRewards.length);

    double finalAngleOffset =
        (2 * pi - (segmentAngle * targetSegmentIndex + segmentAngle / 2));
    double finalSpinAngle = baseRotations + finalAngleOffset;

    setState(() {
      _isSpinning = true;
    });

    _animation = Tween<double>(
      begin: _animation.value,
      end: finalSpinAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.reset();
    _controller.forward().whenComplete(() async {
      if (!mounted) return;

      final int landedIndex =
          (visualRewards.length - (finalSpinAngle % (2 * pi)) / segmentAngle)
              .floor() %
          visualRewards.length;

      final wonReward = visualRewards[landedIndex];
      final wonRewardValue = wonReward == "Gift Card" ? "₹500" : null;

      try {
        await _updateSpinWheel(wonReward, wonRewardValue);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 30),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Congratulations!',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You won',
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    SizedBox(height: 10),
                    Text(
                      wonReward,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (wonRewardValue != null) ...[
                      SizedBox(height: 5),
                      Text(
                        wonRewardValue,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close result dialog
                      Navigator.of(context).pop(); // Close spin wheel dialog
                    },
                    child: Text('OK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Spin Wheel',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC8821B),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Progress info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.eligibility['matches_remaining'] > 0
                          ? 'Play ${widget.eligibility['matches_remaining']} more match(es) to unlock!'
                          : widget.eligibility['has_spun']
                              ? 'You have already spun this week!'
                              : 'You are eligible to spin!',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Spin Wheel
            Container(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animation.value,
                        child: CustomPaint(
                          painter: WeeklySpinWheelPainter(visualRewards, segmentColors),
                          size: const Size(270, 270),
                        ),
                      );
                    },
                  ),
                  // Pointer
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      painter: PointerPainter(const Color(0xFFC48B30)),
                      size: const Size(40, 30),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            // Spin Button
            ElevatedButton(
              onPressed: widget.eligibility['can_spin'] && !_isSpinning
                  ? spinWheel
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFC8821B),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                _isSpinning ? 'SPINNING...' : 'SPIN',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class WeeklySpinWheelPainter extends CustomPainter {
  final List<String> rewards;
  final List<Color> segmentColors;

  WeeklySpinWheelPainter(this.rewards, this.segmentColors);

  @override
  void paint(Canvas canvas, Size size) {
    double angle = (2 * pi) / rewards.length;
    double radius = size.width / 2;

    var rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE5B861), Color(0xFFC48B30), Color(0xFFE5B861)],
      ).createShader(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
      );
    canvas.drawCircle(Offset(radius, radius), radius, rimPaint);

    double segmentRadius = radius * 0.95;

    for (int i = 0; i < rewards.length; i++) {
      var segmentPaint = Paint()..style = PaintingStyle.fill;
      segmentPaint.color = segmentColors[i % segmentColors.length];

      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: segmentRadius),
        angle * i + (pi / 2),
        angle,
        true,
        segmentPaint,
      );

      const double textRadiusFactor = 0.7;
      double textCenterAngle = angle * i + angle / 2 + (pi / 2);

      double x = radius + (segmentRadius * textRadiusFactor) * cos(textCenterAngle);
      double y = radius + (segmentRadius * textRadiusFactor) * sin(textCenterAngle);

      final textPainter = TextPainter(
        text: TextSpan(
          text: rewards[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black87, blurRadius: 2)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: segmentRadius * 0.85);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(textCenterAngle + pi / 2);
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PointerPainter extends CustomPainter {
  final Color color;

  PointerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
