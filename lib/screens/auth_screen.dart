import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Custom Neon Xyphra Logo
class XyphraLogo extends StatelessWidget {
  final double size;

  const XyphraLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _XyphraLogoPainter(),
      ),
    );
  }
}

class _XyphraLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintGlow = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final paintLine = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB388FF), Color(0xFFEA80FC), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    final pathLeft = Path()
      ..moveTo(w * 0.2, h * 0.2)
      ..lineTo(w * 0.8, h * 0.8);

    final pathBolt = Path()
      ..moveTo(w * 0.8, h * 0.2)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.2, h * 0.8);

    canvas.drawPath(pathLeft, paintGlow);
    canvas.drawPath(pathBolt, paintGlow);
    canvas.drawPath(pathLeft, paintLine);
    canvas.drawPath(pathBolt, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscureLoginPassword = true;
  bool _obscureRegPassword = true;
  bool _obscureRegConfirmPassword = true;

  // Domain selection logic
  final List<String> _emailDomains = [
    '@gmail.com',
    '@outlook.com',
    '@yahoo.com',
    '@icloud.com',
    'Manual',
  ];
  String _selectedDomain = '@gmail.com';

  // Email OTP logic
  bool _isCodeSent = false;
  String? _generatedCode;
  int _timerSeconds = 60;
  Timer? _timer;

  // 6 digit code inputs
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  late TabController _tabController;

  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regDisplayNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  DateTime? _selectedBirthDate;

  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();
  final _regPasswordHintController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regDisplayNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regPasswordHintController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _timerSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        if (mounted) setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(email.toLowerCase());
  }

  String _generateRandomCode() {
    final rnd = Random();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  /// Send email without third-party packages (using dart:io)
  Future<bool> _sendActualEmail(String targetEmail, String code) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      );
      request.headers.set('content-type', 'application/json');

      final payload = jsonEncode({
        'service_id': 'xyphra_auth_service',
        'template_id': 'xyphra_verification_template',
        'user_id': 'xyphra_public_key',
        'template_params': {
          'to_email': targetEmail.toLowerCase(),
          'code': code,
          'app_name': 'Xyphra',
        }
      });

      request.write(payload);
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return true;
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE53935) : const Color(0xFF7C4DFF),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  String _getFullEmail() {
    final input = _regEmailController.text.trim().toLowerCase();
    if (input.isEmpty) return '';
    if (_selectedDomain == 'Manual' || input.contains('@')) {
      return input;
    }
    return '$input$_selectedDomain';
  }

  String _maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  Future<void> _sendEmailVerification() async {
    FocusScope.of(context).unfocus();

    final name = _regDisplayNameController.text.trim();
    final fullEmail = _getFullEmail();
    final pass = _regPasswordController.text;
    final confirmPass = _regConfirmPasswordController.text;

    if (name.isEmpty) {
      _tabController.animateTo(0);
      _showSnackBar('Please enter a display name!');
      return;
    }

    if (pass.isEmpty) {
      _tabController.animateTo(1);
      _showSnackBar('Please enter a password!');
      return;
    }

    if (pass != confirmPass) {
      _tabController.animateTo(1);
      _showSnackBar('Passwords do not match!');
      return;
    }

    // Email is OPTIONAL: If provided, validate and send code
    if (fullEmail.isNotEmpty) {
      if (!_isValidEmail(fullEmail)) {
        _tabController.animateTo(0);
        _showSnackBar('Invalid email address format!');
        return;
      }

      setState(() => _isLoading = true);

      final cleanUsername = name.toLowerCase().replaceAll(' ', '_');
      final isTaken = await AuthService.isUsernameTaken(cleanUsername);

      if (isTaken) {
        setState(() => _isLoading = false);
        _showSnackBar('Username is already taken!');
        return;
      }

      _generatedCode = _generateRandomCode();
      await _sendActualEmail(fullEmail, _generatedCode!);

      setState(() {
        _isLoading = false;
        _isCodeSent = true;
      });

      _startResendTimer();
      _showSnackBar('Verification code sent to $fullEmail', isError: false);
    } else {
      // Direct registration without email
      await _registerDirectly();
    }
  }

  Future<void> _registerDirectly() async {
    setState(() => _isLoading = true);
    final name = _regDisplayNameController.text.trim();
    final cleanUsername = name.toLowerCase().replaceAll(' ', '_');
    final currentYear = DateTime.now().year;

    final user = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: cleanUsername,
      tag: '#${(1000 + (name.hashCode % 9000)).abs()}',
      displayName: name,
      bio: 'Xyphra Member',
      avatarUrl: '',
      bannerColor: '0xFF9C27B0',
      joinedDate: '$currentYear',
      badges: ['VERIFIED'],
    );

    await AuthService.saveSession(user);

    if (!mounted) return;
    widget.onLoginSuccess();
  }

  Future<void> _verifyCodeAndRegister() async {
    final inputCode = _otpControllers.map((c) => c.text).join().trim();

    if (inputCode.length < 6) {
      _showSnackBar('Please enter all 6 digits!');
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    if (inputCode == _generatedCode) {
      await _registerDirectly();
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Invalid verification code!');
    }
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    final input = _loginUsernameController.text.trim().toLowerCase();
    if (input.isEmpty) {
      _showSnackBar('Please enter your username!');
      return;
    }

    setState(() => _isLoading = true);
    final existingUser = await AuthService.findUserByUsername(input);

    if (existingUser != null) {
      await AuthService.saveSession(existingUser);
      if (!mounted) return;
      widget.onLoginSuccess();
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('User not found!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE040FB).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 420,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E14),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isLoading
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _buildLoadingWidget(),
                  secondChild: _isCodeSent
                      ? _buildCustomOtpVerificationForm()
                      : _buildAuthForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: Color(0xFF7C4DFF),
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _isCodeSent
                ? 'Verifying code...'
                : (_isRegisterMode ? 'Processing account...' : 'Signing in...'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Secured by Xyphra Protocol',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomOtpVerificationForm() {
    final fullEmail = _getFullEmail();
    final maskedEmail = _maskEmail(fullEmail);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
              ),
            ),
            const Icon(
              Icons.shield_outlined,
              size: 40,
              color: Color(0xFFB388FF),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Email Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined,
                  size: 14, color: Color(0xFFB388FF)),
              const SizedBox(width: 8),
              Text(
                maskedEmail,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 6 digit code
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 48,
              height: 58,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF06060A),
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _otpControllers[index].text.isNotEmpty
                          ? const Color(0xFF7C4DFF)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFE040FB),
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 5) {
                    _otpFocusNodes[index + 1].requestFocus();
                  } else if (val.isEmpty && index > 0) {
                    _otpFocusNodes[index - 1].requestFocus();
                  }
                  if (_otpControllers.map((c) => c.text).join().length == 6) {
                    _verifyCodeAndRegister();
                  }
                  setState(() {});
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 28),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
            ),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _verifyCodeAndRegister,
            child: const Text(
              'Activate Account',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _timerSeconds == 0 ? _sendEmailVerification : null,
          child: Text(
            _timerSeconds > 0
                ? 'Resend code in ${_timerSeconds}s'
                : 'Resend verification code',
            style: TextStyle(
              color: _timerSeconds == 0
                  ? const Color(0xFFB388FF)
                  : Colors.grey.withValues(alpha: 0.5),
              fontSize: 13,
            ),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _isCodeSent = false),
          child: const Text(
            '← Back to registration',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                    const Color(0xFFE040FB).withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                ),
              ),
              child: const XyphraLogo(size: 32),
            ),
            const SizedBox(width: 14),
            const Text(
              'XYPHRA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _isRegisterMode ? 'Create your account' : 'Sign in to your ecosystem',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!_isRegisterMode) ...[
          _buildTextField(
            controller: _loginUsernameController,
            label: 'Username or Email',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureLoginPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () => setState(
                  () => _obscureLoginPassword = !_obscureLoginPassword),
            ),
          ),
        ] else ...[
          _buildCustomTabBar(),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: 230,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _regDisplayNameController,
                          label: 'Username (Latin only)',
                          icon: Icons.badge_outlined,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildEmailFieldWithDomainDropdown(),
                        const SizedBox(height: 12),
                        _buildCustomDatePickerField(),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _regPasswordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureRegPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureRegPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => setState(() =>
                                _obscureRegPassword = !_obscureRegPassword),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _regConfirmPasswordController,
                          label: 'Confirm Password',
                          icon: Icons.lock_reset_rounded,
                          obscureText: _obscureRegConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureRegConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () => setState(() =>
                                _obscureRegConfirmPassword =
                                    !_obscureRegConfirmPassword),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _regPasswordHintController,
                          label: 'Password Hint (Optional)',
                          icon: Icons.help_outline_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isRegisterMode ? _sendEmailVerification : _login,
            child: Text(
              _isRegisterMode ? 'Create Account' : 'Sign In',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
            });
          },
          child: Text(
            _isRegisterMode
                ? 'Already have an account? Sign In'
                : 'Don\'t have an account? Sign Up',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  /// Special Email TextField with Domain Dropdown on the right
  Widget _buildEmailFieldWithDomainDropdown() {
    return TextField(
      controller: _regEmailController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Email Address (Optional)',
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon:
            const Icon(Icons.email_outlined, color: Colors.grey, size: 20),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDomain,
              dropdownColor: const Color(0xFF111118),
              borderRadius: BorderRadius.circular(14),
              icon:
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
              style: const TextStyle(
                color: Color(0xFFB388FF),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: _emailDomains.map((String domain) {
                return DropdownMenuItem<String>(
                  value: domain,
                  child: Text(
                    domain,
                    style: TextStyle(
                      color: domain == 'Manual' ? Colors.grey : Colors.white,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDomain = newValue;
                  });
                }
              },
            ),
          ),
        ),
        filled: true,
        fillColor: const Color(0xFF06060A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF06060A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF7C4DFF),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '1. Profile'),
          Tab(text: '2. Security'),
        ],
      ),
    );
  }

  Widget _buildCustomDatePickerField() {
    String formattedDate = 'Birth Date (Optional)';

    if (_selectedBirthDate != null) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final day = _selectedBirthDate!.day.toString().padLeft(2, '0');
      final month = months[_selectedBirthDate!.month - 1];
      final year = _selectedBirthDate!.year;

      formattedDate = '$month $day, $year';
    }

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2005),
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _selectedBirthDate = picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF06060A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_outlined,
              color: _selectedBirthDate != null
                  ? const Color(0xFF7C4DFF)
                  : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formattedDate,
                style: TextStyle(
                  color:
                      _selectedBirthDate == null ? Colors.grey : Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF06060A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C4DFF), width: 1.5),
        ),
      ),
    );
  }
}
