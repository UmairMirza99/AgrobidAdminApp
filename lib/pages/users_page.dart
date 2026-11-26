import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.api, this.initialStatus, this.initialRole});

  final ApiClient api;
  final String? initialStatus;
  final String? initialRole;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 25;
  late String? _status = widget.initialStatus;
  late String? _role = widget.initialRole;
  String? _verified;
  String _search = '';
  int _page = 1;
  Timer? _debounce;
  late Future<Map<String, dynamic>> Function() _loader = _makeLoader();

  Future<Map<String, dynamic>> Function() _makeLoader() {
    final query = {'search': _search, 'role': _role, 'status': _status, 'identity_verified': _verified, 'page': _page, 'page_size': _pageSize};
    return () async => await widget.api.get('/api/v1/admin/users', query: query) as Map<String, dynamic>;
  }

  void _apply(VoidCallback change, {bool resetPage = true}) {
    setState(() {
      change();
      if (resetPage) _page = 1;
      _loader = _makeLoader();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader('Users', subtitle: 'Farmers and buyers: search, filter and open a profile to take action'),
      SectionCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search name, email or phone', prefixIcon: Icon(Icons.search)),
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _apply(() => _search = value.trim()));
              },
            ),
          ),
          FilterDropdown(label: 'Role', value: _role, options: const ['FARMER', 'BUYER'], onChanged: (v) => _apply(() => _role = v)),
          FilterDropdown(label: 'Account status', value: _status, options: accountStatuses, onChanged: (v) => _apply(() => _status = v)),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              initialValue: _verified,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Identity'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'true', child: Text('Verified')),
                DropdownMenuItem(value: 'false', child: Text('Not verified')),
              ],
              onChanged: (v) => _apply(() => _verified = v),
            ),
          ),
        ]),
      ),
      AsyncPage<Map<String, dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['Name', 'Role', 'Email', 'Phone', 'District', 'Status', 'Verified', 'Joined'],
                empty: 'No users match these filters',
                rows: [
                  for (final u in items)
                    DataRow(onSelectChanged: (_) => context.go('/users/${u['id']}'), cells: [
                      DataCell(Text(u['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(humanize(u['role']))),
                      DataCell(Text(u['email'] ?? '')),
                      DataCell(Text(u['phone_number'] ?? '')),
                      DataCell(Text(((u['farmer_profile'] ?? u['buyer_profile']) as Map?)?['district']?.toString() ?? '-')),
                      DataCell(StatusChip(u['account_status'])),
                      DataCell(VerifiedBadge(u['identity_verified'] == true)),
                      DataCell(Text(fmtDate(u['created_at']))),
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
