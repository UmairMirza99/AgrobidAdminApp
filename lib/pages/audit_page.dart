import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

/// Every admin action and every identity-document view, newest first.
class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  static const _pageSize = 50;
  int _page = 1;
  late Future<List<dynamic>> Function() _loader = _makeLoader();

  Future<List<dynamic>> Function() _makeLoader() {
    final page = _page;
    return () async => await widget.api.get('/api/v1/admin/audit-logs', query: {'page': page, 'page_size': _pageSize}) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Audit log', subtitle: 'Every administrator action, including each time an identity document is opened', actions: [
        OutlinedButton.icon(onPressed: () => setState(() => _loader = _makeLoader()), icon: const Icon(Icons.refresh), label: const Text('Refresh')),
      ]),
      AsyncPage<List<dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final rows = data.cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['Time', 'Action', 'Admin', 'Target user', 'Reason', 'Details'],
                empty: 'No admin actions recorded yet',
                rows: [
                  for (final r in rows)
                    DataRow(cells: [
                      DataCell(Text(fmtDateTime(r['created_at']))),
                      DataCell(Text(humanize(r['action']), style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('#${shortId(r['admin_id'])}')),
                      DataCell(r['target_user_id'] == null
                          ? const Text('-')
                          : TextButton(onPressed: () => context.go('/users/${r['target_user_id']}'), child: Text('#${shortId(r['target_user_id'])}'))),
                      DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 280), child: Text(r['reason'] ?? '', overflow: TextOverflow.ellipsis))),
                      DataCell(ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text((r['metadata'] as Map? ?? {}).entries.map((e) => '${humanize(e.key)}: ${e.value}').join(' · '), overflow: TextOverflow.ellipsis),
                      )),
                    ]),
                ],
              ),
              Pager(page: _page, pageSize: _pageSize, itemsOnPage: rows.length, onPage: (p) => setState(() {
                    _page = p;
                    _loader = _makeLoader();
                  })),
            ]),
          );
        },
      ),
    ]);
  }
}
