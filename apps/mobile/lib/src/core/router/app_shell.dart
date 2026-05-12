import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent shell that wraps all bottom-nav destinations.
///
/// Accepts a [StatefulNavigationShell] from go_router's [StatefulShellRoute],
/// which manages independent navigation stacks per branch and preserves their
/// state across tab switches.
///
/// Uses Material 3 [NavigationBar] (not the legacy [BottomNavigationBar]).
/// Re-tapping the active destination navigates back to its initial location
/// (i.e. pops the branch's stack to root).
class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          navigationShell.goBranch(
            index,
            // Re-tapping the active tab navigates back to the branch root.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'My Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
