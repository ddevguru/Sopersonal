import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/main_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:lottie/lottie.dart';
import 'login_screen.dart';
import 'dart:developer' as developer;

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _referralFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _referralFocus.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter a valid 10-digit phone number';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _fieldFocusChange(BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('https://sopersonal.in/signup.php'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Accept': '*/*'},
          body: {
            'username': _usernameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': _phoneController.text.trim(),
            'password': _passwordController.text,
            'referral_code': _referralController.text.trim(),
          },
        ).timeout(const Duration(seconds: 10));
        developer.log('Raw Response: ${response.body}', name: 'Signup');
        developer.log('Status Code: ${response.statusCode}', name: 'Signup');
        developer.log('Headers: ${response.headers}', name: 'Signup');
        try {
          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && data['success']) {
            _showSuccessAnimation();
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('session_token', data['token']);
            await prefs.setString('username', _usernameController.text.trim());
            await prefs.setString('email', _emailController.text.trim());
            await prefs.setString('phone', _phoneController.text.trim());
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutQuart;
                    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 700),
                ),
              );
            }
          } else _showErrorSnackBar(data['message'] ?? 'Signup failed with status ${response.statusCode}');
        } catch (e) {
          developer.log('JSON Decode Error: $e', name: 'Signup');
          _showErrorSnackBar('Invalid response format: ${e.toString()}');
        }
      } catch (e) {
        developer.log('HTTP Error: $e', name: 'Signup');
        _showErrorSnackBar('Error: ${e is TimeoutException ? 'Request timed out' : e.toString()}');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else HapticFeedback.mediumImpact();
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(height: 200, child: Lottie.network('https://assets9.lottiefiles.com/packages/lf20_jbrw3hcz.json', repeat: false)),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(message))]),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF9575CD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(top: screenHeight * 0.05, left: -screenWidth * 0.1, child: Container(height: 100, width: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
              Positioned(bottom: screenHeight * 0.1, right: -screenWidth * 0.1, child: Container(height: 150, width: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle))),
              Positioned(top: 10, left: 10, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context))),
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: screenHeight * 0.02),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(height: screenHeight * 0.02),
                            Text('Welcome to', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.w500)),
                            AnimatedTextKit(
                              animatedTexts: [
                                TypewriterAnimatedText(
                                  'Sopersonal',
                                  textStyle: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 3), blurRadius: 5)],
                                  ),
                                  speed: const Duration(milliseconds: 150),
                                ),
                              ],
                              isRepeatingAnimation: false,
                              totalRepeatCount: 1,
                            ),
                            const SizedBox(height: 5),
                            Container(width: 60, height: 4, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10))),
                            SizedBox(height: screenHeight * 0.03),
                          ]),
                        ),
                        ..._buildAnimatedFormFields(screenHeight),
                        SizedBox(height: screenHeight * 0.03),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _isLoading ? 60 : screenWidth * 0.7,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(_isLoading ? 50 : 30),
                                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.black.withOpacity(0.5),
                                ).copyWith(
                                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                                    return _isLoading ? Colors.transparent : null;
                                  }),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black), strokeWidth: 3)
                                    : Container(
                                        decoration: BoxDecoration(
                                          // gradient: LinearGradient(
                                          //   colors: [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
                                          //   begin: Alignment.centerLeft,
                                          //   end: Alignment.centerRight,
                                          // ),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'CREATE ACCOUNT',
                                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.black),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(0.0, 1.0);
                                      const end = Offset.zero;
                                      const curve = Curves.easeOutQuint;
                                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                      return SlideTransition(position: animation.drive(tween), child: child);
                                    },
                                    transitionDuration: const Duration(milliseconds: 500),
                                  ),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Already a quiz master? ',
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                  children: [TextSpan(text: 'Login', style: GoogleFonts.poppins(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15))],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAnimatedFormFields(double screenHeight) {
    final fields = [
      _buildInputField(
        controller: _usernameController,
        labelText: 'Username',
        prefixIcon: Icons.person_outline,
        focusNode: _usernameFocus,
        nextFocusNode: _emailFocus,
        validator: _validateUsername,
        textInputAction: TextInputAction.next,
      ),
      _buildInputField(
        controller: _emailController,
        labelText: 'Email Address',
        prefixIcon: Icons.email_outlined,
        focusNode: _emailFocus,
        nextFocusNode: _phoneFocus,
        validator: _validateEmail,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
      ),
      _buildInputField(
        controller: _phoneController,
        labelText: 'Phone Number',
        prefixIcon: Icons.phone_outlined,
        focusNode: _phoneFocus,
        nextFocusNode: _passwordFocus,
        validator: _validatePhone,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
      ),
      _buildInputField(
        controller: _passwordController,
        labelText: 'Password',
        prefixIcon: Icons.lock_outline,
        focusNode: _passwordFocus,
        nextFocusNode: _confirmPasswordFocus,
        validator: _validatePassword,
        obscureText: !_isPasswordVisible,
        suffixIcon: IconButton(
          icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 22),
          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
        textInputAction: TextInputAction.next,
      ),
      _buildInputField(
        controller: _confirmPasswordController,
        labelText: 'Confirm Password',
        prefixIcon: Icons.lock_outline,
        focusNode: _confirmPasswordFocus,
        nextFocusNode: _referralFocus,
        validator: _validateConfirmPassword,
        obscureText: !_isConfirmPasswordVisible,
        suffixIcon: IconButton(
          icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 22),
          onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
        textInputAction: TextInputAction.next,
      ),
      _buildInputField(
        controller: _referralController,
        labelText: 'Referral Code (Optional)',
        prefixIcon: Icons.card_giftcard_outlined,
        focusNode: _referralFocus,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _signup(),
      ),
    ];

    List<Widget> animatedFields = [];
    for (int i = 0; i < fields.length; i++) {
      final delay = i * 0.08;
      final fieldAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Interval(delay, delay + 0.3, curve: Curves.easeOut)),
      );
      animatedFields.add(
        FadeTransition(
          opacity: fieldAnimation,
          child: Padding(padding: EdgeInsets.only(bottom: screenHeight * 0.015), child: fields[i]),
        ),
      );
    }
    return animatedFields;
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction textInputAction = TextInputAction.next,
    Function(String)? onFieldSubmitted,
  }) {
    return Material(
      color: Colors.transparent,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: Colors.white70, size: 22),
          suffixIcon: suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white30, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.amber, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade300, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          errorStyle: GoogleFonts.poppins(color: Colors.amber, fontSize: 12, height: 1.0),
          errorMaxLines: 2,
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: (value) {
          if (onFieldSubmitted != null) onFieldSubmitted(value);
          else if (nextFocusNode != null) _fieldFocusChange(context, focusNode!, nextFocusNode);
        },
        onTap: () => HapticFeedback.selectionClick(),
      ),
    );
  }
}