import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreTestScreen extends StatefulWidget {
  const FirestoreTestScreen({super.key});

  @override
  State<FirestoreTestScreen> createState() => _FirestoreTestScreenState();
}

class _FirestoreTestScreenState extends State<FirestoreTestScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _testResult = 'Tap button to test Firestore connection';
  bool _isTesting = false;

  Future<void> _testFirestore() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing Firestore...';
    });

    try {
      // Test 1: Write to a test document
      final testRef = _firestore.collection('rooms').doc('test');
      await testRef.set({
        'test': 'Hello from Flutter',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Test 2: Read the document back
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        // Test 3: Write to a subcollection
        await testRef.collection('callerCandidates').add({
          'test': 'subcollection test',
        });

        // Test 4: Clean up
        final candidates = await testRef.collection('callerCandidates').get();
        for (var doc in candidates.docs) {
          await doc.reference.delete();
        }
        await testRef.delete();

        setState(() {
          _testResult = '✅ SUCCESS!\n\n'
              'Firestore is working correctly.\n'
              'All permissions are set up properly.\n\n'
              'You can now use the video call features!';
          _isTesting = false;
        });
      }
    } catch (e) {
      String errorMessage = e.toString();
      String solution = '';

      if (errorMessage.contains('permission-denied')) {
        solution = '\n\n🔧 SOLUTION:\n'
            '1. Go to Firebase Console\n'
            '2. Click Firestore Database > Rules\n'
            '3. Replace with:\n\n'
            'rules_version = \'2\';\n'
            'service cloud.firestore {\n'
            '  match /databases/{database}/documents {\n'
            '    match /rooms/{roomId} {\n'
            '      allow read, write: if true;\n'
            '      match /{document=**} {\n'
            '        allow read, write: if true;\n'
            '      }\n'
            '    }\n'
            '  }\n'
            '}\n\n'
            '4. Click Publish\n'
            '5. Wait 10 seconds\n'
            '6. Test again';
      } else if (errorMessage.contains('NOT_FOUND')) {
        solution = '\n\n🔧 SOLUTION:\n'
            'Firestore database not created.\n'
            'Go to Firebase Console and enable Firestore.';
      }

      setState(() {
        _testResult = '❌ FAILED\n\n'
            'Error: $errorMessage$solution';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Setup Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Firestore Connection Test',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This will test if your Firestore database is properly configured.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isTesting ? null : _testFirestore,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isTesting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Testing...'),
                      ],
                    )
                  : const Text('Test Firestore Connection'),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _testResult,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

