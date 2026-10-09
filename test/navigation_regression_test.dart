import 'dart:io';
import 'package:flutter/services.dart';
import 'package:contabile_app/database/database_helper.dart';
import 'package:contabile_app/providers/app_theme_provider.dart';
import 'package:contabile_app/screens/main_screen.dart';
import 'package:contabile_app/screens/notes_screen.dart';
import 'package:contabile_app/screens/note_form_screen.dart';
import 'package:contabile_app/screens/deadlines_selection_screen.dart';
import 'package:contabile_app/widgets/app_sidebar.dart';
import 'package:contabile_app/widgets/app_drawer.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationFirebaseMock extends MockFirebaseApp {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    CoreInitializeResponse(name: '[DEFAULT]', options: CoreFirebaseOptions(
      apiKey: 'test', appId: 'test', messagingSenderId: 'test',
      projectId: 'test', storageBucket: 'test-only.invalid'), pluginConstants: {}),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestFirebaseCoreHostApi.setUp(NavigationFirebaseMock());
  late FakeFirebaseFirestore database;
  setUpAll(() async {
    await Firebase.initializeApp();
    // Real font metrics avoid Ahem-only layout failures in the full app flow.
    final font = FontLoader('Roboto');
    font.addFont(File('test/fixtures/roboto-regular.ttf').readAsBytes().then((bytes) => ByteData.sublistView(bytes)));
    await font.load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = FakeFirebaseFirestore();
    DatabaseHelper.setMockFirestore(database);
    await database.collection('notes').doc('existing').set({
      'title': 'Nota da conservare', 'content': 'Contenuto originale',
      'type': 'TEXT', 'creation_date': '2026-09-01',
    });
  });

  Future<void> showApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppThemeProvider(),
      child: MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: const MainScreen(role: 'User'))));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
  }

  Future<void> selectSection(WidgetTester tester, int index, bool desktop) async {
    if (desktop) {
      tester.widget<AppSidebar>(find.byType(AppSidebar)).onItemSelected(index);
    } else {
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffold.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Use the drawer's actual item callback without depending on its scroll position.
      tester.widget<AppDrawer>(find.byType(AppDrawer)).onItemSelected(index);
      scaffold.closeDrawer();
    }
    await tester.pump();
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  for (final desktop in [true, false]) {
    testWidgets('Section back restores history and leaves notes unchanged ($desktop)', (tester) async {
      await showApp(tester, desktop ? const Size(1440, 1000) : const Size(430, 932));
      await selectSection(tester, 4, desktop);
      expect(find.text('Nota da conservare'), findsOneWidget);
      await selectSection(tester, 3, desktop);
      expect(find.byType(DeadlinesSelectionScreen), findsOneWidget);
      expect(find.byTooltip('Torna alla sezione precedente'), findsOneWidget);
      await tester.tap(find.byTooltip('Torna alla sezione precedente'));
      await tester.pump();
      await tester.pump(); await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NotesScreen), findsOneWidget);
      expect(find.text('Nota da conservare'), findsOneWidget);
      await tester.tap(find.byTooltip('Torna alla sezione precedente'));
      await tester.pump();
      await tester.pump(); await tester.pump(const Duration(seconds: 1));
      expect(find.byType(NotesScreen), findsNothing);
      expect(find.byTooltip('Torna alla sezione precedente'), findsNothing);
      expect((await database.collection('notes').get()).docs.length, 1);
      expect((await database.collection('notes').doc('existing').get()).data()!['content'], 'Contenuto originale');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('System back closes the note editor before leaving the section', (tester) async {
    await showApp(tester, const Size(1440, 1000));
    await selectSection(tester, 4, true);
    await tester.tap(find.text('Nota da conservare'));
    await tester.pump();
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NoteFormScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NoteFormScreen), findsNothing);
    expect(find.text('Nota da conservare'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(); await tester.pump(const Duration(seconds: 1));
    expect(find.byType(NotesScreen), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
