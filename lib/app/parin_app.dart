import 'package:flutter/material.dart';
import 'app_state.dart';
import 'i18n.dart';
import '../theme/theme_catalog.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/workspace_screen.dart';

class ParinApp extends StatefulWidget {
  const ParinApp({super.key});
  @override State<ParinApp> createState() => _ParinAppState();
}

class _ParinAppState extends State<ParinApp> {
  final appState = AppState();
  bool ready = false;

  @override
  void initState() {
    super.initState();
    appState.load().whenComplete(() => setState(() => ready = true));
  }

  @override
  void dispose() {
    appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final brightness = appState.brightness(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Parin Office',
          locale: appState.locale,
          supportedLocales: AppI18n.supported,
          theme: ThemeCatalog.build(preset: appState.preset, brightness: brightness, amoled: appState.amoled),
          builder: (context, child) => Directionality(
            textDirection: AppI18n.isRtl(appState.locale) ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
          home: Shell(state: appState),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.state});
  final AppState state;
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final t = (String key) => AppI18n.t(widget.state.locale, key);
    final destinations = [
      (Icons.home_rounded, t('home')),
      (Icons.description_outlined, t('recent')),
      (Icons.dashboard_customize_outlined, t('dashboard')),
      (Icons.settings_outlined, t('settings')),
    ];
    final pages = [
      HomeScreen(state: widget.state),
      const WorkspaceScreen(filter: 'recent'),
      const WorkspaceScreen(filter: 'all'),
      SettingsScreen(state: widget.state),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final large = constraints.maxWidth >= 900;
        if (large) {
          return Scaffold(
            body: Row(children: [
              SizedBox(
                width: 256,
                child: NavigationRail(
                  extended: true,
                  selectedIndex: index,
                  onDestinationSelected: (value) => setState(() => index = value),
                  destinations: destinations.map((item) => NavigationRailDestination(icon: Icon(item.$1), label: Text(item.$2))).toList(),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[index]),
            ]),
          );
        }
        return Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: destinations.map((item) => NavigationDestination(icon: Icon(item.$1), label: item.$2)).toList(),
          ),
        );
      },
    );
  }
}
