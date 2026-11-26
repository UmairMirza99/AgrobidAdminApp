import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

const _trendDays = 30;

class _DashboardData {
  const _DashboardData(this.users, this.market, this.signups, this.prices);

  final Map<String, dynamic> users;
  final Map<String, dynamic> market;

  /// Users created in the last [_trendDays] days, or null if they couldn't be loaded.
  final List<Map<String, dynamic>>? signups;

  /// Latest official price per grain and market, or null if they couldn't be loaded.
  final List<Map<String, dynamic>>? prices;
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.api});

  final ApiClient api;

  /// Pages through the newest users until it passes the start of the trend window (at most 5 pages of 100).
  Future<List<Map<String, dynamic>>?> _recentSignups() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: _trendDays));
      final result = <Map<String, dynamic>>[];
      for (var page = 1; page <= 5; page++) {
        final data = await api.get('/api/v1/admin/users', query: {'page': page, 'page_size': 100}) as Map<String, dynamic>;
        final items = (data['items'] as List).cast<Map<String, dynamic>>();
        var reachedOlder = false;
        for (final u in items) {
          final created = DateTime.tryParse(u['created_at']?.toString() ?? '');
          if (created == null) continue;
          if (created.isBefore(since)) {
            reachedOlder = true;
          } else {
            result.add(u);
          }
        }
        if (reachedOlder || items.length < 100) break;
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> _latestPrices() async {
    try {
      final data = await api.get('/api/v1/prices/latest') as Map<String, dynamic>;
      return (data['items'] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait<dynamic>([
      api.get('/api/v1/admin/dashboard/stats'),
      api.get('/api/v1/admin/market/stats'),
      _recentSignups(),
      _latestPrices(),
    ]);
    return _DashboardData(
      results[0] as Map<String, dynamic>,
      results[1] as Map<String, dynamic>,
      results[2] as List<Map<String, dynamic>>?,
      results[3] as List<Map<String, dynamic>>?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<_DashboardData>(
      load: _load,
      builder: (context, data, reload) {
        final users = data.users;
        final market = data.market;
        final listings = (market['listings'] as Map).cast<String, dynamic>();
        final bids = (market['bids'] as Map).cast<String, dynamic>();
        final pendingReviews = (users['pending_verification_reviews'] ?? 0) as num;
        final totalUsers = (users['total_users'] ?? 0) as num;
        final verified = (users['total_identity_verified'] ?? 0) as num;
        final tons = ((market['accepted_quantity_kg'] ?? 0) as num) / 1000;

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader('Dashboard', subtitle: 'Overview of users, verification and the grain marketplace', actions: [
            OutlinedButton.icon(onPressed: reload, icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh')),
          ]),
          if (pendingReviews > 0) _ReviewBanner(count: pendingReviews.toInt()),
          _Grid(minChildWidth: 160, children: [
            KpiCard(
              label: 'Total users',
              value: fmtNum(totalUsers),
              icon: Icons.people_alt_outlined,
              caption: '${fmtNum(users['total_farmers'])} farmers · ${fmtNum(users['total_buyers'])} buyers',
              onTap: () => context.go('/users'),
            ),
            KpiCard(
              label: 'Identity verified',
              value: fmtNum(verified),
              icon: Icons.verified_user_outlined,
              color: AppColors.info,
              caption: totalUsers == 0 ? 'No users yet' : '${(verified / totalUsers * 100).round()}% of users · ${fmtNum(pendingReviews)} waiting',
              onTap: () => context.go('/verifications'),
            ),
            KpiCard(
              label: 'Open listings',
              value: fmtNum(listings['OPEN'] ?? 0),
              icon: Icons.grass_outlined,
              color: AppColors.accent,
              caption: '${fmtNum(bids['ACTIVE'] ?? 0)} active bids',
              onTap: () => context.go('/listings?status=OPEN'),
            ),
            KpiCard(
              label: 'Grain traded',
              value: '${fmtNum(tons)} t',
              icon: Icons.scale_outlined,
              color: AppColors.chart[3],
              caption: 'from ${fmtNum(bids['ACCEPTED'] ?? 0)} accepted bids',
              onTap: () => context.go('/bids?status=ACCEPTED'),
            ),
          ]),
          const SizedBox(height: 20),
          _Grid(flex: const [2, 1], children: [
            ChartCard(
              title: 'New registrations',
              subtitle: 'Last $_trendDays days, by role',
              child: data.signups == null ? const ChartEmpty('Registration trend unavailable') : _signupTrend(data.signups!),
            ),
            ChartCard(
              title: 'Users by role',
              subtitle: 'Farmers and buyers on AgroBid',
              child: DonutChart(centerLabel: 'Users', data: [
                ChartDatum('Farmers', (users['total_farmers'] ?? 0) as num, AppColors.chart[0]),
                ChartDatum('Buyers', (users['total_buyers'] ?? 0) as num, AppColors.chart[1]),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _Grid(children: [
            ChartCard(
              title: 'Account status',
              subtitle: 'Where every account stands',
              child: HorizontalBars(data: [
                ChartDatum('Active', (users['total_active_users'] ?? 0) as num, AppColors.success),
                ChartDatum('Email not verified', (users['total_pending_users'] ?? 0) as num, AppColors.neutral),
                ChartDatum('Awaiting approval', (users['total_pending_approvals'] ?? 0) as num, AppColors.warning),
                ChartDatum('Suspended', (users['total_suspended_accounts'] ?? 0) as num, AppColors.chart[5]),
                ChartDatum('Rejected', (users['total_rejected_accounts'] ?? 0) as num, AppColors.danger),
              ]),
            ),
            ChartCard(
              title: 'Listings by status',
              subtitle: 'All grain listings',
              child: DonutChart(centerLabel: 'Listings', emptyMessage: 'No listings yet', data: [
                for (final s in listingStatuses) ChartDatum(humanize(s), (listings[s] ?? 0) as num, _listingColor(s)),
              ]),
            ),
            ChartCard(
              title: 'Bids by status',
              subtitle: 'All bids placed by buyers',
              child: VerticalBars(barWidth: 22, emptyMessage: 'No bids yet', data: [
                for (final s in bidStatuses) ChartDatum(humanize(s), (bids[s] ?? 0) as num, _bidColor(s)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          _Grid(flex: const [2, 3], children: [
            ChartCard(
              title: 'Official price benchmark',
              subtitle: 'Average latest price across markets, Rs/maund',
              trailing: TextButton(onPressed: () => context.go('/prices'), child: const Text('Manage')),
              height: 300,
              child: _priceChart(data.prices),
            ),
            _RecentRegistrations(users: (users['recent_registrations'] as List).cast<Map<String, dynamic>>()),
          ]),
        ]);
      },
    );
  }

  Widget _signupTrend(List<Map<String, dynamic>> signups) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = [for (var i = _trendDays - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final farmers = List<num>.filled(days.length, 0);
    final buyers = List<num>.filled(days.length, 0);
    for (final u in signups) {
      final created = DateTime.tryParse(u['created_at'].toString());
      if (created == null) continue;
      final index = days.length - 1 - today.difference(DateUtils.dateOnly(created.toLocal())).inDays;
      if (index < 0 || index >= days.length) continue;
      if (u['role'] == 'FARMER') farmers[index]++;
      if (u['role'] == 'BUYER') buyers[index]++;
    }
    final label = DateFormat('d MMM');
    return TrendChart(
      labelEvery: 7,
      xLabels: [for (final d in days) label.format(d)],
      series: [TrendSeries('Farmers', farmers, AppColors.chart[0]), TrendSeries('Buyers', buyers, AppColors.chart[1])],
    );
  }

  Widget _priceChart(List<Map<String, dynamic>>? prices) {
    if (prices == null) return const ChartEmpty('Prices unavailable');
    final byGrain = <String, List<num>>{};
    for (final p in prices) {
      final value = p['price_per_maund'];
      if (value is num) byGrain.putIfAbsent(p['grain'].toString(), () => []).add(value);
    }
    if (byGrain.isEmpty) return const ChartEmpty('No official prices yet.\nAdd them on the Official prices page.', icon: Icons.price_change_outlined);
    final data = [
      for (final (i, g) in grains.indexed)
        if (byGrain[g] != null) ChartDatum(humanize(g), byGrain[g]!.reduce((a, b) => a + b) / byGrain[g]!.length, AppColors.chart[i]),
    ];
    return VerticalBars(data: data, barWidth: 36, valueFormat: (v) => '${fmtPkr(v.round())} / maund');
  }
}

Color _listingColor(String status) => switch (status) {
      'OPEN' => AppColors.success,
      'DRAFT' => AppColors.neutral,
      'CLOSED' => AppColors.warning,
      'SOLD' => AppColors.info,
      _ => AppColors.danger,
    };

Color _bidColor(String status) => switch (status) {
      'ACTIVE' => AppColors.info,
      'ACCEPTED' => AppColors.success,
      'REJECTED' => AppColors.danger,
      'WITHDRAWN' => AppColors.neutral,
      _ => AppColors.warning,
    };

/// Lays children out in a row with the given flex weights, and wraps them when the row would be too narrow.
class _Grid extends StatelessWidget {
  const _Grid({required this.children, this.flex, this.minChildWidth = 320});

  final List<Widget> children;
  final List<int>? flex;
  final double minChildWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 20.0;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final perRow = ((width + gap) / (minChildWidth + gap)).floor().clamp(1, children.length);
      if (perRow == children.length) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(flex: flex?[i] ?? 1, child: children[i]),
            ],
          ]),
        );
      }
      final childWidth = (width - gap * (perRow - 1)) / perRow;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: childWidth, child: c)]);
    });
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final button = FilledButton(onPressed: () => context.go('/verifications'), child: const Text('Review now'));
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1D9A6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.pending_actions, color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$count identity ${count == 1 ? 'submission is' : 'submissions are'} waiting for review', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text("Unverified users can't list grain or bid.", style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          if (!narrow) ...[const SizedBox(width: 12), button],
        ]),
        if (narrow) ...[const SizedBox(height: 12), button],
      ]),
    );
  }
}

