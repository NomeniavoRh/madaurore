import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/presentation/screens/auth/login_screen.dart';
import 'package:madaurore/core/constants/app_colors.dart';

class DashboardCoordoScreen extends StatefulWidget {
  static const routeName = '/coordinator/dashboard_coordo';

  const DashboardCoordoScreen({super.key});

  @override
  DashboardCoordoScreenState createState() => DashboardCoordoScreenState();
}

class DashboardCoordoScreenState extends State<DashboardCoordoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);
      // FIX: Vérifier 'regional_coordinator' au lieu de 'responsable'
      if (auth.userModel?.role != 'regional_coordinator' || 
          auth.userModel?.status != 'approved') {
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Tableau de bord Coordinateur',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
            },
            icon: const Icon(Icons.logout, color: AppColors.accent),
          ),
        ],
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Profil
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 2),
                    ),
                  ],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<UserModel?>(
                    stream: auth.userModelStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Text(
                          'Erreur lors du chargement du profil',
                        );
                      }
                      if (snapshot.hasData) {
                        final profile = snapshot.data!;
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.accent,
                              backgroundImage: profile.photoUrl != null
                                  ? NetworkImage(profile.photoUrl!)
                                  : null,
                              child: profile.photoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 28,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.fullName,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    profile.region,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return const Text('Profil non trouvé');
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Section Demandes
              Text(
                'Demandes dans votre région',
                style: GoogleFonts.poppins(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('requests')
                      .where('region', isEqualTo: auth.userModel?.region)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text(
                        'Erreur lors du chargement des demandes',
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('Aucune demande dans votre région'),
                      );
                    }
                    final requests = snapshot.data!.docs
                        .map((doc) => RequestModel.fromDocument(doc))
                        .toList();
                    return ListView.builder(
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              request.titre,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Statut: ${request.statut}',
                              style: GoogleFonts.poppins(),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: AppColors.primary,
                              ),
                              onPressed: () async {},
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}