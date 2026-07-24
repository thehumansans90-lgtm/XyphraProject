import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

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
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _regDisplayNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmPasswordController.dispose();
    _regPasswordHintController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent.shade700 : Colors.deepPurpleAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1950),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF16161D),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  void _submit() async {
    FocusScope.of(context).unfocus();

    if (!_isRegisterMode) {
      final username = _loginUsernameController.text.trim();
      if (username.isEmpty) {
        _showSnackBar('Введите ваш логин!');
        return;
      }

      setState(() => _isLoading = true);

      final existingUser = await AuthService.findUserByUsername(username);

      if (existingUser != null) {
        await AuthService.saveSession(existingUser);
        if (!mounted) return;
        widget.onLoginSuccess();
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Пользователь с таким ником не найден!');
      }
    } else {
      final name = _regDisplayNameController.text.trim();
      final pass = _regPasswordController.text;
      final confirmPass = _regConfirmPasswordController.text;

      if (name.isEmpty) {
        _tabController.animateTo(0);
        _showSnackBar('Введите имя пользователя!');
        return;
      }

      if (pass.isEmpty) {
        _tabController.animateTo(1);
        _showSnackBar('Введите пароль!');
        return;
      }

      if (pass != confirmPass) {
        _tabController.animateTo(1);
        _showSnackBar('Пароли не совпадают!');
        return;
      }

      setState(() => _isLoading = true);

      final cleanUsername = name.toLowerCase().replaceAll(' ', '_');
      final isTaken = await AuthService.isUsernameTaken(cleanUsername);

      if (isTaken) {
        setState(() => _isLoading = false);
        _showSnackBar('Никнейм уже занят!');
        return;
      }

      final user = UserProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: cleanUsername,
        tag: '#${(1000 + (name.hashCode % 9000)).abs()}',
        displayName: name,
        bio: 'Новый участник Xyphra!',
        avatarUrl: '',
        bannerColor: '0xFF9C27B0',
        joinedDate: '2026 г.',
        badges: ['NEW'],
      );

      await AuthService.saveSession(user);

      if (!mounted) return;
      widget.onLoginSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090E),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: 0.1),
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
                  color: const Color(0xFF14141B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _isLoading
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _buildLoadingWidget(),
                  secondChild: _buildAuthForm(),
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
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              color: Colors.deepPurpleAccent,
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _isRegisterMode ? 'Создаём ваш профиль...' : 'Вход в систему...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Синхронизация с серверами Xyphra',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.deepPurpleAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
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
        const SizedBox(height: 8),
        Text(
          _isRegisterMode
              ? 'Заполните данные для регистрации'
              : 'Введите логин для входа в профиль',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        if (!_isRegisterMode) ...[
          _buildTextField(
            controller: _loginUsernameController,
            label: 'Логин или Никнейм',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _loginPasswordController,
            label: 'Пароль',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureLoginPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey,
              ),
              onPressed: () =>
                  setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
          ),
        ] else ...[
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF09090E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.deepPurpleAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '1. Профиль'),
                Tab(text: '2. Безопасность'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _regDisplayNameController,
                        label: 'Имя / Никнейм *',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _regEmailController,
                        label: 'Почта (Необязательно)',
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickBirthDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF09090E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake_outlined,
                                  color: Colors.grey, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedBirthDate == null
                                    ? 'Дата рождения'
                                    : '${_selectedBirthDate!.day}.${_selectedBirthDate!.month}.${_selectedBirthDate!.year}',
                                style: TextStyle(
                                  color: _selectedBirthDate == null
                                      ? Colors.grey
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _regPasswordController,
                        label: 'Пароль *',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureRegPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRegPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(
                              () => _obscureRegPassword = !_obscureRegPassword),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _regConfirmPasswordController,
                        label: 'Повторите пароль *',
                        icon: Icons.lock_reset_rounded,
                        obscureText: _obscureRegConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRegConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() =>
                              _obscureRegConfirmPassword =
                                  !_obscureRegConfirmPassword),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _regPasswordHintController,
                        label: 'Подсказка к паролю',
                        icon: Icons.help_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _submit,
            child: Text(
              _isRegisterMode ? 'Создать аккаунт' : 'Войти в аккаунт',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
            });
          },
          child: Text(
            _isRegisterMode
                ? 'Уже есть аккаунт? Войти'
                : 'Еще нет аккаунта? Зарегистрироваться',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF09090E),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
        ),
      ),
    );
  }
}