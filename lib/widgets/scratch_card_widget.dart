import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ScratchCardWidget extends StatefulWidget {
  final int contestId;
  final String contestType; // 'mega' or 'mini'
  final Function(double) onScratched;
  final Future<double> Function() fetchScratchAmount;
  final bool canScratchToday; // Whether user can scratch today
  final Map<String, dynamic> weeklyProgress; // Weekly progress data

  const ScratchCardWidget({
    Key? key,
    required this.contestId,
    required this.contestType,
    required this.onScratched,
    required this.fetchScratchAmount,
    this.canScratchToday = true,
    this.weeklyProgress = const {},
  }) : super(key: key);

  @override
  _ScratchCardWidgetState createState() => _ScratchCardWidgetState();
}

class _ScratchCardWidgetState extends State<ScratchCardWidget> {
  bool _isScratched = false;
  bool _isLoading = false;
  double? _scratchAmount;
  final Set<Offset> _scratchedPoints = {};
  double _scratchedPercentage = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.canScratchToday) {
      _loadScratchAmount();
    }
  }

  Future<void> _loadScratchAmount() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final amount = await widget.fetchScratchAmount();
      if (mounted) {
        setState(() {
          _scratchAmount = amount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading scratch amount: $e');
      // Don't throw, just log the error so the widget can still render
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isScratched || _isLoading || !widget.canScratchToday) return;

    setState(() {
      final RenderBox box = context.findRenderObject() as RenderBox;
      final Offset localPosition = box.globalToLocal(details.globalPosition);
      
      // Add points in a radius around the touch point
      for (int i = -15; i <= 15; i++) {
        for (int j = -15; j <= 15; j++) {
          if (i * i + j * j <= 225) {
            _scratchedPoints.add(localPosition + Offset(i.toDouble(), j.toDouble()));
          }
        }
      }
      
      // Calculate scratched percentage (rough estimate)
      final size = box.size;
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final radius = 60.0; // Circular scratch area radius
      
      // Make sure _scratchAmount is set before checking scratched percentage
      if (_scratchAmount == null) {
        _loadScratchAmount();
      }
      
      // Count points within circular area
      int pointsInCircle = 0;
      for (final point in _scratchedPoints) {
        final distance = ((point.dx - centerX) * (point.dx - centerX) + 
                          (point.dy - centerY) * (point.dy - centerY));
        if (distance <= radius * radius) {
          pointsInCircle++;
        }
      }
      
      final circleArea = math.pi * radius * radius;
      _scratchedPercentage = (pointsInCircle * 4.0 / circleArea * 100).clamp(0.0, 100.0);
      
      // If more than 40% of circle is scratched, reveal the card
      if (_scratchedPercentage >= 40.0 && !_isScratched) {
        // Ensure amount is loaded before marking as scratched
        if (_scratchAmount == null) {
          _loadScratchAmount().then((_) {
            if (mounted && _scratchAmount != null) {
              setState(() {
                _isScratched = true;
              });
              widget.onScratched(_scratchAmount!);
            }
          });
        } else {
          setState(() {
            _isScratched = true;
          });
          widget.onScratched(_scratchAmount!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canScratchToday) {
      final totalScratched = widget.weeklyProgress['total_scratched'] ?? 0;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFD700), // Gold
              Color(0xFFFFA500), // Orange Gold
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Colors.white,
                  size: 40,
                ),
                SizedBox(height: 8),
                Text(
                  'Already Scratched Today',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Come back tomorrow!',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Week Progress: $totalScratched/7 Days',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Next: Day ${widget.weeklyProgress['current_streak_day'] ?? 1} - ₹${((widget.weeklyProgress['current_streak_day'] ?? 1) * 5).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFD700), // Gold
              Color(0xFFFFA500), // Orange Gold
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    if (_isScratched) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4CAF50), // Green
              Color(0xFF66BB6A), // Light Green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 50,
                ),
                SizedBox(height: 8),
                Text(
                  '₹${_scratchAmount?.toStringAsFixed(2) ?? '0.00'}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Added to Wallet!',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      child: CustomPaint(
        painter: ScratchCardPainter(_scratchedPoints),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFD700), // Gold
                Color(0xFFFFA500), // Orange Gold
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Revealed content (shown through scratched areas) - Circular area in center
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(
                      color: Color(0xFFFFD700),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.8),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹',
                          style: GoogleFonts.poppins(
                            color: Color(0xFFFFD700),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _scratchAmount?.toStringAsFixed(0) ?? '0',
                          style: GoogleFonts.poppins(
                            color: Color(0xFFFFD700),
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Weekly Progress Indicator (top right)
              Positioned(
                top: 15,
                right: 15,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            'Day ${widget.weeklyProgress['current_streak_day'] ?? 1}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '₹${((widget.weeklyProgress['current_streak_day'] ?? 1) * 5).toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Overlay (scratchable surface)
              CustomPaint(
                painter: ScratchOverlayPainter(_scratchedPoints),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScratchCardPainter extends CustomPainter {
  final Set<Offset> scratchedPoints;

  ScratchCardPainter(this.scratchedPoints);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw golden star border around circular scratch area
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = 60.0;
    
    final starPaint = Paint()
      ..color = Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw star shape (8-pointed star)
    final path = Path();
    final numPoints = 8;
    final outerRadius = radius + 15;
    final innerRadius = radius + 5;
    
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = (i * math.pi) / numPoints;
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final x = centerX + r * math.cos(angle);
      final y = centerY + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, starPaint);
  }

  @override
  bool shouldRepaint(ScratchCardPainter oldDelegate) {
    return scratchedPoints.length != oldDelegate.scratchedPoints.length;
  }
}


class ScratchOverlayPainter extends CustomPainter {
  final Set<Offset> scratchedPoints;

  ScratchOverlayPainter(this.scratchedPoints);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the overlay with holes where scratched
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.fill;

    // Draw full overlay
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Draw circular scratch area border
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = 60.0;
    
    final borderPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(Offset(centerX, centerY), radius, borderPaint);

    // Erase scratched areas
    final erasePaint = Paint()
      ..blendMode = BlendMode.clear;

    for (final point in scratchedPoints) {
      if (point.dx >= 0 && point.dx <= size.width && point.dy >= 0 && point.dy <= size.height) {
        canvas.drawCircle(point, 15, erasePaint);
      }
    }
  }

  @override
  bool shouldRepaint(ScratchOverlayPainter oldDelegate) {
    return scratchedPoints.length != oldDelegate.scratchedPoints.length;
  }
}