class _RecentRegistrations extends StatelessWidget {
  const _RecentRegistrations({required this.users});

  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          child: Row(children: [
            Expanded(child: Text('Recent registrations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => context.go('/users'), child: const Text('All users')),
          ]),
        ),
        const Divider(),
        if (users.isEmpty)
          const SizedBox(height: 200, child: ChartEmpty('No users yet', icon: Icons.person_outline))
        else
          for (final u in users.take(6))
            InkWell(
              onTap: () => context.go('/users/${u['id']}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
                child: Row(children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: (u['role'] == 'BUYER' ? AppColors.chart[1] : AppColors.chart[0]).withValues(alpha: 0.14),
                    child: Text(
                      _initial(u['full_name']),
                      style: TextStyle(fontWeight: FontWeight.w700, color: u['role'] == 'BUYER' ? AppColors.warning : AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: Text(u['full_name'] ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))),
                        const SizedBox(width: 4),
                        VerifiedBadge(u['identity_verified'] == true),
                      ]),
                      Text('${humanize(u['role'])} · ${u['email'] ?? ''}', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(u['account_status']),
                ]),
              ),
            ),
      ]),
    );
  }

  static String _initial(Object? name) {
    final text = (name ?? '').toString().trim();
    return text.isEmpty ? '?' : text[0].toUpperCase();
  }
}
