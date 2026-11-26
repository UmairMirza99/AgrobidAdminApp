import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class BidsPage extends StatefulWidget {
  const BidsPage({super.key, required this.api, this.initialStatus, this.buyerId});

  final ApiClient api;
  final String? initialStatus;
  final String? buyerId;

  @override
  State<BidsPage> createState() => _BidsPageState();
}

class _BidsPageState extends State<BidsPage> {
  static const _pageSize = 25;
  late String? _status = widget.initialStatus;
  int _page = 1;
  late Future<Map<String, dynamic>> Function() _loader = _makeLoader();

  Future<Map<String, dynamic>> Function() _makeLoader() {
    final query = {'status': _status, 'buyer_id': widget.buyerId, 'page': _page, 'page_size': _pageSize};
    return () async => await widget.api.get('/api/v1/admin/bids', query: query) as Map<String, dynamic>;
  }

  void _apply(VoidCallback change, {bool resetPage = true}) => setState(() {
        change();
        if (resetPage) _page = 1;
        _loader = _makeLoader();
      });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Bids', subtitle: widget.buyerId == null ? 'Every bid placed by buyers' : 'Bids by one buyer', actions: [
        if (widget.buyerId != null) OutlinedButton(onPressed: () => context.go('/bids'), child: const Text('Show all buyers')),
      ]),
      SectionCard(child: Wrap(children: [FilterDropdown(label: 'Status', value: _status, options: bidStatuses, onChanged: (v) => _apply(() => _status = v))])),
      AsyncPage<Map<String, dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['Buyer', 'Listing', 'Price / maund', 'Quantity', 'Total', 'Revision', 'Status', 'Placed', 'Valid until'],
                empty: 'No bids match this filter',
                rows: [
                  for (final b in items)
                    DataRow(onSelectChanged: (_) => context.go('/listings/${b['listing_id']}'), cells: [
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(b['buyer']['business_name'] ?? b['buyer']['full_name'] ?? ''),
                        const SizedBox(width: 4),
                        VerifiedBadge(b['buyer']['identity_verified'] == true),
                      ])),
                      DataCell(Text('#${shortId(b['listing_id'])}')),
                      DataCell(Text(fmtPkr(b['price_per_maund']))),
                      DataCell(Text('${fmtNum(b['quantity_kg'])} kg')),
                      DataCell(Text(fmtPkr(b['total_value']))),
                      DataCell(Text('${b['revision']}')),
                      DataCell(StatusChip(b['status'])),
                      DataCell(Text(fmtDateTime(b['created_at']))),
                      DataCell(Text(fmtDateTime(b['valid_until']))),
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
