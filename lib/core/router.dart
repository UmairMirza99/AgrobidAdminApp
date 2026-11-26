import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/audit_page.dart';
import '../pages/bids_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/listings_page.dart';
import '../pages/login_page.dart';
import '../pages/prices_page.dart';
import '../pages/user_detail_page.dart';
import '../pages/users_page.dart';
import '../pages/verifications_page.dart';
import '../widgets/app_shell.dart';
import 'session.dart';

GoRouter buildRouter(Session session) {
  final api = session.api;
  // Each page gets a key from its full URL so changing a filter in the address bar reloads it.
  Page<void> page(GoRouterState state, Widget child) => NoTransitionPage(key: ValueKey(state.uri.toString()), child: child);

  return GoRouter(
    refreshListenable: session,
    redirect: (context, state) {
      if (!session.ready) return null;
      final atLogin = state.matchedLocation == '/login';
      if (!session.loggedIn) return atLogin ? null : '/login';
      return atLogin ? '/' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => LoginPage(session: session)),
      ShellRoute(
        builder: (context, state, child) => AppShell(session: session, location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (context, state) => page(state, DashboardPage(api: api))),
          GoRoute(path: '/verifications', pageBuilder: (context, state) => page(state, VerificationsPage(api: api))),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => page(state, UsersPage(api: api, initialStatus: state.uri.queryParameters['status'], initialRole: state.uri.queryParameters['role'])),
            routes: [
              GoRoute(path: ':id', pageBuilder: (context, state) => page(state, UserDetailPage(api: api, userId: state.pathParameters['id']!))),
            ],
          ),
          GoRoute(
            path: '/listings',
            pageBuilder: (context, state) => page(state, ListingsPage(api: api, initialStatus: state.uri.queryParameters['status'], farmerId: state.uri.queryParameters['farmer_id'])),
            routes: [
              GoRoute(path: ':id', pageBuilder: (context, state) => page(state, ListingDetailPage(api: api, listingId: state.pathParameters['id']!))),
            ],
          ),
          GoRoute(path: '/bids', pageBuilder: (context, state) => page(state, BidsPage(api: api, initialStatus: state.uri.queryParameters['status'], buyerId: state.uri.queryParameters['buyer_id']))),
          GoRoute(path: '/prices', pageBuilder: (context, state) => page(state, PricesPage(api: api))),
          GoRoute(path: '/audit', pageBuilder: (context, state) => page(state, AuditPage(api: api))),
        ],
      ),
    ],
  );
}
