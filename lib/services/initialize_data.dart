import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:madaurore/data/models/user_model.dart';
import 'package:madaurore/services/firestore_service.dart';
import 'package:path_provider/path_provider.dart';

Future<void> initializeData() async {
  final firestoreService = FirestoreService.instance;
  final firestore = FirebaseFirestore.instance;

  // Ajouter un utilisateur étudiant (Cathy)
  final studentDoc = await firestore.collection('users').doc('user123').get();
  if (!studentDoc.exists) {
    final student = UserModel(
      uid: 'user123',
      email: 'cathynomeniavo@gmail.com',
      fullName: 'ANDRIAMANANTENA Nomeniavo Cathy',
      region: 'Fianarantsoa',
      role: 'étudiant',
      status: 'active',
      createdAt: Timestamp.now().toDate(),
      photoUrl: '', // Convertit Timestamp en DateTime
    );
    await firestoreService.addUser(student);
  }

  // Ajouter une demande de parrainage (crée 'sponsorship_requests' et 'validation_requests')
  final sponsorshipDoc = await firestore
      .collection('sponsorship_requests')
      .doc('sponsorship_1696435200000')
      .get();
  if (!sponsorshipDoc.exists) {
    final dir = await getTemporaryDirectory();
    final pdfFile = File('${dir.path}/sample.pdf'); // Fichier PDF de test
    final justificationFile = File(
      '${dir.path}/justification.pdf',
    ); // Fichier PDF de test
    await firestoreService.addSponsorshipRequest(
      titre: 'Demande de parrainage pour études',
      userId: 'user123',
      userEmail: 'cathynomeniavo@gmail.com',
      region: 'Fianarantsoa',
      familySituation:
          'Je vis avec mon père, qui a perdu la vue en raison de complications liées à son diabète. Ma mère, secrétaire, assume la charge principale de la famille.',
      pdfFile: pdfFile,
      justificationFile: justificationFile,
    );
  }

  // Ajouter un admin et un coordinateur pour tester
  final adminDoc = await firestore.collection('users').doc('admin1').get();
  if (!adminDoc.exists) {
    final admin = UserModel(
      uid: 'admin1',
      email: 'admin@example.com',
      fullName: 'Admin User',
      region: 'Antananarivo',
      role: 'admin',
      status: 'active',
      createdAt: Timestamp.now().toDate(),
      photoUrl: '', // Convertit Timestamp en DateTime
    );
    await firestoreService.addUser(admin);
  }

  final coordoDoc = await firestore.collection('users').doc('coordo1').get();
  if (!coordoDoc.exists) {
    final coordo = UserModel(
      uid: 'coordo1',
      email: 'coordo@example.com',
      fullName: 'Coordinateur User',
      region: 'Fianarantsoa',
      role: 'coordinateur',
      status: 'active',
      createdAt: Timestamp.now().toDate(),
      photoUrl: '',
    );
    await firestoreService.addUser(coordo);
  }
}
