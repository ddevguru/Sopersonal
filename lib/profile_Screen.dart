import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:play_smart/splash_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({required this.token, Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _failedAttempts = 0;
  bool _isProcessingPayment = false;
  String? _sessionToken;
  double? _enteredAmount;
  late Razorpay _razorpay;

  final TextEditingController _amountController = TextEditingController();
  static const String BASE_URL = 'https://sopersonal.in';
  static const double MIN_PAYMENT_AMOUNT = 1.0;
  static const double MAX_PAYMENT_AMOUNT = 100000;
  static const int MAX_RETRY_ATTEMPTS = 3;

  late AnimationController _animationController;
  late AnimationController _floatingIconsController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _selectedTab = 0;

  TextStyle header = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
  TextStyle value = const TextStyle(fontWeight: FontWeight.w400, fontSize: 14);

  @override
  void initState() {
    super.initState();
    _sessionToken = widget.token;
    _initializeAnimations();
    _initializeRazorpay();
    _fetchUserData();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _initializeAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _floatingIconsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 8000))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _rotateController = AnimationController(vsync: this, duration: const Duration(milliseconds: 20000))..repeat();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingIconsController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$BASE_URL/get_user_data.php?token=$_sessionToken'), headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'QuizMaster/1.0',
      }).timeout(const Duration(seconds: 15));
      print('User data response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && response.headers['content-type']?.contains('application/json') == true) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is Map<String, dynamic>) {
          setState(() {
            userData = data['data'];
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch user data');
        }
      } else {
        throw Exception('Invalid response format or server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _showCustomSnackBar('Error fetching user data: $e. Please try again.', isError: true);
      setState(() => isLoading = false);
    }
  }

  bool _validatePaymentAmount(double amount) {
    if (amount < MIN_PAYMENT_AMOUNT) {
      _showCustomSnackBar('Minimum payment amount is ₹${MIN_PAYMENT_AMOUNT.toStringAsFixed(0)}', isError: true);
      return false;
    }
    if (amount > MAX_PAYMENT_AMOUNT) {
      _showCustomSnackBar('Amount exceeds limit of ₹${MAX_PAYMENT_AMOUNT.toStringAsFixed(0)}', isError: true);
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>?> _createRazorpayOrder(double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/create_razorpay_order.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'token': _sessionToken,
          'amount': amount * 100,
        }),
      ).timeout(const Duration(seconds: 15));

      print('Create Razorpay order response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && response.headers['content-type']?.contains('application/json') == true) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
        _showCustomSnackBar('Failed to create order: ${data['message'] ?? 'Unknown error'}', isError: true);
        return null;
      } else {
        _showCustomSnackBar('Server error: ${response.statusCode}', isError: true);
        return null;
      }
    } catch (e) {
      print('Error creating Razorpay order: $e');
      _showCustomSnackBar('Network error: $e', isError: true);
      return null;
    }
  }

  Future<bool> _updateWalletBalance(String paymentId, String orderId, String signature) async {
    try {
      final payload = {
        'token': _sessionToken,
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      };
      print('Sending payload to update_wallet.php: $payload');

      final response = await http.post(
        Uri.parse('$BASE_URL/update_wallet.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      print('Update wallet response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && response.headers['content-type']?.contains('application/json') == true) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('Wallet update successful, new balance: ${data['new_balance']}');
          return true;
        }
        print('Wallet update failed: ${data['message']}');
        return false;
      }
      print('Invalid response format: ${response.statusCode} - ${response.body}');
      return false;
    } catch (e) {
      print('Error updating wallet: $e');
      return false;
    }
  }

  void _initiatePayment(double amount) async {
    if (_failedAttempts >= MAX_RETRY_ATTEMPTS) {
      _showCustomSnackBar('Too many failed attempts. Please try again later.', isError: true);
      return;
    }

    if (_isProcessingPayment) {
      _showCustomSnackBar('Payment is already in progress. Please wait.', isError: true);
      return;
    }

    if (!_validatePaymentAmount(amount)) return;

    setState(() {
      _isProcessingPayment = true;
      _enteredAmount = amount;
    });
    _showLoadingDialog('Initiating payment...');

    try {
      final orderData = await _createRazorpayOrder(amount);
      if (orderData == null) {
        setState(() => _isProcessingPayment = false);
        Navigator.pop(context);
        return;
      }

      var options = {
        'key': 'rzp_live_Nb4qh9syPEKkss',
        'amount': (amount * 100).toInt(),
        'order_id': orderData['order_id'],
        'name': 'Esportswala',
        'description': 'Wallet Top-up',
        'prefill': {
          'contact': userData?['phone'] ?? '',
          'email': userData?['email'] ?? '',
        },
        'theme': {
          'color': '#6A1B9A'
        }
      };

      _razorpay.open(options);
    } catch (e) {
      print('Payment Error: $e');
      _showCustomSnackBar('Payment initiation failed: $e', isError: true);
      setState(() => _isProcessingPayment = false);
      Navigator.pop(context);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Navigator.pop(context);
    _showLoadingDialog('Verifying payment...');

    bool success = false;
    try {
      success = await _updateWalletBalance(
        response.paymentId!,
        response.orderId!,
        response.signature!,
      );
      if (success) {
        await _fetchUserData();
        Navigator.pop(context);
        _showSuccessDialog(_enteredAmount!, userData?['wallet_balance']?.toDouble() ?? 0.0);
      } else {
        _showCustomSnackBar('Failed to update wallet. Please try again.', isError: true);
      }
    } catch (e) {
      print('Error in payment success handling: $e');
      _showCustomSnackBar('Error verifying payment: $e', isError: true);
    } finally {
      setState(() {
        _isProcessingPayment = false;
        _failedAttempts = success ? 0 : _failedAttempts + 1;
        _enteredAmount = null;
        _amountController.clear();
      });
      Navigator.pop(context);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Navigator.pop(context);
    _showCustomSnackBar('Payment failed: ${response.message}', isError: true);
    setState(() {
      _isProcessingPayment = false;
      _failedAttempts++;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showCustomSnackBar('External wallet selected: ${response.walletName}');
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 14))),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[700] : Color(0xFF9575CD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Widget _displayTransactionData(String title, String body) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$title: ", style: header),
          Flexible(child: Text(body, style: value)),
        ],
      ),
    );
  }

  void _showDepositDialog() {
    if (_isProcessingPayment) {
      _showCustomSnackBar('Payment is already in progress. Please wait.', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFD1C4E9).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Color(0xFFD1C4E9),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add Money to Wallet',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.currency_rupee, color: Color(0xFF6A1B9A)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _amountController.clear();
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text);
                if (amount != null && _validatePaymentAmount(amount)) {
                  Navigator.pop(context);
                  _initiatePayment(amount);
                } else {
                  _showCustomSnackBar(
                    'Please enter a valid amount between ₹$MIN_PAYMENT_AMOUNT and ₹$MAX_PAYMENT_AMOUNT',
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Proceed',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6A1B9A)),
                const SizedBox(height: 15),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Color(0xFF6A1B9A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(double amount, double newBalance) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF9575CD), Color(0xFF6A1B9A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                'Payment Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1B9A),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFD1C4E9).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '₹${amount.toStringAsFixed(2)} added to your wallet',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'New Balance: ₹${newBalance.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A1B9A),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF9575CD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  elevation: 2,
                ),
                child: Text(
                  'Continue',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWithdrawForm() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController bankNameController = TextEditingController();
    final TextEditingController accountNumberController = TextEditingController();
    final TextEditingController ifscCodeController = TextEditingController();
    final TextEditingController upiIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFD1C4E9).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: Color(0xFF6A1B9A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Withdrawal Request',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWithdrawField(
                  controller: amountController,
                  label: 'Amount (₹, Minimum ₹50)',
                  icon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildWithdrawField(
                  controller: bankNameController,
                  label: 'Bank Name',
                  icon: Icons.account_balance,
                ),
                const SizedBox(height: 12),
                _buildWithdrawField(
                  controller: accountNumberController,
                  label: 'Account Number',
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _buildWithdrawField(
                  controller: ifscCodeController,
                  label: 'IFSC Code',
                  icon: Icons.code,
                ),
                const SizedBox(height: 12),
                _buildWithdrawField(
                  controller: upiIdController,
                  label: 'UPI ID (Optional)',
                  icon: Icons.payment,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null &&
                    amount >= 50 &&
                    bankNameController.text.isNotEmpty &&
                    accountNumberController.text.isNotEmpty &&
                    ifscCodeController.text.isNotEmpty) {
                  _submitWithdrawalRequest(
                    amount,
                    bankNameController.text,
                    accountNumberController.text,
                    ifscCodeController.text,
                    upiIdController.text,
                  );
                  Navigator.pop(context);
                } else {
                  _showCustomSnackBar(
                    'Please fill all required fields correctly and ensure amount is at least ₹50',
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Submit Request',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWithdrawField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(icon, color: Color(0xFF6A1B9A)),
        filled: true,
        fillColor: Colors.grey[50],
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
        ),
      ),
      style: GoogleFonts.poppins(fontSize: 14),
    );
  }

  Future<void> _submitWithdrawalRequest(
    double amount,
    String bankName,
    String accountNumber,
    String ifscCode,
    String upiId,
  ) async {
    try {
      if (amount < 50) {
        _showCustomSnackBar(
          'Minimum withdrawal amount is ₹50',
          isError: true,
        );
        return;
      }

      final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
      if (!ifscRegex.hasMatch(ifscCode)) {
        _showCustomSnackBar(
          'Invalid IFSC code format. Use format like SBIN0001234.',
          isError: true,
        );
        return;
      }

      final requestBody = jsonEncode({
        'token': _sessionToken,
        'amount': amount,
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc_code': ifscCode,
        'upi_id': upiId.isEmpty ? null : upiId,
      });
      print('Withdrawal request: $requestBody');
      
      _showLoadingDialog('Submitting withdrawal request...');

      final response = await http.post(
        Uri.parse('$BASE_URL/withdraw.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 15));

      print('Withdrawal response: ${response.statusCode} - ${response.body}');
      Navigator.pop(context);

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showCustomSnackBar(
          'Withdrawal request submitted successfully. It will be processed soon.',
        );
      } else if (data['error_code'] == 'outside_withdrawal_window') {
        _showOutsideWithdrawalWindowDialog();
      } else {
        _showCustomSnackBar(
          'Failed to submit withdrawal request: ${data['message'] ?? 'Unknown error'}',
          isError: true,
        );
      }
    } catch (e) {
      print('Error submitting withdrawal request: $e');
      Navigator.pop(context);
      _showCustomSnackBar(
        'Error submitting withdrawal request: $e',
        isError: true,
      );
    }
  }

  void _showOutsideWithdrawalWindowDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9575CD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Withdrawal Time Restricted',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Withdrawals are only allowed between\n11:00 AM and 5:00 PM IST.',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Please try again during the allowed hours.',
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFCE93D8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    elevation: 2,
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF6A1B9A)),
                const SizedBox(height: 15),
                Text(
                  'Logging out...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      );

      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        Navigator.pop(context);
        print('Logout: No internet connection');
        _showCustomSnackBar('No internet connection', isError: true);
        return;
      }

      print('Logout: Sending POST request to $BASE_URL/logout.php with token: $_sessionToken');
      final response = await http.post(
        Uri.parse('$BASE_URL/logout.php'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'token': _sessionToken,
        },
      ).timeout(const Duration(seconds: 10));

      print('Logout response: ${response.statusCode} - ${response.body}');
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Color(0xFFD1C4E9).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF6A1B9A),
                    size: 100,
                  ),
                ),
              );
            },
          );
          await Future.delayed(const Duration(milliseconds: 1500));

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('token');
          print('Logout: Token and login status cleared');

          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SplashScreen()),
          );
        } else {
          _showCustomSnackBar(data['message'] ?? 'Logout failed', isError: true);
        }
      } else {
        _showCustomSnackBar('Logout failed: HTTP ${response.statusCode}', isError: true);
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error during logout: $e');
      _showCustomSnackBar('Error during logout: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF9575CD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
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
          SafeArea(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF6A1B9A)),
                        const SizedBox(height: 20),
                        Text(
                          'Loading Profile...',
                          style: GoogleFonts.poppins(
                            color: Color(0xFFD1C4E9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : userData == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFD1C4E9),
                              size: 50,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Failed to load profile data.',
                              style: GoogleFonts.poppins(
                                color: Color(0xFFD1C4E9),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _fetchUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFCE93D8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: _buildAnimatedIconButton(
                                      icon: Icons.arrow_back_ios,
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ),
                                  const Spacer(),
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: _buildAnimatedIconButton(
                                      icon: Icons.refresh,
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        _fetchUserData();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: _buildProfileHeader(),
                                ),
                              ),
                              const SizedBox(height: 30),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(
                                        0.4,
                                        0.7,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                  ),
                                  child: _buildTabSelector(),
                                ),
                              ),
                              const SizedBox(height: 25),
                              FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: _animationController,
                                      curve: const Interval(
                                        0.5,
                                        0.8,
                                        curve: Curves.easeOutCubic,
                                      ),
                                    ),
                                  ),
                                  child: _buildTabContent(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: const [
                          Color(0xFF6A1B9A),
                          Color(0xFF9575CD),
                          Color(0xFFCE93D8),
                          Color(0xFFD1C4E9),
                          Color(0xFF6A1B9A),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        startAngle: 0,
                        endAngle: pi * 2,
                        transform: GradientRotation(_pulseController.value * pi * 2),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData?['username'] ?? 'User',
                      style: GoogleFonts.poppins(
                        color: Color(0xFF6A1B9A),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      userData?['email'] ?? 'email@example.com',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          color: Colors.grey[600],
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            userData?['phone'] ?? 'N/A',
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Color(0xFFD1C4E9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF6A1B9A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet Balance',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '₹${userData?['wallet_balance']?.toString() ?? '0'}',
                          style: GoogleFonts.poppins(
                            color: Color(0xFF6A1B9A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWalletButton(
                      label: 'ADD MONEY',
                      icon: Icons.add,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showDepositDialog();
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildWalletButton(
                      label: 'WITHDRAW',
                      icon: Icons.arrow_downward,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _showWithdrawForm();
                      },
                      isSecondary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Color(0xFFD1C4E9).withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildTabButton(
            icon: Icons.person,
            label: 'Profile',
            index: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          HapticFeedback.selectionClick();
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFCE93D8) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Color(0xFFD1C4E9),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Color(0xFFD1C4E9),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return _buildProfileTab();
  }

  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Personal Information'),
        const SizedBox(height: 15),
        _buildProfileField(
          label: 'Phone',
          value: userData?['phone'] ?? 'N/A',
          icon: Icons.phone,
        ),
        const SizedBox(height: 15),
        _buildProfileField(
          label: 'Helpline Number',
          value: '+91 85073-51008',
          icon: Icons.support_agent,
          onPressed: () async {
            final Uri phoneUri = Uri(scheme: 'tel', path: '+918507351008');
            if (await canLaunchUrl(phoneUri)) {
              await launchUrl(phoneUri);
              _showCustomSnackBar('Initiating call to helpline');
              HapticFeedback.mediumImpact();
            } else {
              _showCustomSnackBar('Unable to initiate call', isError: true);
            }
          },
          iconAction: Icons.call,
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('Referral Information'),
        const SizedBox(height: 15),
        _buildProfileField(
          label: 'Referral Code',
          value: userData?['referral_code'] ?? 'N/A',
          icon: Icons.card_giftcard,
          onPressed: () {
            if (userData?['referral_code'] != null) {
              Clipboard.setData(ClipboardData(text: userData!['referral_code']));
              _showCustomSnackBar('Referral code copied to clipboard');
              HapticFeedback.mediumImpact();
            }
          },
          iconAction: Icons.copy,
        ),
        const SizedBox(height: 15),
        _buildProfileField(
          label: 'Referral Count',
          value: userData?['referral_count']?.toString() ?? '0',
          icon: Icons.people,
        ),
        const SizedBox(height: 30),
        _buildActionButton(
          label: 'Share App',
          icon: Icons.share,
          color: Color(0xFF9575CD),
          onPressed: () async {
            final String message = 'Check out Sopersonal! Download now: https://play.google.com/store/apps/details?id=com.devloperwala.play_smart&pcampaignid=web_share';
            final Uri whatsappUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
            if (await canLaunchUrl(whatsappUri)) {
              await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
              _showCustomSnackBar('Opening WhatsApp to share PlaySmart app');
              HapticFeedback.mediumImpact();
            } else {
              _showCustomSnackBar('WhatsApp is not installed or cannot be opened', isError: true);
            }
          },
        ),
        const SizedBox(height: 15),
        _buildActionButton(
          label: 'Logout',
          icon: Icons.logout,
          color: Colors.red[700]!,
          onPressed: () {
            HapticFeedback.mediumImpact();
            _logout();
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Color(0xFFD1C4E9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Color(0xFFCE93D8),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileField({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onPressed,
    IconData? iconAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color(0xFFD1C4E9).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(0xFF6A1B9A).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFFD1C4E9),
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Color(0xFFD1C4E9),
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onPressed != null && iconAction != null)
            IconButton(
              icon: Icon(
                iconAction,
                color: Color(0xFFD1C4E9),
              ),
              onPressed: onPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color(0xFFCE93D8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 15),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 140,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSecondary ? null : LinearGradient(
              colors: [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            color: isSecondary ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(30),
            border: isSecondary
                ? Border.all(color: Color(0xFFD1C4E9), width: 2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSecondary ? Color(0xFFD1C4E9) : Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: isSecondary ? Color(0xFFD1C4E9) : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingIcon(int index) {
    const icons = [
      Icons.lightbulb,
      Icons.school,
      Icons.psychology,
      Icons.extension,
      Icons.star,
      Icons.auto_awesome,
    ];
    const sizes = [30.0, 40.0, 25.0, 35.0, 45.0];
    return Icon(
      icons[index % icons.length],
      color: Color(0xFFD1C4E9),
      size: sizes[index % sizes.length],
    );
  }

  Widget _buildAnimatedIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xFFD1C4E9).withOpacity(0.3),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xFF6A1B9A).withOpacity(0.2 + (_pulseController.value * 0.1)),
                blurRadius: 10 + (_pulseController.value * 5),
                spreadRadius: 1 + (_pulseController.value * 1),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            onPressed: onPressed,
          ),
        );
      },
    );
  }
}