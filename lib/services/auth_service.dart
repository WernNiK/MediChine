import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class AuthService {
  static FirebaseAuth? _auth;
  static bool _isInitialized = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static Future<void> _ensureInitialized() async {
    if (_isInitialized && _auth != null) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase initialized');
      }
      _auth = FirebaseAuth.instance;
      _isInitialized = true;
    } catch (e) {
      print('⚠️ Firebase init: $e');
    }
  }

  Future<User?> get currentUser async {
    await _ensureInitialized();
    return _auth?.currentUser;
  }

  Future<bool> get isLoggedIn async {
    await _ensureInitialized();
    return _auth?.currentUser != null;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    await _ensureInitialized();

    if (_auth == null) throw 'Authentication service not available';

    try {
      UserCredential userCredential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();

    if (_auth == null) throw 'Authentication service not available';

    try {
      await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    }
  }

  Future<void> signInWithGoogle() async {
    await _ensureInitialized();

    if (_auth == null) throw 'Authentication service not available';

    try {
      // Completely sign out first
      await _googleSignIn.signOut();
      await Future.delayed(const Duration(milliseconds: 500));

      // Start fresh sign-in flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google sign-in cancelled by user');
        return;
      }

      print('Google user: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print('Got Google auth tokens');

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw 'Failed to obtain Google credentials';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Signing in to Firebase...');

      final userCredential = await _auth!.signInWithCredential(credential);

      print('✅ Signed in: ${userCredential.user?.email}');

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      throw _getErrorMessage(e.code);
    } catch (e) {
      print('Google Sign-In Error: $e');
      // Ignore the PigeonUserDetails error - it's harmless
      if (e.toString().contains('PigeonUserDetails')) {
        print('⚠️ Ignoring PigeonUserDetails error (harmless)');
        // Check if sign-in actually succeeded
        if (_auth?.currentUser != null) {
          print('✅ User is signed in despite error');
          return;
        }
      }
      throw 'Google sign-in failed. Please try again.';
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _auth?.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _ensureInitialized();

    if (_auth == null) throw 'Authentication service not available';

    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}