import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import '../dialogs/account_suspended_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    _buildCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 56),
          decoration: BoxDecoration(
            color: const Color(0xFF695959),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
          child: _buildForm(),
        ),
        Positioned(
          top: 0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.scaffoldBg,
              border: Border.all(color: const Color(0xFF695959), width: 3),
            ),
            child: ClipOval(
              child: Image.asset('assets/images/Logo.png', fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome back to\nCozyTalk!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'LOGIN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.yellowWarm,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _label('Email'),
          const SizedBox(height: 6),
          _textField(
            controller: _emailController,
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _label('Password'),
          const SizedBox(height: 6),
          _passwordField(),
          const SizedBox(height: 24),
          _loginButton(),
          const SizedBox(height: 18),
          _orDivider(),
          const SizedBox(height: 18),
          _googleButton(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              GestureDetector(
                onTap: _goToSignUp,
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: AppColors.yellowWarm,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _goToHome,
            child: const Text(
              'Login as a guest',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => showAccountSuspendedDialog(context),
            child: const Text(
              '[Test] Account Banned',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(color: Colors.black87, fontSize: 14),
    decoration: _inputDecoration(hint),
  );

  Widget _passwordField() => TextFormField(
    controller: _passwordController,
    obscureText: _obscurePassword,
    validator: _validatePassword,
    style: const TextStyle(color: Colors.black87, fontSize: 14),
    decoration: _inputDecoration('Enter your password').copyWith(
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFFAAAAAA),
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm, width: 1.5),
    ),
    errorStyle: const TextStyle(color: AppColors.yellowWarm, fontSize: 12),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm),
    ),
  );

  Widget _orDivider() => const Row(
    children: [
      Expanded(child: Divider(color: Colors.white38, thickness: 1)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'or',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ),
      Expanded(child: Divider(color: Colors.white38, thickness: 1)),
    ],
  );

  Widget _googleButton() => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4A3228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/icons/google_logo.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 10),
          const Text(
            'Continue with Google',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A3228),
            ),
          ),
        ],
      ),
    ),
  );

  void _signInWithGoogle() {
    _goToHome();
  }

  Widget _loginButton() => SizedBox(
    height: 48,
    child: ElevatedButton(
      onPressed: _goToHome,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.saveBtn,
        foregroundColor: const Color(0xFF4A3228),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: const Text(
        'Login',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _goToHome();
  }

  void _goToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  void _goToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'At least 6 characters.';
    return null;
  }
}
