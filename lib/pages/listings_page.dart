import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key, required this.api, this.initialStatus, this.farmerId});

  final ApiClient api;
  final String? initialStatus;
  final String? farmerId;

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  static const _pageSize = 25;
  late String? _status = widget.initialStatus;
  String? _grain;
  int _page = 1;
  late Future<Map<String, dynamic>> Function() _loader = _makeLoader();

  Future<Map<String, dynamic>> Function() _makeLoader() {
    final query = {'status': _status, 'grain': _grain, 'farmer_id': widget.farmerId, 'page': _page, 'page_size': _pageSize};
    return () async => await widget.api.get('/api/v1/admin/listings', query: query) as Map<String, dynamic>;
  }

  void _apply(VoidCallback change, {bool resetPage = true}) => setState(() {
        change();
        if (resetPage) _page = 1;
        _loader = _makeLoader();
      });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Grain listings', subtitle: widget.farmerId == null ? 'Every listing on the marketplace' : 'Listings by one farmer', actions: [
        if (widget.farmerId != null) OutlinedButton(onPressed: () => context.go('/listings'), child: const Text('Show all farmers')),
      ]),
      SectionCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          FilterDropdown(label: 'Status', value: _status, options: listingStatuses, onChanged: (v) => _apply(() => _status = v)),
          FilterDropdown(label: 'Grain', value: _grain, options: grains, onChanged: (v) => _apply(() => _grain = v)),
        ]),
      ),
      AsyncPage<Map<String, dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['Grain', 'Farmer', 'Left / total', 'Expected / maund', 'City', 'Bids', 'Highest / maund', 'Status', 'Closes'],
                empty: 'No listings match these filters',
                rows: [
                  for (final l in items)
                    DataRow(onSelectChanged: (_) => context.go('/listings/${l['id']}'), cells: [
                      DataCell(Text('${humanize(l['grain'])}${l['variety'] != null ? ' · ${l['variety']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [Text(l['farmer']['full_name'] ?? ''), const SizedBox(width: 4), VerifiedBadge(l['farmer']['identity_verified'] == true)])),
                      DataCell(Text('${fmtNum(l['remaining_quantity'])} / ${fmtNum(l['quantity'])} ${humanize(l['quantity_unit']).toLowerCase()}')),
                      DataCell(Text(fmtPkr(l['expected_price_per_maund']))),
                      DataCell(Text(l['city'] ?? '')),
                      DataCell(Text('${l['bid_stats']['active_bids']} active · ${l['bid_stats']['accepted_bids']} accepted')),
                      DataCell(Text(fmtPkr(l['bid_stats']['highest_bid_per_maund']))),
                      DataCell(StatusChip(l['status'])),
                      DataCell(Text(fmtDateTime(l['bidding_closes_at']))),
                    ]),
                ],
              ),
              Pager(page: _page, pageSize: _pageSize, total: data['total'] as int?, onPage: (p) => _apply(() => _page = p, resetPage: false)),
            ]),
          );
        },
      ),
    ]);
  }
}

class ListingDetailPage extends StatefulWidget {
  const ListingDetailPage({super.key, required this.api, required this.listingId});

  final ApiClient api;
  final String listingId;

  @override
  State<ListingDetailPage> createState() => _ListingDetailPageState();
}

class _ListingDetailPageState extends State<ListingDetailPage> {
  late Future<Map<String, dynamic>> Function() _loader = _makeLoader();

  Future<Map<String, dynamic>> Function() _makeLoader() => () async => await widget.api.get('/api/v1/admin/listings/${widget.listingId}') as Map<String, dynamic>;

