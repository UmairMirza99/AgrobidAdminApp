// Runs every admin API call the panel makes against a real backend.
//
//   AGROBID_TEST_API=http://127.0.0.1:8000 AGROBID_TEST_USERS=users.json flutter test test/api_integration_test.dart
//
// users.json holds {"farmer": {"id", "token"}, "buyer1": {...}, "buyer2": {...}} for seeded accounts,
// plus an admin admin@example.com / smoke-admin-password-1. Skipped when the variables are not set.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agrobid_admin/core/api.dart';
import 'package:agrobid_admin/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

final _base = Platform.environment['AGROBID_TEST_API'];
final _usersFile = Platform.environment['AGROBID_TEST_USERS'];

final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(200, 0)]);
final pdf = Uint8List.fromList([...utf8.encode('%PDF-1.4\n'), ...List.filled(200, 48)]);

ApiClient asUser(String token) {
  final store = MemoryTokenStore()..write('access_token', token);
  return ApiClient(baseUrl: _base, store: store);
}

void main() {
  final skip = _base == null || _usersFile == null ? 'Set AGROBID_TEST_API and AGROBID_TEST_USERS to run' : false;

  test('admin panel API integration', () async {
    final users = jsonDecode(File(_usersFile!).readAsStringSync()) as Map<String, dynamic>;
    final farmer = asUser(users['farmer']['token']);
    final buyer = asUser(users['buyer1']['token']);
    final farmerId = users['farmer']['id'] as String;
    final buyerId = users['buyer1']['id'] as String;

    // Login through the same Session the UI uses.
    final api = ApiClient(baseUrl: _base, store: MemoryTokenStore());
    final session = Session(api);
    await expectLater(session.login('admin@example.com', 'wrong-password-123'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    await session.login('admin@example.com', 'smoke-admin-password-1');
    expect(session.loggedIn, isTrue);
    expect(session.user!['role'], 'ADMIN');

    // Users upload documents (multipart through ApiClient.upload) and submit.
    for (final (client, types) in [
      (farmer, ['CNIC_FRONT', 'CNIC_BACK']),
      (buyer, ['CNIC_FRONT', 'CNIC_BACK', 'NTN_CERTIFICATE']),
    ]) {
      for (final t in types) {
        await client.upload('/api/v1/users/me/documents', bytes: t == 'NTN_CERTIFICATE' ? pdf : png, filename: '$t.png', fields: {'document_type': t});
      }
      await client.post('/api/v1/users/me/verification/submit');
    }
    await farmer.upload('/api/v1/users/me/photo', bytes: png, filename: 'me.png', method: 'PUT');

    // Dashboard
    final stats = await api.get('/api/v1/admin/dashboard/stats') as Map<String, dynamic>;
    expect(stats['pending_verification_reviews'], 2);
    expect(stats['recent_registrations'], isA<List>());
    final market = await api.get('/api/v1/admin/market/stats') as Map<String, dynamic>;
    expect(market['listings'], containsPair('OPEN', 0));
    expect(market.keys, containsAll(['bids', 'accepted_quantity_kg', 'official_prices', 'latest_price_date']));

    // Users list with every filter the page sends (null filters are dropped).
    final list = await api.get('/api/v1/admin/users', query: {'search': '', 'role': 'BUYER', 'status': 'PENDING_APPROVAL', 'identity_verified': 'false', 'page': 1, 'page_size': 25}) as Map<String, dynamic>;
    expect(list['total'], greaterThanOrEqualTo(1));
    expect((list['items'] as List).first['buyer_profile']['district'], isNotNull);

    // Verification queue -> user detail -> documents
    final queue = await api.get('/api/v1/admin/verifications', query: {'status': 'PENDING', 'submitted': 'true', 'page': 1, 'page_size': 25}) as List;
    expect(queue.map((r) => r['user_id']), containsAll([farmerId, buyerId]));
    expect(queue.first.keys, containsAll(['user_name', 'user_role', 'submitted_at', 'document_count']));
    final detail = await api.get('/api/v1/admin/users/$buyerId') as Map<String, dynamic>;
    expect(detail['verification']['status'], 'UNDER_REVIEW');
    expect(detail['completion']['percent'], isA<int>());
    final docs = (await api.get('/api/v1/admin/users/$buyerId/documents') as List).cast<Map<String, dynamic>>();
    expect(docs, hasLength(3));
    final ntn = docs.firstWhere((d) => d['document_type'] == 'NTN_CERTIFICATE');
    expect(await api.bytes('/api/v1/admin/documents/${ntn['id']}/file'), pdf);
    await api.post('/api/v1/admin/documents/${docs.first['id']}/approve');
    await expectLater(api.post('/api/v1/admin/documents/${docs.first['id']}/approve'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)));

    // Decisions with reasons; a too-short reason is a 422 with field errors.
    await expectLater(api.post('/api/v1/admin/verifications/$buyerId/approve', body: {'reason': 'ok'}), throwsA(isA<ApiException>().having((e) => e.fieldErrors, 'fields', isNotEmpty)));
    final approved = await api.post('/api/v1/admin/verifications/$buyerId/approve', body: {'reason': 'Documents match CNIC'}) as Map<String, dynamic>;
    expect(approved['account_status'], 'ACTIVE');
    await api.post('/api/v1/admin/verifications/$farmerId/approve', body: {'reason': 'Documents match CNIC'});

    // Profile edit, photo view and removal (DELETE with a JSON body), suspend / activate.
    final edited = await api.put('/api/v1/admin/users/$farmerId/profile', body: {'district': 'Okara', 'main_crops': ['WHEAT', 'MAIZE'], 'reason': 'Corrected after call'}) as Map<String, dynamic>;
    expect(edited['farmer_profile']['district'], 'Okara');
    expect(await api.bytes('/api/v1/admin/users/$farmerId/photo'), png);
    await api.delete('/api/v1/admin/users/$farmerId/photo', body: {'reason': 'Inappropriate image'});
    await expectLater(api.bytes('/api/v1/admin/users/$farmerId/photo'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'No profile photo')));
    await api.post('/api/v1/admin/users/${users['buyer2']['id']}/suspend', body: {'reason': 'Test suspension'});
    await api.post('/api/v1/admin/users/${users['buyer2']['id']}/activate');

    // Official prices: add, edit, CSV import, history, delete.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final price = await api.post('/api/v1/admin/prices', body: {'grain': 'WHEAT', 'market': 'Okara', 'province': 'Punjab', 'min_price': 9800, 'max_price': 10200, 'avg_price': null, 'unit': 'QUINTAL', 'price_date': today, 'source': 'AMIS_PUNJAB', 'source_url': null, 'notes': null}) as Map<String, dynamic>;
    expect(price['price_per_maund'], 4000);
    await api.put('/api/v1/admin/prices/${price['id']}', body: {'grain': 'WHEAT', 'market': 'Okara', 'province': 'Punjab', 'avg_price': 10100, 'unit': 'QUINTAL', 'price_date': today, 'source': 'AMIS_PUNJAB'});
    final csv = utf8.encode('grain,market,min_price,max_price,unit,price_date,source\nRICE,Gujranwala,3000,3400,MAUND,$today,AMIS_PUNJAB\n');
    final imported = await api.upload('/api/v1/admin/prices/import-csv', bytes: csv, filename: 'prices.csv') as Map<String, dynamic>;
    expect(imported['created'], 1);
    final prices = await api.get('/api/v1/prices', query: {'grain': null, 'market': '', 'page': 1, 'page_size': 50}) as Map<String, dynamic>;
    expect(prices['total'], 2);
    final history = await api.get('/api/v1/prices/history', query: {'grain': 'WHEAT', 'market': 'okara', 'days': 180}) as Map<String, dynamic>;
    expect((history['points'] as List).single['price_per_maund'], 4040);

    // Marketplace moderation: farmer lists, buyer bids, admin inspects and removes.
    final closes = DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String();
    final listing = await farmer.post('/api/v1/listings', body: {'grain': 'WHEAT', 'quantity': 100, 'expected_price': 4000, 'city': 'Okara', 'bidding_closes_at': closes}) as Map<String, dynamic>;
    await buyer.post('/api/v1/listings/${listing['id']}/bids', body: {'price': 4100, 'quantity': 50});
    final listings = await api.get('/api/v1/admin/listings', query: {'status': 'OPEN', 'grain': 'WHEAT', 'farmer_id': farmerId, 'page': 1, 'page_size': 25}) as Map<String, dynamic>;
    expect(listings['total'], 1);
    final ld = await api.get('/api/v1/admin/listings/${listing['id']}') as Map<String, dynamic>;
    expect(ld['listing']['benchmark']['market'], 'Okara');
    expect((ld['bids'] as List).single['buyer']['business_name'], isNotNull);
    expect((ld['history'] as List).map((e) => e['action']), contains('BID_PLACED'));
    final bids = await api.get('/api/v1/admin/bids', query: {'status': 'ACTIVE', 'buyer_id': buyerId, 'page': 1, 'page_size': 25}) as Map<String, dynamic>;
    expect(bids['total'], 1);
    await api.post('/api/v1/admin/listings/${listing['id']}/cancel', body: {'reason': 'Duplicate listing'});
    final after = await api.get('/api/v1/admin/bids', query: {'buyer_id': buyerId}) as Map<String, dynamic>;
    expect((after['items'] as List).single['status'], 'REJECTED');

    // Audit log shows the actions above.
    final audit = (await api.get('/api/v1/admin/audit-logs', query: {'page': 1, 'page_size': 50}) as List).map((r) => r['action']).toSet();
    expect(audit, containsAll(['DOCUMENT_VIEWED', 'DOCUMENT_APPROVED', 'VERIFICATION_APPROVED', 'PROFILE_UPDATED', 'PHOTO_REMOVED', 'USER_SUSPENDED', 'USER_ACTIVATED', 'PRICE_ADDED', 'PRICES_IMPORTED', 'LISTING_REMOVED']));

    // An expired access token is refreshed automatically and the request retried.
    await api.store.write('access_token', 'expired-or-garbage');
    final again = await api.get('/api/v1/admin/dashboard/stats') as Map<String, dynamic>;
    expect(again['total_identity_verified'], 2);
    expect(await api.store.read('access_token'), isNot('expired-or-garbage'));

    // A bad refresh token signs the admin out instead of looping.
    var expired = false;
    api.onSessionExpired = () => expired = true;
    await api.store.write('access_token', 'garbage');
    await api.store.write('refresh_token', 'garbage');
    await expectLater(api.get('/api/v1/admin/dashboard/stats'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(expired, isTrue);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
