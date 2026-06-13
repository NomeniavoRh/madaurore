import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/request_model.dart';
import 'package:madaurore/data/repositories/request_repository.dart';
import 'package:madaurore/presentation/widgets/dashboard/request_card_conseil.dart';

/// Liste des demandes à trancher pour le conseil
class ConseilRequestsList extends StatelessWidget {
  final FirebaseFirestore firestore;
  final RequestRepository _requestRepository = RequestRepository();

  ConseilRequestsList({super.key, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demandes à Trancher',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<RequestModel>>(
          stream: _requestRepository.getPendingCouncilApprovalStream(
            limit: 500,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data ?? [];

            if (requests.isEmpty) {
              return Center(
                child: Text(
                  'Aucune demande à trancher',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) => RequestCardConseil(
                request: requests[index],
                firestore: firestore,
              ),
            );
          },
        ),
      ],
    );
  }
}
