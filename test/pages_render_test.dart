// Renders every page with real responses captured from the backend
// (test/fixtures/admin_responses.json) and fails on any exception or layout overflow.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrobid_admin/core/api.dart';
import 'package:agrobid_admin/pages/audit_page.dart';
import 'package:agrobid_admin/pages/bids_page.dart';
import 'package:agrobid_admin/pages/dashboard_page.dart';
import 'package:agrobid_admin/pages/listings_page.dart';
import 'package:agrobid_admin/pages/login_page.dart';
import 'package:agrobid_admin/pages/prices_page.dart';
import 'package:agrobid_admin/pages/user_detail_page.dart';
import 'package:agrobid_admin/pages/users_page.dart';
import 'package:agrobid_admin/pages/verifications_page.dart';
import 'package:agrobid_admin/core/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final fixtures = jsonDecode(File('test/fixtures/admin_responses.json').readAsStringSync()) as Map<String, dynamic>;

/// Answers GETs from the captured responses instead of the network.
class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'http://fake', store: MemoryTokenStore());

  final calls = <String>[];

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add(path);
    final key = switch (path) {
      '/api/v1/admin/dashboard/stats' => 'dashboard',
      '/api/v1/admin/market/stats' => 'market',
      '/api/v1/admin/users' => 'users',
      '/api/v1/admin/verifications' => 'verifications',
      '/api/v1/admin/listings' => 'listings',
      '/api/v1/admin/bids' => 'bids',
      '/api/v1/prices' => 'prices',
      '/api/v1/prices/latest' => 'prices',
      '/api/v1/prices/history' => 'history',
      '/api/v1/admin/audit-logs' => 'audit',
      _ when path.endsWith('/documents') => 'documents',
      _ when path.startsWith('/api/v1/admin/users/') && path.contains('farmer') => 'user_farmer',
      _ when path.startsWith('/api/v1/admin/users/') => 'user_buyer',
      _ when path.startsWith('/api/v1/admin/listings/') => 'listing',
      _ => throw StateError('No fixture for $path'),
    };
    return jsonDecode(jsonEncode(fixtures[key])); // a fresh copy each time
  }

  @override
  Future<Uint8List> bytes(String path) async => Uint8List(0);
}

Future<void> render(WidgetTester tester, Widget page, {Size size = const Size(1400, 1000), bool fullScreen = false}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Pages normally sit inside the shell's scroll view; full-screen pages (login) bring their own Scaffold.
  await tester.pumpWidget(MaterialApp(home: fullScreen ? page : Scaffold(body: SingleChildScrollView(child: page))));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byIcon(Icons.error_outline), findsNothing, reason: 'page showed its error state');
}

void main() {
  final api = FakeApi();

  testWidgets('login', (tester) async {
    await render(tester, LoginPage(session: Session(api)), fullScreen: true);
    expect(find.text('AgroBid Admin'), findsOneWidget);
  });

  testWidgets('dashboard', (tester) async {
    await render(tester, DashboardPage(api: api));
    expect(find.text('Recent registrations'), findsOneWidget);
    expect(find.text('Open listings'), findsOneWidget);
  });

  testWidgets('users', (tester) async {
    await render(tester, UsersPage(api: api));
    expect(find.textContaining('Farmer'), findsWidgets);
  });

  testWidgets('user detail: buyer and farmer', (tester) async {
    await render(tester, UserDetailPage(api: api, userId: 'buyer-id'));
    expect(find.text('Identity verification'), findsOneWidget);
    expect(find.text('Ntn certificate'), findsOneWidget);
    await render(tester, UserDetailPage(api: api, userId: 'farmer-id'));
    expect(find.text('Main crops'), findsOneWidget);
    await tester.ensureVisible(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit farmer profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verification queue', (tester) async {
    await render(tester, VerificationsPage(api: api));
    expect(find.text('Verification queue'), findsOneWidget);
  });

  testWidgets('listings and listing detail', (tester) async {
    await render(tester, ListingsPage(api: api));
    expect(find.textContaining('Wheat'), findsWidgets);
    await render(tester, ListingDetailPage(api: api, listingId: 'x'));
    expect(find.text('Official price benchmark'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('bids', (tester) async {
    await render(tester, BidsPage(api: api));
    expect(find.text('Rejected'), findsWidgets);
  });

  testWidgets('prices, add dialog', (tester) async {
    await render(tester, PricesPage(api: api));
    expect(find.text('Okara, Punjab'), findsOneWidget);
    await tester.ensureVisible(find.text('Add price'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add price'));
    await tester.pumpAndSettle();
    expect(find.text('Add official price'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audit log', (tester) async {
    await render(tester, AuditPage(api: api));
    expect(find.text('Document viewed'), findsWidgets);
  });

  testWidgets('pages fit a phone-width screen', (tester) async {
    for (final page in <Widget>[DashboardPage(api: api), UsersPage(api: api), UserDetailPage(api: api, userId: 'b'), PricesPage(api: api)]) {
      await render(tester, page, size: const Size(390, 844));
    }
  });
}
