import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'settings.dart';
import 'explore.dart';
import 'wardrobe.dart';
import 'looks.dart';
import 'chat.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: paper,
    ),
  );
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const MusaApp()));
  try {
    await state.initialize();
  } catch (_) {
    state.ready = true;
    state.syncError = 'No se pudo iniciar Musa. Cierra y abre la aplicación.';
    state.navigate(0);
  }
}

class MusaApp extends StatelessWidget {
  const MusaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Musa · Tu estilo',
    debugShowCheckedModeBanner: false,
    theme: musaTheme(),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6),
      ),
      child: Container(
        color: const Color(0xFFECE5DD),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ),
    ),
    home: const MusaHome(),
  );
}

class MusaHome extends StatelessWidget {
  const MusaHome({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.ready) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MuseMark(size: 72),
              const SizedBox(height: 22),
              Text('musa', style: editorial(58, color: plum)),
              const SizedBox(height: 12),
              const Text('Un poquito más tú.', style: TextStyle(color: muted)),
              const SizedBox(height: 35),
              const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 19, 5),
              child: Row(
                children: [
                  const MuseMark(size: 23),
                  const SizedBox(width: 8),
                  Text('musa', style: editorial(38, color: plum)),
                  Expanded(
                    child: Text(
                      (s.profile['name'] as String).isEmpty
                          ? 'UN ESPACIO PARA TI'
                          : 'HOLA, ${(s.profile['name'] as String).split(' ').first.toUpperCase()}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.35,
                        color: muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton(
                    tooltip: 'Mi espacio y configuración',
                    onPressed: () => openSettings(context),
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: line),
                      minimumSize: const Size(38, 38),
                    ),
                    icon: const Icon(
                      Icons.person_outline_rounded,
                      size: 20,
                      color: plum,
                    ),
                  ),
                ],
              ),
            ),
            if (s.syncError != null)
              Container(
                color: const Color(0xFFF4E7DB),
                padding: const EdgeInsets.fromLTRB(20, 7, 8, 7),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 17, color: plum),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        s.syncError!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reintentar sincronización',
                      onPressed: () async {
                        try {
                          if (s.connected) {
                            await s.refresh();
                          } else {
                            await ensureConnected(context);
                          }
                        } catch (e) {
                          if (context.mounted) notice(context, e);
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: s.tab,
                children: const [
                  ExploreScreen(),
                  WardrobeScreen(),
                  LooksScreen(),
                  ChatScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: paper,
          border: Border(top: BorderSide(color: line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Row(
              children: [
                _NavItem(
                  index: 0,
                  label: 'Descubrir',
                  icon: Icons.style_outlined,
                  active: Icons.style_rounded,
                ),
                _NavItem(
                  index: 1,
                  label: 'Armario',
                  icon: Icons.checkroom_outlined,
                  active: Icons.checkroom_rounded,
                ),
                _NavItem(
                  index: 2,
                  label: 'Mis looks',
                  icon: Icons.bookmarks_outlined,
                  active: Icons.bookmarks_rounded,
                ),
                _NavItem(
                  index: 3,
                  label: 'Musa',
                  icon: Icons.chat_bubble_outline_rounded,
                  active: Icons.chat_bubble_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon, active;
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.active,
  });
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>(),
        selected = context.watch<AppState>().tab == index;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () => s.navigate(index),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? blush.withValues(alpha: .65)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    selected ? active : icon,
                    size: 22,
                    color: selected ? plum : muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? plum : muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
