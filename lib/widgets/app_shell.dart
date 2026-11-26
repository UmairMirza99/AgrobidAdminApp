import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/session.dart';
import '../core/theme.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon, this.path, this.group);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final String group;
}

const navItems = [
  NavItem('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard, '/', 'Overview'),
  NavItem('Verification queue', Icons.fact_check_outlined, Icons.fact_check, '/verifications', 'People'),
  NavItem('Users', Icons.people_outline, Icons.people, '/users', 'People'),
  NavItem('Listings', Icons.grass_outlined, Icons.grass, '/listings', 'Marketplace'),
  NavItem('Bids', Icons.gavel_outlined, Icons.gavel, '/bids', 'Marketplace'),
  NavItem('Official prices', Icons.price_change_outlined, Icons.price_change, '/prices', 'Marketplace'),
  NavItem('Audit log', Icons.receipt_long_outlined, Icons.receipt_long, '/audit', 'System'),
];

/// Dark sidebar on wide screens (a drawer on narrow ones), a top bar with the page title and the admin menu.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.session, required this.location, required this.child});

  final Session session;
  final String location;
  final Widget child;

  int get _selected {
    for (var i = navItems.length - 1; i >= 0; i--) {
      final path = navItems[i].path;
      if (path == '/' ? location == '/' : location.startsWith(path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final nav = _Sidebar(selected: _selected, session: session, inDrawer: !wide);
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: AppColors.sidebar, shape: const RoundedRectangleBorder(), child: nav),
      body: Row(children: [
        if (wide) SizedBox(width: 256, child: ColoredBox(color: AppColors.sidebar, child: nav)),
        Expanded(
          child: Column(children: [
            _TopBar(session: session, item: navItems[_selected], wide: wide),
            Expanded(
              child: SelectionArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(wide ? 32 : 16, wide ? 28 : 16, wide ? 32 : 16, 32),
                  child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: child)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.item, required this.wide});

  final Session session;
  final NavItem item;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = session.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 8),
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        if (!wide)
          Builder(builder: (context) => IconButton(tooltip: 'Menu', onPressed: () => Scaffold.of(context).openDrawer(), icon: const Icon(Icons.menu))),
        Expanded(
          child: Row(children: [
            if (wide) ...[
              Text(item.group, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right, size: 18, color: AppColors.muted)),
            ],
            Flexible(child: Text(item.label, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          ]),
        ),
        if (wide) ...[
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Text(DateFormat('EEE, d MMM yyyy').format(DateTime.now()), style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
          const SizedBox(width: 20),
          Container(width: 1, height: 28, color: AppColors.border),
          const SizedBox(width: 12),
        ],
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 52),
          onSelected: (value) {
            if (value == 'logout') session.logout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                Text((session.user?['email'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 18), SizedBox(width: 10), Text('Sign out')])),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.primary,
                child: Text(initials.isEmpty ? 'A' : initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              if (wide) ...[
                const SizedBox(width: 10),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const Text('Administrator', style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.session, required this.inDrawer});

  final int selected;
  final Session session;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? group;
    for (var i = 0; i < navItems.length; i++) {
      final item = navItems[i];
      if (item.group != group) {
        group = item.group;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(group.toUpperCase(), style: const TextStyle(color: Color(0xFF6F8A79), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.1)),
        ));
      }
      children.add(_NavTile(
        item: item,
        selected: i == selected,
        onTap: () {
          if (inDrawer) Navigator.pop(context);
          context.go(item.path);
        },
      ));
    }

    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1E3A2A)))),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E8B4F), AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.agriculture, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AgroBid', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              Text('Admin console', style: TextStyle(color: AppColors.sidebarText, fontSize: 11.5)),
            ]),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 12), children: children)),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.sidebarHover, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            const Expanded(child: Text('Every admin action is recorded in the audit log', style: TextStyle(color: AppColors.sidebarText, fontSize: 11.5, height: 1.35))),
            IconButton(
              tooltip: 'Sign out',
              visualDensity: VisualDensity.compact,
              onPressed: session.logout,
              icon: const Icon(Icons.logout, color: AppColors.sidebarText, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.sidebarHover,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(selected ? item.selectedIcon : item.icon, size: 20, color: selected ? Colors.white : AppColors.sidebarText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: selected ? Colors.white : const Color(0xFFD3DED7), fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
