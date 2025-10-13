import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart' as validators;
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/app_auth_provider.dart';
import '../../../presentation/screens/dashboard/admin/dashboard_admin_screen.dart';
import '../../../presentation/screens/dashboard/coordinator/dashboard_coordo_screen.dart';
import '../../../presentation/screens/dashboard/student/dashboard_student_screen.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  String _selectedRole = 'student';
  String _selectedRegion = 'Antananarivo';
  bool _loading = false;

  static const List<String> roles = [
    'student',
    'regional_coordinator',
    'admin',
  ];
  static const List<String> regions = [
    'Antananarivo',
    'Antsirabe',
    'Fianarantsoa',
    'Tuléar',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    try {
      if (_isLogin) {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
          region: _selectedRegion,
          role: _selectedRole,
        );
      }

      if (!mounted) return;
      final user = auth.user;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final userDoc = await auth.userModelStream.first;
      if (!mounted) return;

      final role = userDoc?.role ?? _selectedRole;
      if (role == 'admin') {
        Navigator.of(
          context,
        ).pushReplacementNamed(DashboardAdminScreen.routeName);
      } else if (role == 'regional_coordinator') {
        Navigator.of(
          context,
        ).pushReplacementNamed(DashboardCoordoScreen.routeName);
      } else {
        Navigator.of(
          context,
        ).pushReplacementNamed(DashboardStudentScreen.routeName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLogin ? 'Connexion' : 'Inscription',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _isLogin = !_isLogin);
            },
            child: Text(
              _isLogin ? 'S\'inscrire' : 'Se connecter',
              style: TextStyle(
                color: AppColors.accent,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: Theme.of(context).cardTheme.elevation,
              shape: Theme.of(context).cardTheme.shape,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: validators.validateEmail,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                        ),
                        obscureText: true,
                        validator: validators.validatePassword,
                      ),
                      const SizedBox(height: 12),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Nom complet requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          items: roles
                              .map(
                                (role) => DropdownMenuItem(
                                  value: role,
                                  child: Text(role),
                                ),
                              )
                              .toList(),
                          hint: const Text('Rôle'),
                          onChanged: (v) =>
                              setState(() => _selectedRole = v ?? 'student'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRegion,
                          items: regions
                              .map(
                                (region) => DropdownMenuItem(
                                  value: region,
                                  child: Text(region),
                                ),
                              )
                              .toList(),
                          hint: const Text('Région'),
                          onChanged: (v) => setState(
                            () => _selectedRegion = v ?? 'Antananarivo',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppColors.accent,
                                  ),
                                ),
                              )
                            : Text(_isLogin ? 'Se connecter' : 'S\'inscrire'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
