import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Obtener usuario actual
  User? get currentUser => _auth.currentUser;

  // Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ========== REGISTRO ==========
  Future<User?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Crear usuario en Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;

      if (user != null) {
        // Actualizar nombre de usuario en Auth
        await user.updateDisplayName(name);

        // Crear documento de usuario en Firestore (UNA SOLA VEZ)
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'displayName': name, // Mantener consistencia
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': null,
          'coverPhotoUrl': null,
        });

        return user;
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // ========== LOGIN ==========
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      rethrow;
    }
  }

  // ========== LOGOUT ==========
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // ========== RESET PASSWORD ==========
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // ========== ACTUALIZAR PERFIL (FOTO + NOMBRE) ==========
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      User? user = currentUser;
      if (user != null) {
        // Actualizar en Firebase Auth
        if (displayName != null) {
          await user.updateDisplayName(displayName);
        }
        if (photoURL != null) {
          await user.updatePhotoURL(photoURL);
        }

        // Actualizar en Firestore
        await _firestore.collection('users').doc(user.uid).update({
          if (displayName != null) 'displayName': displayName,
          if (displayName != null) 'name': displayName,
          if (photoURL != null) 'photoUrl': photoURL,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== ACTUALIZAR FOTO DE PORTADA ==========
  Future<void> updateCoverPhoto(String coverPhotoUrl) async {
    try {
      User? user = currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'coverPhotoUrl': coverPhotoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== OBTENER FOTO DE PORTADA ==========
  Future<String?> getCoverPhoto() async {
    try {
      User? user = currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data()?['coverPhotoUrl'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener portada: $e');
      return null;
    }
  }

  // ========== ELIMINAR CUENTA ==========
  Future<void> deleteAccount() async {
    try {
      User? user = currentUser;
      if (user != null) {
        // Eliminar documento de Firestore
        await _firestore.collection('users').doc(user.uid).delete();
        // Eliminar cuenta de Auth
        await user.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== REAUTENTICAR ==========
  Future<void> reauthenticateUser(String password) async {
    try {
      User? user = currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== CAMBIAR CONTRASEÑA ==========
  Future<void> changePassword(String newPassword) async {
    try {
      User? user = currentUser;
      if (user != null) {
        await user.updatePassword(newPassword);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== VERIFICAR EMAIL ==========
  Future<void> sendEmailVerification() async {
    try {
      User? user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      rethrow;
    }
  }

  // ========== RECARGAR USUARIO ==========
  Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      rethrow;
    }
  }
}
