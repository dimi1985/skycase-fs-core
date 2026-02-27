import 'package:flutter/material.dart';
import 'package:skycase/screens/home_screen.dart';
import 'package:skycase/services/auth_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/session_manager.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  String? _errorMessage;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final AuthService _authService = AuthService(
    baseUrl: 'http://38.242.241.46:3000',
  );
  final UserService _userService = UserService(
    baseUrl: 'http://38.242.241.46:3000',
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

void _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  final username = _usernameController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  try {
    if (_isLogin) {
      // ---- LOGIN FLOW ----
      final loginResponse = await _authService.login(username, password);

      // Save token
      await SessionManager.saveToken(loginResponse.token);

      // Load full user profile
      final fullProfile = await _userService.getProfile(loginResponse.token);

      if (!mounted) return;

      print('[LOGIN SUCCESS] Loaded profile for ${fullProfile.username}');

      // Navigate to HomeScreen WITH USER
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(),
        ),
      );
    } else {
      // ---- REGISTRATION FLOW ----
      await _authService.register(username, email, password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful. Please login.'),
        ),
      );

      setState(() => _isLogin = true);
    }
  } catch (e, stack) {
    print('[AUTH ERROR] $e');
    print(stack);
    _errorMessage = e.toString();
  }

  // Turn off loader
  if (mounted) {
    setState(() => _isLoading = false);
  }

  // Show error if any
  if (_errorMessage != null && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorMessage!)),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator:
                      (v) =>
                          (v == null || v.isEmpty) ? 'Enter a username' : null,
                ),
                if (!_isLogin)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator:
                      (v) =>
                          (v == null || v.length < 6)
                              ? 'Minimum 6 characters'
                              : null,
                ),
                const SizedBox(height: 20),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? 'Login' : 'Register'),
                    ),
                TextButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _isLogin = !_isLogin;
                        _usernameController.clear();
                        _emailController.clear();
                        _passwordController.clear();
                      });
                    }
                  },
                  child: Text(
                    _isLogin
                        ? 'Create new account'
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
