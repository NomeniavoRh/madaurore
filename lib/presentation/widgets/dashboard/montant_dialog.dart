import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:madaurore/core/constants/app_colors.dart';
import 'package:madaurore/data/models/request_model.dart';

/// Dialog pour fixer le montant à accorder
Future<void> showMontantDialog(
  BuildContext context,
  RequestModel request,
  Function(double) onConfirm,
) async {
  final controller = TextEditingController(
    text: (request.montant ?? 0).toString(),
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Montant pour ${request.titre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Demandé: ${request.montant ?? 0} Ar',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.pending,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Montant à accorder (Ar)',
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  final montant = double.tryParse(controller.text) ?? 0;
  onConfirm(montant);
}
