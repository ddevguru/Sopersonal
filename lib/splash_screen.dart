import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:play_smart/Auth/login_screen.dart';
import 'package:play_smart/Auth/signup_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2500),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _buttonOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6A1B9A), // Dark purple
              Color(0xFF9575CD), // Lighter purple from image
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -screenWidth * 0.2,
              left: -screenWidth * 0.2,
              child: Container(
                height: screenWidth * 0.5,
                width: screenWidth * 0.5,
                decoration: BoxDecoration(
                  color: Color(0xFF9575CD).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -screenWidth * 0.3,
              right: -screenWidth * 0.3,
              child: Container(
                height: screenWidth * 0.6,
                width: screenWidth * 0.6,
                decoration: BoxDecoration(
                  color: Color(0xFF9575CD).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Main content
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/icons/app_icon.png', // Replace with your logo asset path
                            height: 80,
                            width: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // App name
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: AnimatedTextKit(
                        animatedTexts: [
                          FlickerAnimatedText(
                            'Sopersonal',
                            textStyle: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            speed: Duration(milliseconds: 2000),
                          ),
                        ],
                        isRepeatingAnimation: false,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Tagline
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Text(
                        'Challenge Your Mind, Expand Your Knowledge',
                        style: GoogleFonts.poppins(
                          color: Color(0xFFD1C4E9), // Light purple from image
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 40),

                    // Welcome box
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Container(
                        width: screenWidth * 0.85,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Welcome Back!',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Sign in to continue your quiz journey',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.black,
                                // textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 20),
                            FadeTransition(
  opacity: _buttonOpacityAnimation,
  child: _buildButton(
    text: 'LOGIN',
    color: LinearGradient(
      colors: [
        Color(0xFFCE93D8), // Lighter purple
        Color(0xFF6A1B9A), // Dark purple
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    textColor: Colors.black,
    onPressed: () {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(1.0, 0.0);
            var end = Offset.zero;
            var curve = Curves.easeOutQuint;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    },
  ),
),
                            SizedBox(height: 15),
                            FadeTransition(
                              opacity: _buttonOpacityAnimation,
                              child: _buildButton(
                                text: 'SIGN UP',
                                color: Colors.white,
                                textColor: Color(0xFF6A1B9A),
                                borderColor: Color(0xFFCE93D8),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) => SignupScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        var begin = Offset(1.0, 0.0);
                                        var end = Offset.zero;
                                        var curve = Curves.easeOutQuint;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(position: animation.drive(tween), child: child);
                                      },
                                      transitionDuration: Duration(milliseconds: 500),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Secure & Private
                    FadeTransition(
                      opacity: _fadeInAnimation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield, color: Color(0xFFD1C4E9), size: 16),
                          SizedBox(width: 5),
                          Text(
                            'Secure & Private',
                            style: GoogleFonts.poppins(
                              color: Color(0xFFD1C4E9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required dynamic color, // Can be Color or Gradient
    required Color textColor,
    required VoidCallback onPressed,
    Color? borderColor,
  }) {
    return Container(
      width: 220,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color is Color ? color : null,
          foregroundColor: textColor,
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
            side: borderColor != null
                ? BorderSide(color: borderColor, width: 2)
                : BorderSide.none,
          ),
          elevation: 0,
        ).copyWith(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            return color is LinearGradient ? null : color;
          }),
          overlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: text == 'LOGIN'
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Color(0xFF6A1B9A), size: 16),
                  SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}