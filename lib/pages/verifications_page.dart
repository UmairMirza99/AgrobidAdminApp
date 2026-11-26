import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

/// Identity submissions. By default: submitted and still pending, oldest first.
class VerificationsPage extends StatefulWidget {
  const VerificationsPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<VerificationsPage> createState() => _VerificationsPageState();
}

class _VerificationsPageState extends State<VerificationsPage> {
  static const _pageSize = 25;
  String? _status = 'PENDING';
  bool _submittedOnly = true;
  int _page = 1;
  late Future<List<dynamic>> Function() _loader = _makeLoader();

  Future<List<dynamic>> Function() _makeLoader() {
    final query = {'status': _status, 'submitted': _submittedOnly ? 'true' : null, 'page': _page, 'page_size': _pageSize};
    return () async => await widget.api.get('/api/v1/admin/verifications', query: query) as List<dynamic>;
  }

  void _apply(VoidCallback change, {bool resetPage = true}) => setState(() {
        change();
        if (resetPage) _page = 1;
        _loader = _makeLoader();
      });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Verification queue', subtitle: 'Review identity documents. Approving a waiting buyer also activates the account.', actions: [
        OutlinedButton.icon(onPressed: () => _apply(() {}, resetPage: false), icon: const Icon(Icons.refresh), label: const Text('Refresh')),
      ]),
      SectionCard(
        child: Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilterDropdown(label: 'Status', value: _status, options: const ['PENDING', 'APPROVED', 'REJECTED'], onChanged: (v) => _apply(() => _status = v)),
          FilterChip(label: const Text('Submitted for review only'), selected: _submittedOnly, onSelected: (v) => _apply(() => _submittedOnly = v)),
        ]),
      ),
      AsyncPage<List<dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final rows = data.cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['User', 'Role', 'Submitted', 'Documents', 'Status', 'Reviewed', ''],
                empty: 'Nothing waiting for review',
                rows: [
                  for (final r in rows)
                    DataRow(onSelectChanged: (_) => context.go('/users/${r['user_id']}'), cells: [
                      DataCell(Text(r['user_name'] ?? shortId(r['user_id']), style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(humanize(r['user_role']))),
                      DataCell(Text(r['submitted'] == true ? fmtDateTime(r['submitted_at']) : 'Not submitted')),
                      DataCell(Text('${r['document_count']}')),
                      DataCell(StatusChip(r['status'])),
                      DataCell(Text(fmtDateTime(r['reviewed_at']))),
                      DataCell(FilledButton.tonal(onPressed: () => context.go('/users/${r['user_id']}'), child: const Text('Review'))),
                    ]),
                ],
              ),
              Pager(page: _page, pageSize: _pageSize, itemsOnPage: rows.length, onPage: (p) => _apply(() => _page = p, resetPage: false)),
            ]),
          );
        },
      ),
    ]);
  }
}
