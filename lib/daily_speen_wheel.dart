import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SpinWheelWidget extends StatefulWidget {
  final Function(double)? onSpinComplete;
  final Map<String, dynamic> weeklyProgress;
  final bool canSpinToday;

  const SpinWheelWidget({
    super.key,
    this.onSpinComplete,
    this.weeklyProgress = const {},
    this.canSpinToday = true,
  });

  @override
  State<SpinWheelWidget> createState() => _SpinWheelWidgetState();
}

class _SpinWheelWidgetState extends State<SpinWheelWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _isLoading = false;
  double? _winAmount;
  List<String>? _cachedRewards; // Cache rewards during spin

  // Progressive rewards based on actual win amount
  // IMPORTANT: Progressive amount is ALWAYS at index 0 (first segment)
  List<String> get visualRewards {
    // Use the actual win amount if available, otherwise calculate from weekly progress
    final winAmount = _winAmount ?? ((widget.weeklyProgress['current_streak_day'] ?? 1) * 5);
    
    // Create wheel with progressive amount FIRST (index 0) - this is what will be won
    // The wheel will always land on index 0, which contains the progressive amount
    final List<String> rewards = [
      "₹${winAmount.toInt()}", // Main progressive amount (will be won) - ALWAYS FIRST (INDEX 0)
      "₹${(winAmount + 5).toInt()}",
      "₹${(winAmount + 10).toInt()}",
      "₹${(winAmount + 15).toInt()}",
      "₹${(winAmount + 20).toInt()}",
      "₹${(winAmount + 25).toInt()}",
      "₹${(winAmount + 30).toInt()}",
    ];
    return rewards;
  }

  // Custom list of colors to match the wheel's vibrant segments (10 segments)
  final List<Color> segmentColors = [
    const Color(0xFFC42D3B), // Red
    const Color(0xFF6C2A78), // Deep Purple
    const Color(0xFF2E653F), // Dark Green
    const Color(0xFFC8821B), // Orange/Gold
    const Color(0xFF4C87C2), // Bright Blue
    const Color(0xFFC42D3B), // Red (Repeat)
    const Color(0xFF6C2A78), // Deep Purple (Repeat)
    const Color(0xFF2E653F), // Dark Green (Repeat)
    const Color(0xFF4C87C2), // Bright Blue (Repeat)
    const Color(0xFFC8821B), // Orange/Gold (Repeat)
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
    
    // Fetch spin amount on init
    if (widget.canSpinToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchSpinAmount();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchSpinAmount() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        throw Exception('No token found');
      }
      
      final response = await http.get(
        Uri.parse('https://sopersonal.in/fetch_spin_wheel_amount.php?session_token=$token'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final amount = data['amount'] is double
              ? data['amount']
              : double.parse(data['amount'].toString());
          print("Fetched spin amount: ₹$amount");
          if (mounted) {
            setState(() {
              _winAmount = amount;
              _isLoading = false;
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch spin amount');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching spin amount: $e');
      throw e;
    }
  }

  Future<void> updateWalletFromSpin(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      throw Exception('No token found');
    }
    
    try {
      final response = await http.post(
        Uri.parse('https://sopersonal.in/update_wallet_from_spin_wheel.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'session_token': token,
          'amount': amount.toString(),
        },
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (widget.onSpinComplete != null) {
            widget.onSpinComplete!(amount);
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to update wallet');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating wallet from spin: $e');
      rethrow;
    }
  }

  void spinWheel() async {
    if (_isSpinning || !widget.canSpinToday || _isLoading) return;
    
    // Fetch the progressive amount first (if not already loaded)
    if (_winAmount == null) {
      try {
        await fetchSpinAmount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    if (_winAmount == null) {
      print("Error: Win amount is still null after fetch");
      return;
    }
    
    print("Spinning wheel for amount: ₹$_winAmount");
    
    // Cache the win amount and rewards before spinning
    final cachedWinAmount = _winAmount!;
    final cachedRewards = visualRewards; // This uses _winAmount, so cache it now
    
    setState(() {
      _isSpinning = true;
      _cachedRewards = cachedRewards; // Store cached rewards for use during spin
    });
    
    final random = Random();
    // Multiple full rotations for visual effect (4-8 rotations)
    double baseRotations = 4 + random.nextDouble() * 4;
    double targetAngle = baseRotations * 2 * pi;

    double segmentAngle = 2 * pi / cachedRewards.length;
    
    // The progressive amount is ALWAYS at index 0 (first segment)
    // Segments are drawn starting from pi/2 (top), going clockwise
    // Segment 0: starts at pi/2, center at pi/2 + segmentAngle/2
    // Pointer: at top (pi/2)
    //
    // Transform.rotate(angle) rotates the child clockwise by angle
    // So if a point is at angle alpha in wheel's local coords, after rotation by theta,
    // it appears at angle (alpha + theta) in screen coords
    //
    // Segment 0 center in wheel coords: pi/2 + segmentAngle/2
    // After rotation by finalAngleMod, it appears at: (pi/2 + segmentAngle/2 + finalAngleMod) % (2*pi)
    // We want this to equal pi/2 (pointer position)
    // So: pi/2 + segmentAngle/2 + finalAngleMod = pi/2 (mod 2*pi)
    // Therefore: finalAngleMod = 2*pi - segmentAngle/2
    //
    // But wait - if it's landing on segment 1 (₹10) instead of segment 0 (₹5),
    // we're off by one segment. Let me try: finalAngleMod = 2*pi - segmentAngle/2 - segmentAngle
    // This would move us back one more segment to segment 0
    
    // Calculate adjustment to land on segment 0
    // Segment 0 center: pi/2 + segmentAngle/2
    // Pointer: pi/2
    // We need: (pi/2 + segmentAngle/2 + adjustment) % (2*pi) = pi/2
    // So: adjustment = 2*pi - segmentAngle/2
    // But if it's landing one segment ahead, we need to go back one more segment
    // Try: adjustment = 2*pi - segmentAngle/2 - segmentAngle = 2*pi - 3*segmentAngle/2
    double adjustment = 2 * pi - (3 * segmentAngle / 2);
    
    // Final angle: full rotations + adjustment to land on segment 0
    double finalAngle = targetAngle + adjustment;
    
    double finalAngleMod = finalAngle % (2 * pi);
    double segment0CenterAfterRotation = (pi / 2 + segmentAngle / 2 + finalAngleMod) % (2 * pi);
    
    print("Spin Debug: winAmount=₹$cachedWinAmount, rewards[0]=${cachedRewards[0]}, segmentAngle=${(segmentAngle * 180 / pi).toStringAsFixed(2)}°");
    print("  adjustment=${(adjustment * 180 / pi).toStringAsFixed(2)}°, finalAngleMod=${(finalAngleMod * 180 / pi).toStringAsFixed(2)}°");
    print("  segment0CenterAfterRotation=${(segment0CenterAfterRotation * 180 / pi).toStringAsFixed(2)}°, pointer=${(pi/2 * 180 / pi).toStringAsFixed(2)}°");
    print("  Difference: ${((segment0CenterAfterRotation - pi/2).abs() * 180 / pi).toStringAsFixed(2)}°");

    // Calculate the exact angle needed
    // We want segment 0 center (at pi/2 + segmentAngle/2) to align with pointer (at pi/2)
    // After rotation by finalAngle, segment 0 center will be at: (pi/2 + segmentAngle/2 + finalAngle) % (2*pi)
    // We want this to equal pi/2
    // So: (pi/2 + segmentAngle/2 + finalAngle) % (2*pi) = pi/2
    // This means: finalAngle % (2*pi) = 2*pi - segmentAngle/2 (which is our adjustment)

    _animation = Tween<double>(
      begin: _animation.value % (2 * pi), // Normalize to 0-2π range
      end: finalAngle,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.reset();
    _controller.forward().whenComplete(() async {
      if (!mounted) return;
      
      print("Spin Complete! Won: ₹$_winAmount");
      
      // Update wallet
      try {
        await updateWalletFromSpin(_winAmount!);
        
        // Show success dialog
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
                      '₹${_winAmount!.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Amount added to your wallet!',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (mounted) {
                        setState(() {
                          _isSpinning = false;
                        });
                      }
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
              content: Text('Error updating wallet: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSpinning = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF202020),
          borderRadius: BorderRadius.circular(200),
          border: Border.all(color: const Color(0xFF444444), width: 6),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
            const BoxShadow(
              color: Color(0xFF666666),
              blurRadius: 5,
              spreadRadius: 0,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wheel Segments
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                // Use cached rewards during spin to prevent recalculation
                final rewards = _isSpinning && _cachedRewards != null 
                    ? _cachedRewards! 
                    : visualRewards;
                return Transform.rotate(
                  angle: _animation.value,
                  child: CustomPaint(
                    key: ValueKey('wheel_${_winAmount?.toInt() ?? 0}'), // Force repaint when amount changes
                    painter: SpinWheelPainter(rewards, segmentColors),
                    size: const Size(270, 270),
                  ),
                );
              },
            ),

            // Spin Button - Central Area (Glow Effect)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2741),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.blue.shade400.withOpacity(0.8),
                    blurRadius: 15,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

            // Spin Button - Clickable area with "SPIN" text
            GestureDetector(
              onTap: (_isSpinning || !widget.canSpinToday || _isLoading) ? null : spinWheel,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (_isSpinning || !widget.canSpinToday || _isLoading) 
                      ? Colors.grey 
                      : const Color(0xFF3B486A),
                  border: Border.all(
                    color: (_isSpinning || !widget.canSpinToday || _isLoading)
                        ? Colors.grey.shade400
                        : Colors.blue.shade200, 
                    width: 2
                  ),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 5,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(
                        _isSpinning ? "SPINNING..." : "SPIN",
                  style: TextStyle(
                          color: (_isSpinning || !widget.canSpinToday || _isLoading)
                              ? Colors.grey.shade300
                              : Colors.cyan.shade300,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        // ignore: deprecated_member_use
                        color: Colors.cyan.shade500.withOpacity(0.8),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Pointer (Triangle on top)
            Positioned(
              top: 5,
              child: CustomPaint(
                painter: PointerPainter(
                  const Color(0xFFD4A62C),
                ), // Gold/Orange color
                size: const Size(40, 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Painter for the Spin Wheel Segments ---

class SpinWheelPainter extends CustomPainter {
  final List<String> rewards;
  final List<Color> segmentColors;

  SpinWheelPainter(this.rewards, this.segmentColors);

  @override
  void paint(Canvas canvas, Size size) {
    double angle = (2 * pi) / rewards.length;
    double radius = size.width / 2;

    // Define the gold-metallic rim paint
    var rimPaint = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE5B861), Color(0xFFC48B30), Color(0xFFE5B861)],
          ).createShader(
            Rect.fromCircle(center: Offset(radius, radius), radius: radius),
          );

    // Draw the gold metallic rim
    canvas.drawCircle(Offset(radius, radius), radius, rimPaint);

    double segmentRadius = radius * 0.95;

    for (int i = 0; i < rewards.length; i++) {
      var segmentPaint = Paint()..style = PaintingStyle.fill;
      segmentPaint.color = segmentColors[i % segmentColors.length];

      // Draw the segment arc
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: segmentRadius),
        angle * i + (pi / 2),
        angle,
        true,
        segmentPaint,
      );

      // --- Draw Text in White Color with Shadow ---
      // Text is positioned at the center of each segment
      const double textRadiusFactor = 0.75;
      // Segment i center angle: angle * i + angle / 2 + (pi / 2)
      // For segment 0: angle/2 + pi/2 = pi/2 + segmentAngle/2
      double textRotationAngle = angle * i + angle / 2 + (pi / 2);

      final textPainter = TextPainter(
        text: TextSpan(
          text: rewards[i],
          style: TextStyle(
            color: Colors.white, // Changed color to WHITE
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                // ignore: deprecated_member_use
                color: Colors.black.withOpacity(
                  0.8,
                ), // Black shadow for contrast
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      double x =
          radius +
          (segmentRadius * textRadiusFactor) * cos(textRotationAngle) -
          textPainter.width / 2;
      double y =
          radius +
          (segmentRadius * textRadiusFactor) * sin(textRotationAngle) -
          textPainter.height / 2;

      canvas.save();
      canvas.translate(x + textPainter.width / 2, y + textPainter.height / 2);
      canvas.rotate(textRotationAngle + pi / 2);
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

// --- Custom Painter for the Top Pointer Triangle ---

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

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 5.0);

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
