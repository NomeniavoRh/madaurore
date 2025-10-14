import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart' as validators;
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/app_auth_provider.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';

  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true; // Mode connexion ou inscription

  // Contrôleurs de texte
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  // Sélections
  String _selectedRole = 'student';
  String _selectedRegion = 'Antananarivo';

  // États
  bool _loading = false;
  bool _obscurePassword = true;

  // Options disponibles
  static const List<String> roles = [
    'student',
    'regional_coordinator',
    'admin',
  ];

  static const Map<String, String> roleLabels = {
    'student': 'Étudiant',
    'regional_coordinator': 'Coordinateur Régional',
    'admin': 'Administrateur',
  };

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

  // =====================================================
  // SOUMISSION DU FORMULAIRE
  // =====================================================
  Future<void> _submit() async {
    // Validation du formulaire
    if (!_formKey.currentState!.validate()) return;

    // Fermer le clavier
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    try {
      if (_isLogin) {
        // ===== MODE CONNEXION =====
        await auth.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // Attendre que le userModel soit chargé
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        final userModel = auth.userModel;

        if (userModel == null) {
          throw Exception('Impossible de récupérer les données utilisateur');
        }

        // Vérifier le statut
        if (userModel.status == 'pending') {
          _showStatusDialog('pending');
          await auth.signOut();
          return;
        }

        if (userModel.status == 'rejected') {
          _showStatusDialog('rejected');
          await auth.signOut();
          return;
        }

        // Navigation selon le rôle
        _navigateToRoleDashboard(userModel.role);
      } else {
        // ===== MODE INSCRIPTION =====
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
          region: _selectedRegion,
          role: _selectedRole,
        );

        if (!mounted) return;

        // Afficher un message de succès
        _showSuccessDialog();
      }
    } catch (e) {
      if (!mounted) return;

      // Afficher l'erreur
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // =====================================================
  // NAVIGATION SELON LE RÔLE
  // =====================================================
  void _navigateToRoleDashboard(String role) {
    String route;

    switch (role) {
      case 'admin':
        route = '/admin/dashboard_admin';
        break;
      case 'regional_coordinator':
        route = '/coordinator/dashboard_coordo';
        break;
      default:
        route = '/student/dashboard_student';
    }

    // Navigation avec remplacement (impossible de revenir en arrière)
    Navigator.of(context).pushReplacementNamed(route);
  }

  // =====================================================
  // DIALOGUES
  // =====================================================

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Text('Erreur'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog(String status) {
    String title;
    String message;
    IconData icon;
    Color color;

    if (status == 'pending') {
      title = 'Compte en attente';
      message =
          'Votre compte est en attente d\'approbation par un administrateur. '
          'Vous recevrez une notification une fois votre compte approuvé.';
      icon = Icons.hourglass_empty;
      color = AppColors.accent;
    } else {
      title = 'Compte rejeté';
      message =
          'Votre demande de compte a été rejetée. '
          'Veuillez contacter un administrateur pour plus d\'informations.';
      icon = Icons.block;
      color = AppColors.error;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 12),
            Text('Inscription réussie'),
          ],
        ),
        content: const Text(
          'Votre compte a été créé avec succès !\n\n'
          'Il est actuellement en attente d\'approbation par un administrateur. '
          'Vous pourrez vous connecter une fois votre compte approuvé.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _isLogin = true);
            },
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // INTERFACE UTILISATEUR
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Calculate responsive logo size based on screen width
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize =
        screenWidth * 0.2; // 20% of screen width, adjustable

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLogin ? 'Connexion' : 'Inscription',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () {
                    setState(() => _isLogin = !_isLogin);
                  },
            child: Text(
              _isLogin ? 'S\'inscrire' : 'Se connecter',
              style: TextStyle(
                color: _loading ? Colors.grey : AppColors.accent,
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
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo ou titre
                      Image.asset(
                        'assets/images/madaction_logo.png', // Path to your logo
                        height: logoSize, // Responsive height
                        width: logoSize, // Responsive width
                        fit: BoxFit.contain, // Maintain aspect ratio
                      ),
                      const SizedBox(height: 24),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: validators.validateEmail,
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 16),

                      // Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: validators.validatePassword,
                        enabled: !_loading,
                      ),

                      // Champs supplémentaires pour l'inscription
                      if (!_isLogin) ...[
                        const SizedBox(height: 16),

                        // Nom complet
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Nom complet requis'
                              : null,
                          enabled: !_loading,
                        ),
                        const SizedBox(height: 16),

                        // Rôle
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Rôle',
                            prefixIcon: Icon(Icons.work),
                          ),
                          items: roles.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(roleLabels[role] ?? role),
                            );
                          }).toList(),
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(
                                    () => _selectedRole = value ?? 'student',
                                  );
                                },
                        ),
                        const SizedBox(height: 16),

                        // Région
                        DropdownButtonFormField<String>(
                          value: _selectedRegion,
                          decoration: const InputDecoration(
                            labelText: 'Région',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          items: regions.map((region) {
                            return DropdownMenuItem(
                              value: region,
                              child: Text(region),
                            );
                          }).toList(),
                          onChanged: _loading
                              ? null
                              : (value) {
                                  setState(
                                    () => _selectedRegion =
                                        value ?? 'Antananarivo',
                                  );
                                },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Bouton de soumission
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                _isLogin ? 'Se connecter' : 'S\'inscrire',
                                style: const TextStyle(fontSize: 16),
                              ),
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
