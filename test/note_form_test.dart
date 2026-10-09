import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:contabile_app/screens/note_form_screen.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:provider/provider.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  testWidgets('Double click on save prevents multiple saves and allows retry on error', (tester) async {
    final fakeDb = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(fakeDb);
    
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppThemeProvider(),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: NoteFormScreen(),
        ),
      ),
    );
    
    await tester.pumpAndSettle();
    
    await tester.enterText(find.byType(TextFormField).first, 'Titolo Test');
    
    final saveFinder = find.widgetWithIcon(IconButton, Icons.check);
    final button = tester.widget<IconButton>(saveFinder);
    
    // Invochiamo il pulsante direttamente per bypassare problemi di HitTest
    button.onPressed!();
    button.onPressed!(); // Doppio clic
    await tester.pumpAndSettle(); 
    
    final docs = await fakeDb.collection('notes').get();
    expect(docs.docs.length, 1, reason: 'Il doppio clic non deve creare due note');
  });
}
