import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/core/utils/member_status_utils.dart';
import 'package:madaurore/data/repositories/app_auth_provider.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/presentation/screens/dashboard/student/justification_upload_screen.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:madaurore/presentation/screens/students/coordinator/student_list_coordinator_screen.dart';

class DashboardCoordoScreen extends StatefulWidget {
  static const routeName = '/coordinator/dashboard_coordo';

  const DashboardCoordoScreen({super.key});

  @override
  DashboardCoordoScreenState createState() => DashboardCoordoScreenState();
}

class DashboardCoordoScreenState extends State<DashboardCoordoScreen> {
  final RequestRepository _requestRepository = RequestRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    final auth = Provider.of<AppAuthProvider>(context, listen: false);
    if (auth.userModel?.role != 'regional_coordinator' ||
        auth.userModel?.status != 'approved') {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AppAuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          'Coordinateur Régional',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Membres de ma région',
            onPressed: () {
              Navigator.pushNamed(context, '/coordinator/member-list');
            },
          ),
          IconButton(
            icon: const Icon(Icons.school),
            tooltip: 'Étudiants de ma région',
            onPressed: () {
              Navigator.pushNamed(
                context,
                StudentListCoordinatorScreen.routeName,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: auth.userModelStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Profil non trouvé'));
          }

          final userModel = snapshot.data!;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildProfileCard(userModel),
                const SizedBox(height: 20),
                _buildStatsSection(userModel.region),
                const SizedBox(height: 20),
                _buildRequestsToReviewSection(userModel.region),
              ],
            ),
          );
        },
      ),
    );
  }

  // ========== PROFILE CARD ==========
  Widget _buildProfileCard(UserModel userModel) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.accent,
                    backgroundImage: userModel.photoUrl != null
                        ? NetworkImage(userModel.photoUrl!)
                        : null,
                    child: userModel.photoUrl == null
                        ? Icon(
                            Icons.admin_panel_settings,
                            size: 45,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/profile/edit');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                userModel.fullName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Région: ${userModel.region}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  'Coordinateur Régional',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                backgroundColor: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _streamRegionalStudents(String region) {
    return _requestRepository
        .getRequestsByRegionStream(region, limit: 500)
        .asyncMap((requests) async {
          final students = <Map<String, dynamic>>[];
          final userIds = <String>{};
          final userCache = <String, UserModel?>{};

          for (final request in requests) {
            if (userIds.add(request.userId)) {
              userCache[request.userId] = await _fetchUserData(request.userId);
              students.add({
                'request': request,
                'user': userCache[request.userId],
              });
            }
          }

          return students;
        });
  }

  Future<UserModel?> _fetchUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) return UserModel.fromDocument(doc);
    } catch (e) {
      debugPrint('Erreur fetch user: $e');
    }
    return null;
  }

  String _effectiveMemberStatus(RequestModel request, UserModel? user) {
    return MemberStatusUtils.effective(
      request.memberStatus,
      user?.memberStatus,
    );
  }

  // ========== STATS SECTION ==========
  Widget _buildStatsSection(String region) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamRegionalStudents(region),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final students = snapshot.data!;

        final pending = students
            .where(
              (student) => (student['request'] as RequestModel).isEnAttente,
            )
            .length;
        final nouveau = students.where((student) {
          final request = student['request'] as RequestModel;
          final user = student['user'] as UserModel?;
          return MemberStatusUtils.isNew(_effectiveMemberStatus(request, user));
        }).length;
        final ancien = students.where((student) {
          final request = student['request'] as RequestModel;
          final user = student['user'] as UserModel?;
          return MemberStatusUtils.isOld(_effectiveMemberStatus(request, user));
        }).length;
        final nonClasse = students.where((student) {
          final request = student['request'] as RequestModel;
          final user = student['user'] as UserModel?;
          return MemberStatusUtils.isUnclassified(
            _effectiveMemberStatus(request, user),
          );
        }).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 640 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: crossAxisCount == 4 ? 1.25 : 1.5,
              children: [
                _buildStatCard(
                  'À traiter',
                  pending.toString(),
                  AppColors.pending,
                  Icons.pending_actions,
                ),
                _buildStatCard(
                  'Nouveau',
                  nouveau.toString(),
                  Colors.blue,
                  Icons.person_add,
                ),
                _buildStatCard(
                  'Ancien',
                  ancien.toString(),
                  Colors.purple,
                  Icons.person,
                ),
                _buildStatCard(
                  'Non classé',
                  nonClasse.toString(),
                  Colors.orange,
                  Icons.help_outline,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ========== REQUESTS SECTION ==========
  Widget _buildRequestsToReviewSection(String region) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demandes de ma Région',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<RequestModel>>(
          stream: _requestRepository.getRequestsByRegionStream(
            region,
            limit: 500,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune demande pour cette région',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _buildRequestCard(request);
              },
            );
          },
        ),
      ],
    );
  }

  // ========== REQUEST CARD ==========
  Widget _buildRequestCard(RequestModel request) {
    final statusColor = request.isEnAttente
        ? AppColors.pending
        : request.isApprouveAdmin
        ? AppColors.success
        : AppColors.error;

    final statusIcon = request.isEnAttente
        ? Icons.schedule
        : request.isApprouveAdmin
        ? Icons.check_circle
        : Icons.cancel;

    final memberStatusColor = request.isNouveauMembre
        ? Colors.blue
        : request.isAncienMembre
        ? Colors.purple
        : AppColors.textSecondary;

    final memberStatusLabel = request.isNouveauMembre
        ? '👤 Nouveau Membre'
        : request.isAncienMembre
        ? '👥 Ancien Membre'
        : '❓ À Classifier';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          request.titre,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'Montant: ${request.montant ?? 0} Ar | Statut: ${request.statut}',
          style: GoogleFonts.poppins(fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détails',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow('Raison:', request.reason ?? 'N/A'),
                _buildDetailRow('Localisation:', request.localisation ?? 'N/A'),
                _buildDetailRow('Montant:', '${request.montant ?? 0} Ar'),

                if (request.studentBio != null &&
                    request.studentBio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Bio Étudiant:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.studentBio!,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: memberStatusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: memberStatusColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        request.isNouveauMembre
                            ? Icons.person_add
                            : request.isAncienMembre
                            ? Icons.people
                            : Icons.help,
                        color: memberStatusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        memberStatusLabel,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: memberStatusColor,
                        ),
                      ),
                    ],
                  ),
                ),

                if (request.hasCoordonotes) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Mes Notes:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.coordoNotes!,
                      style: GoogleFonts.poppins(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                if (request.pdfUrl != null) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await launchUrl(
                          Uri.parse(request.pdfUrl!),
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Impossible d\'ouvrir le PDF'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Voir PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (request.isApprouveConseil ||
                    request.justificationUrl != null) ...[
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            JustificationUploadScreen(requestId: request.id),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Suivi de l\'aide'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ✅ BOUTONS SEULEMENT SI EN ATTENTE
                if (request.isEnAttente) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showMemberStatusDialog(request),
                          icon: const Icon(Icons.edit),
                          label: const Text('Classer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: memberStatusColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(request),
                          icon: const Icon(Icons.check),
                          label: const Text('Approuver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectRequest(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Rejeter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, color: statusColor),
                        const SizedBox(width: 8),
                        Text(
                          request.statut.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== MEMBER STATUS DIALOG ==========
  Future<void> _showMemberStatusDialog(RequestModel request) async {
    final notesController = TextEditingController(
      text: request.coordoNotes ?? '',
    );

    String selectedStatus = request.memberStatus ?? 'nouveau_membre';

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Classifier le Membre'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Statut du membre:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: selectedStatus,
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                    });
                  },
                  child: Column(
                    children: [
                      Radio<String>(value: 'nouveau_membre'),
                      const Text('👤 Nouveau Membre'),
                      Radio<String>(value: 'ancien_membre'),
                      const Text('👥 Ancien Membre'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mes notes (optionnel):',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                    labelText: 'Remarques...',
                    hintText: 'Très motivé, bonne situation...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);

      await FirestoreService.instance.addCoordonotes(
        requestId: request.id,
        memberStatus: selectedStatus,
        notes: notesController.text.trim(),
        coordoId: auth.userModel!.uid,
        coordoName: auth.userModel!.fullName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Statut enregistré'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ========== APPROVE REQUEST ==========
  Future<void> _approveRequest(RequestModel request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approuver?'),
        content: const Text('Envoyer à l\'Admin pour validation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Oui'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final auth = Provider.of<AppAuthProvider>(context, listen: false);

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'coordoNotesAt': FieldValue.serverTimestamp(),
            'coordoNotesBy': auth.userModel!.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Envoyée à l\'Admin'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ========== REJECT REQUEST ==========
  Future<void> _rejectRequest(RequestModel request) async {
    final reasonController = TextEditingController();

    final rejected = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            labelText: 'Motif',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (rejected != true || reasonController.text.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(request.id)
          .update({
            'statut': 'rejected',
            'reason': reasonController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Rejetée'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
