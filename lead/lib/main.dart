import 'package:flutter/material.dart';
import 'dart:io';
import 'splash_screen.dart';

import 'services/call_service.dart';
import 'modules/leads/widgets/add_lead_modal.dart';
import 'modules/dashboard/dashboard_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_service.dart';
import 'theme/theme_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/fcm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  try {
    await Firebase.initializeApp();
    await FCMService.init();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Init Call Service
  final callService = CallService();
  await callService.init();

  callService.onAddLeadRequest = (number) {
    if (navigatorKey.currentState != null) {
      // Direct push of AddLeadModal. No outer Scaffold here!
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => AddLeadModal(
            initialPhoneNumber: number,
            onCancel: () {
              // Redirect to Dashboard on cancel
              navigatorKey.currentState!.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const DashboardPage(initialIndex: 0),
                ),
                (route) => false,
              );
            },
            onSuccess: () {
              // Navigate to Leads tab of DashboardPage
              navigatorKey.currentState!.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const DashboardPage(initialIndex: 1),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );
    }
  };

  final themeService = await ThemeService.create();
  runApp(MyApp(themeService: themeService));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.themeService});

  final ThemeService themeService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      themeService: widget.themeService,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Lead App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: widget.themeService.themeMode,
        home: const SplashScreen(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
