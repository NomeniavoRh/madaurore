import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/user_model.dart';

/// Card profil pour les dashboards
class ProfileCard extends StatelessWidget {
  final UserModel userModel;
  final String role;
  final IconData roleIcon;
  final String chipLabel;
  final VoidCallback? onEditProfileTap;

  const ProfileCard({
    super.key,
    required this.userModel,
    required this.role,
    required this.roleIcon,
    required this.chipLabel,
    this.onEditProfileTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    radius: 45,
                    backgroundColor: AppColors.accent,
                    backgroundImage: userModel.photoUrl != null
                        ? NetworkImage(userModel.photoUrl!)
                        : null,
                    child: userModel.photoUrl == null
                        ? Icon(roleIcon, size: 45, color: Colors.white)
                        : null,
                  ),
                  if (onEditProfileTap != null)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: onEditProfileTap,
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
                role,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  chipLabel,
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
}
