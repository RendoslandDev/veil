import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'screens/chats_screen.dart';
import 'screens/find_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/requests_screen.dart';
import 'services/repo.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Repo.init();
  runApp(const VeilApp());
}

class VeilApp extends StatelessWidget {
  const VeilApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Veil',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.light,
        home: StreamBuilder<void>(
          stream: Repo.changes,
          builder: (context, _) => Repo.currentId == null
              ? const WelcomeScreen()
              // Keyed by person so every tab reloads after switching.
              : HomeScreen(key: ValueKey(Repo.currentId)),
        ),
      );
}

/// First launch: just a name. No account, no password; everything stays on
/// this phone.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) return;
    await Repo.createPerson(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
          children: [
            Text('Only findable\nif you say yes', style: t.displaySmall),
            const SizedBox(height: 16),
            Text(
              'You can\'t stop people taking photos, but you can decide who finds you. No account needed: your face data stays on this phone.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
              ),
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ListenableBuilder(
                listenable: _name,
                builder: (context, _) => ArrowButton(
                  tooltip: 'Get started',
                  onPressed: _name.text.trim().isEmpty ? null : _start,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const LegalLinks(
                lead: 'You must be 18 or older. By continuing you agree to the ',
                align: TextAlign.left),
            const SizedBox(height: 24),
            const Center(child: Illustration(Icons.shield_moon_rounded, size: 240)),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Row(
            children: [
              Icon(Icons.shield_moon_rounded, color: VeilColors.orange),
              SizedBox(width: 8),
              Text('Veil'),
            ],
          ),
          actions: [
            if (kDebugMode) const _PersonSwitcher(),
            const SizedBox(width: 12),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: const [
            FindScreen(),
            RequestsScreen(),
            ChatsScreen(),
            PrivacyScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.person_search_rounded), label: 'Find'),
            NavigationDestination(icon: Icon(Icons.mark_email_unread), label: 'Requests'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
            NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Privacy'),
          ],
        ),
      );
}

/// Debug only: act as several people on one device to test both sides of a
/// request without a server.
class _PersonSwitcher extends StatelessWidget {
  const _PersonSwitcher();

  Future<void> _addPerson(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add test person'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) await Repo.createPerson(name);
  }

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Switch person (dev)',
        icon: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: VeilColors.orangeSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(Repo.myName()[0].toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: VeilColors.orange, fontSize: 18)),
        ),
        onSelected: (v) =>
            v == '+' ? _addPerson(context) : Repo.switchTo(v),
        itemBuilder: (_) => [
          for (final p in Repo.people())
            CheckedPopupMenuItem(
              value: p.id,
              checked: p.id == Repo.currentId,
              child: Text(p.name),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(value: '+', child: Text('DEV: add test person')),
        ],
      );
}
