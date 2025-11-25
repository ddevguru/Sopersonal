import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/Auth/reset_password_Screen.dart';
import 'package:play_smart/main_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isLoggedIn = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );
    _animationController.forward();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? rememberedEmail = prefs.getString('rememberedEmail');
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        if (rememberedEmail != null) _emailController.text = rememberedEmail;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  void _fieldFocusChange(BuildContext context, FocusNode currentFocus, FocusNode nextFocus) {
    currentFocus.unfocus();
    FocusScope.of(context).requestFocus(nextFocus);
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await http.post(
          Uri.parse('https://sopersonal.in/login.php'),
          body: {'email': _emailController.text, 'password': _passwordController.text},
        );
        print('Login response: ${response.statusCode} - ${response.body}');
        final data = jsonDecode(response.body);
        if (data['success']) {
          _showSuccessAnimation();
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('token', data['token']);
          if (_rememberMe) await prefs.setString('rememberedEmail', _emailController.text);
          else await prefs.remove('rememberedEmail');
          setState(() => _isLoggedIn = true);
          Future.delayed(Duration(milliseconds: 1500), () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => MainScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  var begin = Offset(0.0, 1.0);
                  var end = Offset.zero;
                  var curve = Curves.easeInOutQuart;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return SlideTransition(position: animation.drive(tween), child: child);
                },
                transitionDuration: Duration(milliseconds: 700),
              ),
            );
          });
        } else _showErrorSnackBar(data['message'] ?? 'Login failed');
      } catch (e) {
        print('Error during login: $e');
        _showErrorSnackBar('An error occurred: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else HapticFeedback.mediumImpact();
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      _showErrorSnackBar('Not logged in. Please log in first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      print('Sending logout request with token: $token');
      final response = await http.post(
        Uri.parse('https://sopersonal.in/logout.php'),
        body: {'token': token},
      );
      print('Logout response: ${response.statusCode} - ${response.body}');
      final data = jsonDecode(response.body);
      if (data['success']) {
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('token');
        setState(() => _isLoggedIn = false);
        _showSuccessSnackBar('Logout successful');
      } else _showErrorSnackBar(data['message'] ?? 'Logout failed');
    } catch (e) {
      print('Error during logout: $e');
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    TextEditingController _emailController = TextEditingController();
    FocusNode _emailFocus = FocusNode();
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email address to reset your password.', style: GoogleFonts.poppins(color: Colors.black87)),
            SizedBox(height: 20),
            _buildInputField(
              controller: _emailController,
              labelText: 'Email Address',
              prefixIcon: Icons.email_outlined,
              focusNode: _emailFocus,
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (_validateEmail(_emailController.text) == null) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => ResetPasswordScreen(email: _emailController.text),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        var begin = Offset(0.0, 1.0);
                        var end = Offset.zero;
                        var curve = Curves.easeInOutQuart;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(position: animation.drive(tween), child: child);
                      },
                      transitionDuration: Duration(milliseconds: 700),
                    ),
                  );
                } else _showErrorSnackBar('Please enter a valid email address.');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _emailController.dispose();
              _emailFocus.dispose();
            },
            child: Text('CANCEL', style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              if (_validateEmail(_emailController.text) == null) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => ResetPasswordScreen(email: _emailController.text),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      var begin = Offset(0.0, 1.0);
                      var end = Offset.zero;
                      var curve = Curves.easeInOutQuart;
                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(position: animation.drive(tween), child: child);
                    },
                    transitionDuration: Duration(milliseconds: 700),
                  ),
                );
              } else _showErrorSnackBar('Please enter a valid email address.');
            },
            child: Text('CONTINUE', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(height: 200, child: Lottie.network('https://assets9.lottiefiles.com/packages/lf20_jbrw3hcz.json', repeat: false, onLoaded: (composition) {
          Future.delayed(Duration(milliseconds: 1500), () => Navigator.pop(context));
        })),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.check_circle_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text(message))]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text(message))]),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
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
              Positioned(top: 10, left: 10, child: IconButton(icon: Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context))),
              if (_isLoggedIn)
                Positioned(top: 10, right: 10, child: IconButton(icon: Icon(Icons.logout, color: Colors.white), onPressed: _isLoading ? null : _logout, tooltip: 'Logout')),
              SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: screenHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06, vertical: screenHeight * 0.02),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(height: screenHeight * 0.06),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Welcome Back', style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 24, fontWeight: FontWeight.w500)),
                                  Text('Sopersonal', style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, shadows: [
                                    Shadow(color: Colors.black.withOpacity(0.3), offset: Offset(0, 3), blurRadius: 5)
                                  ])),
                                  SizedBox(height: 5),
                                  Container(width: 60, height: 4, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(10))),
                                ]),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.06),
                            Center(
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(height: 120, width: 120, child: Lottie.network('https://assets3.lottiefiles.com/packages/lf20_touohxv0.json', fit: BoxFit.contain)),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.04),
                          ]),
                          Column(children: [
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: Offset(0.3, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Interval(0.2, 0.7, curve: Curves.easeOutCubic))),
                                child: _buildInputField(
                                  controller: _emailController,
                                  labelText: 'Email Address',
                                  prefixIcon: Icons.email_outlined,
                                  focusNode: _emailFocus,
                                  nextFocusNode: _passwordFocus,
                                  validator: _validateEmail,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: Offset(0.3, 0), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Interval(0.3, 0.8, curve: Curves.easeOutCubic))),
                                child: _buildInputField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  prefixIcon: Icons.lock_outline,
                                  focusNode: _passwordFocus,
                                  validator: _validatePassword,
                                  obscureText: !_isPasswordVisible,
                                  suffixIcon: IconButton(
                                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 22),
                                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _login(),
                                ),
                              ),
                            ),
                            SizedBox(height: 5),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Row(children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() => _rememberMe = value ?? false);
                                        HapticFeedback.selectionClick();
                                      },
                                      activeColor: Colors.amber,
                                      checkColor: Colors.black,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Remember me', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                                ]),
                                TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    _forgotPassword();
                                  },
                                  child: Text('Forgot Password?', style: GoogleFonts.poppins(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w600)),
                                ),
                              ]),
                            ),
                            SizedBox(height: screenHeight * 0.04),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Center(
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    width: _isLoading ? 60 : screenWidth * 0.7,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.black,
                                        padding: EdgeInsets.symmetric(vertical: 12),
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
                                          ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.black), strokeWidth: 3)
                                          : Container(
                                              decoration: BoxDecoration(
                                                // gradient: LinearGradient(
                                                //   // colors: [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
                                                //   begin: Alignment.centerLeft,
                                                //   end: Alignment.centerRight,
                                                // ),
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'LOGIN',
                                                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1, color: Colors.black),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                          Column(children: [
                            SizedBox(height: screenHeight * 0.03),
                            FadeTransition(
                              opacity: _fadeAnimation,
                              child: Center(
                                child: TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => SignupScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          var begin = Offset(0.0, 1.0);
                                          var end = Offset.zero;
                                          var curve = Curves.easeOutQuint;
                                          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                          return SlideTransition(position: animation.drive(tween), child: child);
                                        },
                                        transitionDuration: Duration(milliseconds: 500),
                                      ),
                                    );
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'New to Sopersonal? ',
                                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                                      children: [
                                        TextSpan(text: 'Sign Up', style: GoogleFonts.poppins(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                          ]),
                        ],
                      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: Colors.white70, size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          filled: true,
          fillColor: Colors.transparent,
          errorStyle: GoogleFonts.poppins(color: Colors.amber, fontSize: 12),
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