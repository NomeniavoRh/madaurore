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
    'Conseil_Administratif',
  ];

  static const Map<String, String> roleLabels = {
    'student': 'Étudiant',
    'regional_coordinator': 'Coordinateur Régional',
    'admin': 'Administrateur',
    'Conseil_Administratif': 'Conseil Administratif',
  };

  static const List<String> regions = [
    'Antananarivo',
    'Antsirabe',
    'Fianarantsoa',
    'Toliara',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // =====================================================
  // SOUMISSION DU FORMULAIRE - Améliorée avec debug et force reload
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
        debugPrint(
          '🔍 [LoginScreen] Début connexion pour: ${_emailController.text.trim()}',
        );
        await auth.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        // Force le reload pour sync userModel (fix timing async)
        debugPrint('🔍 [LoginScreen] Force reload userModel post-signIn');
        await auth.forceReloadUserModel();

        // Petit delay supplémentaire si besoin (GMS/Firestore lag)
        await Future.delayed(const Duration(milliseconds: 300));

        if (!mounted) return;

        final userModel = auth.userModel;

        debugPrint(
          '🔍 [LoginScreen] userModel post-reload: rôle=${userModel?.role}, status=${userModel?.status}',
        );

        if (userModel == null) {
          debugPrint(
            '⚠️ [LoginScreen] userModel null après reload - Erreur fetch Firestore ?',
          );
          throw Exception('Impossible de récupérer les données utilisateur');
        }

        // Vérifier le statut
        if (userModel.status == 'pending') {
          debugPrint('🚫 [LoginScreen] Statut pending - Déconnexion');
          _showStatusDialog('pending');
          await auth.signOut();
          return;
        }

        if (userModel.status == 'rejected') {
          debugPrint('🚫 [LoginScreen] Statut rejected - Déconnexion');
          _showStatusDialog('rejected');
          await auth.signOut();
          return;
        }

        // Navigation selon le rôle
        debugPrint(
          '🚀 [LoginScreen] Navigation vers dashboard pour rôle: ${userModel.role}',
        );
        _navigateToRoleDashboard(userModel.role);
      } else {
        // ===== MODE INSCRIPTION =====
        debugPrint(
          '📝 [LoginScreen] Début inscription pour: ${_emailController.text.trim()}, rôle: $_selectedRole',
        );
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _fullNameController.text.trim(),
          region: _selectedRegion,
          role: _selectedRole,
        );

        if (!mounted) return;

        // Afficher un message de succès
        debugPrint('✅ [LoginScreen] Inscription OK - Affichage dialog');
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('❌ [LoginScreen] Erreur _submit: $e');
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
  // MOT DE PASSE OUBLIE
  // =====================================================
  Future<void> _showForgotPasswordDialog() async {
    FocusScope.of(context).unfocus();

    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.primary, size: 28),
            SizedBox(width: 12),
            Text('Mot de passe oublié'),
          ],
        ),
        content: Form(
          key: resetFormKey,
          child: TextFormField(
            controller: resetEmailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email du compte',
              prefixIcon: Icon(Icons.email),
            ),
            validator: validators.validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resetFormKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(resetEmailController.text.trim());
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    resetEmailController.dispose();
    if (email == null) return;
    if (!mounted) return;

    setState(() => _loading = true);

    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    try {
      await auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      _showPasswordResetSuccessDialog(email);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // =====================================================
  // NAVIGATION SELON LE ROLE
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
      case 'Conseil_Administratif':
        route = '/conseil/dashboard_conseil';
        break;
      default:
        route = '/student/dashboard_student';
    }

    // Navigation avec remplacement (impossible de revenir en arrière)
    Navigator.of(context).pushReplacementNamed(route);
  }

  // =====================================================
  // DIALOGUES - Sans changement majeur, + debug mineur
  // =====================================================

  void _showErrorDialog(String message) {
    debugPrint('💬 [LoginScreen] Affichage erreur dialog: $message');
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

    debugPrint('💬 [LoginScreen] Affichage status dialog: $status');
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
    debugPrint('💬 [LoginScreen] Affichage success dialog');
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

  void _showPasswordResetSuccessDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.success, size: 28),
            SizedBox(width: 12),
            Text('Email envoyé'),
          ],
        ),
        content: Text(
          'Un lien de réinitialisation a été envoyé à $email. '
          'Ouvrez cet email puis choisissez un nouveau mot de passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // INTERFACE UTILISATEUR - Améliorée avec loader pour userModel
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Calculate responsive logo size based on screen width
    final double screenWidth = MediaQuery.of(context).size.width;
    final double logoSize =
        screenWidth * 0.2; // 20% of screen width, adjustable

    return Consumer<AppAuthProvider>(
      builder: (context, auth, child) {
        // Si userModel loading, afficher loader global (fix pour timing)
        if (auth.isLoadingUserModel && auth.user != null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

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
                          if (_isLogin) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _loading
                                    ? null
                                    : _showForgotPasswordDialog,
                                icon: const Icon(Icons.lock_reset, size: 18),
                                label: const Text('Mot de passe oublié ?'),
                              ),
                            ),
                          ],

                          if (!_isLogin) ...[
                            const SizedBox(height: 16),

                            // Nom complet
                            TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Nom complet requis'
                                  : null,
                              enabled: !_loading,
                            ),
                            const SizedBox(height: 16),

                            // Rôle
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRole,
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
                                        () =>
                                            _selectedRole = value ?? 'student',
                                      );
                                    },
                            ),
                            const SizedBox(height: 16),

                            // Région
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRegion,
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
      },
    );
  }
}