  @override
  void didUpdateWidget(covariant ListingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listingId != widget.listingId) _loader = _makeLoader();
  }

  Future<void> _remove() async {
    final reason = await reasonDialog(context, 'Remove this listing', action: 'Remove', hint: 'Why is it being removed? (the farmer sees this)');
    if (reason == null || !mounted) return;
    final ok = await runAction(context, () => widget.api.post('/api/v1/admin/listings/${widget.listingId}/cancel', body: {'reason': reason}), success: 'Listing removed; active bids were rejected');
    if (ok) setState(() => _loader = _makeLoader());
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<Map<String, dynamic>>(
      load: _loader,
      builder: (context, data, reload) {
        final l = (data['listing'] as Map).cast<String, dynamic>();
        final bids = (data['bids'] as List).cast<Map<String, dynamic>>();
        final history = (data['history'] as List).cast<Map<String, dynamic>>();
        final benchmark = l['benchmark'] as Map?;
        final removable = l['status'] != 'SOLD' && l['status'] != 'CANCELLED';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go('/listings'), icon: const Icon(Icons.arrow_back), label: const Text('All listings'))),
          PageHeader('${humanize(l['grain'])}${l['variety'] != null ? ' · ${l['variety']}' : ''}', subtitle: '${l['city']}, ${l['district']}', actions: [
            StatusChip(l['status']),
            if (removable) FilledButton.tonalIcon(onPressed: _remove, icon: const Icon(Icons.delete_outline), label: const Text('Remove listing')),
          ]),
          SectionCard(
            title: 'Details',
            child: InfoGrid({
              'Farmer': TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => context.go('/users/${l['farmer']['id']}'),
                child: Text(l['farmer']['full_name'] ?? ''),
              ),
              'Quantity': '${fmtNum(l['quantity'])} ${humanize(l['quantity_unit']).toLowerCase()} (${fmtNum(l['quantity_kg'])} kg)',
              'Remaining': '${fmtNum(l['remaining_quantity'])} ${humanize(l['quantity_unit']).toLowerCase()}',
              'Minimum order': l['min_order_kg'] == null ? '-' : '${fmtNum(l['min_order_kg'])} kg',
              'Expected price': l['expected_price'] == null ? '-' : '${fmtPkr(l['expected_price'])} / ${humanize(l['price_unit']).toLowerCase()}',
              'Expected / maund': fmtPkr(l['expected_price_per_maund']),
              'Quality grade': l['quality_grade'],
              'Moisture': l['moisture_percent'] == null ? '-' : '${l['moisture_percent']}%',
              'Delivery': humanize(l['delivery_option']),
              'Location': l['location_details'],
              'Bidding opened': fmtDateTime(l['bidding_opens_at']),
              'Bidding closes': fmtDateTime(l['bidding_closes_at']),
              'Created': fmtDateTime(l['created_at']),
              if (l['cancel_reason'] != null) 'Cancel reason': l['cancel_reason'],
              'Description': l['description'],
            }),
          ),
          SectionCard(
            title: 'Official price benchmark',
            child: benchmark == null
                ? const Text('No official price found for this grain in this city or district.')
                : InfoGrid({
                    'Market': '${benchmark['market']}, ${benchmark['province']}',
                    'Price / maund': fmtPkr(benchmark['price_per_maund']),
                    'Date': '${fmtDate(benchmark['price_date'])} (${benchmark['age_days']} days ago)',
                    'Source': benchmark['source'],
                    'Expected vs official': l['expected_vs_benchmark'] == null ? '-' : StatusChip((l['expected_vs_benchmark'] as Map)['position']),
                  }),
          ),
          SectionCard(
            title: 'Bids (${bids.length})',
            child: ScrollTable(
              columns: const ['Buyer', 'Price / maund', 'Quantity', 'Total', 'Delivery', 'Valid until', 'Status', 'Reason'],
              empty: 'No bids yet',
              rows: [
                for (final b in bids)
                  DataRow(cells: [
                    DataCell(TextButton(onPressed: () => context.go('/users/${b['buyer']['id']}'), child: Text(b['buyer']['business_name'] ?? b['buyer']['full_name'] ?? ''))),
                    DataCell(Text(fmtPkr(b['price_per_maund']))),
                    DataCell(Text('${fmtNum(b['quantity_kg'])} kg')),
                    DataCell(Text(fmtPkr(b['total_value']))),
                    DataCell(Text(humanize(b['delivery_option']))),
                    DataCell(Text(fmtDateTime(b['valid_until']))),
                    DataCell(StatusChip(b['status'])),
                    DataCell(Text(b['decision_reason'] ?? '')),
                  ]),
              ],
            ),
          ),
          SectionCard(
            title: 'History',
            child: Column(children: [
              for (final e in history.reversed)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text(humanize(e['action'])),
                  subtitle: (e['data'] as Map).isEmpty ? null : Text((e['data'] as Map).entries.map((x) => '${humanize(x.key)}: ${x.value}').join(' · ')),
                  trailing: Text(fmtDateTime(e['created_at'])),
                ),
            ]),
          ),
        ]);
      },
    );
  }
}
