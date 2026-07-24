import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Кастомный неоновый логотип Xyphra (Концепция "Кристаллический Разряд")
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

    // Градиент для мягкого неонового свечения
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

    // Основная кисть для четких неоновых линий
    final paintLine = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB388FF), Color(0xFFEA80FC), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    // Путь 1: Левая диагональ X
    final pathLeft = Path()
      ..moveTo(w * 0.2, h * 0.2)
      ..lineTo(w * 0.8, h * 0.8);

    // Путь 2: Правая диагональ в виде молнии (XYPHRA Bolt X)
    final pathBolt = Path()
      ..moveTo(w * 0.8, h * 0.2)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.2, h * 0.8);

    // Отрисовка свечения
    canvas.drawPath(pathLeft, paintGlow);
    canvas.drawPath(pathBolt, paintGlow);

    // Отрисовка четких линий
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

  /// Кастомный диалог выбора даты рождения
  Future<void> _pickBirthDateCustom() async {
    DateTime tempDate = _selectedBirthDate ?? DateTime(2005, 1, 1);

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            int age = now.year - tempDate.year;
            if (now.month < tempDate.month ||
                (now.month == tempDate.month && now.day < tempDate.day)) {
              age--;
            }

            return Container(
              height: 440,
              decoration: const BoxDecoration(
                color: Color(0xFF12121A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: Color(0x26FFFFFF), width: 1),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Дата рождения',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.deepPurpleAccent
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '$age лет',
                          style: const TextStyle(
                            color: Colors.deepPurpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Colors.deepPurpleAccent,
                          onPrimary: Colors.white,
                          surface: Color(0xFF12121A),
                          onSurface: Colors.white,
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: tempDate,
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now(),
                        onDateChanged: (newDate) {
                          setModalState(() {
                            tempDate = newDate;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, tempDate),
                      child: const Text(
                        'Подтвердить',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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

      final currentYear = DateTime.now().year;

      final user = UserProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: cleanUsername,
        tag: '#${(1000 + (name.hashCode % 9000)).abs()}',
        displayName: name,
        bio: 'Новый участник Xyphra!',
        avatarUrl: '',
        bannerColor: '0xFF9C27B0',
        joinedDate: '$currentYear г.',
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
      backgroundColor: const Color(0xFF08080C),
      body: Stack(
        children: [
          // Декоративные фоновые неоновые пятна
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.deepPurpleAccent.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purpleAccent.withValues(alpha: 0.2),
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
                  color: const Color(0xFF111118),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withValues(alpha: 0.08),
                      blurRadius: 30,
                      spreadRadius: -10,
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
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              color: Colors.deepPurpleAccent,
              strokeWidth: 3.5,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _isRegisterMode ? 'Создаём ваш профиль...' : 'Вход в систему...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
        // Шапка с новым уникальным логотипом
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurpleAccent.withValues(alpha: 0.25),
                    Colors.purpleAccent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurpleAccent.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
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
          _isRegisterMode
              ? 'Заполните данные для создания аккаунта'
              : 'Введите логин для входа в профиль',
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
                          label: 'Пароль *',
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
                          label: 'Подсказка к паролю',
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

        // Главная кнопка
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
        const SizedBox(height: 14),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
          onPressed: () {
            setState(() {
              _isRegisterMode = !_isRegisterMode;
            });
          },
          child: Text(
            _isRegisterMode
                ? 'Уже есть аккаунт? Войти'
                : 'Еще нет аккаунта? Зарегистрироваться',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Кастомная панель вкладок
  Widget _buildCustomTabBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF08080C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.deepPurpleAccent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
              blurRadius: 8,
            )
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '1. Профиль'),
          Tab(text: '2. Безопасность'),
        ],
      ),
    );
  }

  /// Безопасное форматирование даты без пакета intl
  Widget _buildCustomDatePickerField() {
    String formattedDate = 'Дата рождения';

    if (_selectedBirthDate != null) {
      const months = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря'
      ];
      final day = _selectedBirthDate!.day.toString().padLeft(2, '0');
      final month = months[_selectedBirthDate!.month - 1];
      final year = _selectedBirthDate!.year;

      formattedDate = '$day $month $year г.';
    }

    return InkWell(
      onTap: _pickBirthDateCustom,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF08080C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedBirthDate != null
                ? Colors.deepPurpleAccent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_outlined,
              color: _selectedBirthDate != null
                  ? Colors.deepPurpleAccent
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
        fillColor: const Color(0xFF08080C),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
        ),
      ),
    );
  }
}