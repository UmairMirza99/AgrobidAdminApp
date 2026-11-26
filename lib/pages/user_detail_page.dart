import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';
import '../widgets/file_viewer.dart';

class UserDetailPage extends StatefulWidget {
  const UserDetailPage({super.key, required this.api, required this.userId});

  final ApiClient api;
  final String userId;

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late Future<(Map<String, dynamic>, List<dynamic>)> Function() _loader = _makeLoader();

  Future<(Map<String, dynamic>, List<dynamic>)> Function() _makeLoader() => () async {
        final results = await Future.wait([
          widget.api.get('/api/v1/admin/users/${widget.userId}'),
          widget.api.get('/api/v1/admin/users/${widget.userId}/documents'),
        ]);
        return (results[0] as Map<String, dynamic>, results[1] as List<dynamic>);
      };

  void _reload() => setState(() => _loader = _makeLoader());

  @override
  void didUpdateWidget(covariant UserDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _loader = _makeLoader();
  }

  ApiClient get api => widget.api;
  String get base => '/api/v1/admin';

  Future<void> _act(Future<void> Function() call, String success) async {
    if (await runAction(context, call, success: success)) _reload();
  }

  Future<void> _withReason(String title, String path, String success, {String action = 'Confirm', String? method}) async {
    final reason = await reasonDialog(context, title, action: action);
    if (reason == null) return;
    await _act(() async {
      if (method == 'DELETE') {
        await api.delete(path, body: {'reason': reason});
      } else {
        await api.post(path, body: {'reason': reason});
      }
    }, success);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<(Map<String, dynamic>, List<dynamic>)>(
      load: _loader,
      builder: (context, data, reload) {
        final (user, allDocs) = data;
        final role = user['role'] as String;
        final status = user['account_status'] as String;
        final profile = ((user['farmer_profile'] ?? user['buyer_profile']) as Map?)?.cast<String, dynamic>() ?? {};
        final verification = (user['verification'] as Map?)?.cast<String, dynamic>() ?? {};
        final completion = (user['completion'] as Map?)?.cast<String, dynamic>() ?? {};
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go('/users'), icon: const Icon(Icons.arrow_back), label: const Text('All users'))),
          _header(user, role, status),
          _accountActions(user, role, status),
          _verificationCard(user, verification),
          _profileCard(user, role, profile, completion),
          _historyCard(allDocs),
        ]);
      },
    );
  }

  Widget _header(Map<String, dynamic> user, String role, String status) {
    final id = user['id'];
    return SectionCard(
      child: Wrap(spacing: 24, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Column(children: [
          ProtectedAvatar(api: api, path: '$base/users/$id/photo', name: user['full_name'] ?? '', hasPhoto: user['has_photo'] == true, radius: 40),
          if (user['has_photo'] == true)
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(tooltip: 'View photo', icon: const Icon(Icons.zoom_in), onPressed: () => showProtectedFile(context, api, path: '$base/users/$id/photo', title: 'Profile photo', contentType: 'image/jpeg')),
              IconButton(
                tooltip: 'Remove photo',
                icon: Icon(Icons.hide_image_outlined, color: Colors.red.shade700),
                onPressed: () => _withReason('Remove profile photo', '$base/users/$id/photo', 'Photo removed', action: 'Remove', method: 'DELETE'),
              ),
            ]),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(user['full_name'] ?? '', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            VerifiedBadge(user['identity_verified'] == true),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [Chip(label: Text(humanize(role)), visualDensity: VisualDensity.compact), StatusChip(status)]),
          const SizedBox(height: 8),
          InfoGrid({
            'Email': user['email'],
            'Phone': user['phone_number'],
            'Email verified': user['email_verified'] == true ? 'Yes' : 'No',
            'Joined': fmtDateTime(user['created_at']),
            'Last login': fmtDateTime(user['last_login_at']),
            'User ID': user['id'],
          }),
        ]),
      ]),
    );
  }

  Widget _accountActions(Map<String, dynamic> user, String role, String status) {
    final id = user['id'];
    final emailVerified = user['email_verified'] == true;
    return SectionCard(
      title: 'Account actions',
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (status == 'PENDING_APPROVAL')
          FilledButton.icon(
            onPressed: emailVerified ? () => _act(() => api.post('$base/users/$id/approve'), 'Account approved') : null,
            icon: const Icon(Icons.check),
            label: const Text('Approve account'),
          ),
        if (status == 'SUSPENDED' || status == 'REJECTED')
          FilledButton.icon(
            onPressed: emailVerified ? () => _act(() => api.post('$base/users/$id/activate'), 'Account activated') : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Activate account'),
          ),
        if (status != 'SUSPENDED')
          OutlinedButton.icon(
            onPressed: () => _withReason('Suspend account', '$base/users/$id/suspend', 'Account suspended', action: 'Suspend'),
            icon: const Icon(Icons.block),
            label: const Text('Suspend'),
          ),
        if (status != 'REJECTED')
          OutlinedButton.icon(
            onPressed: () => _withReason('Reject account', '$base/users/$id/reject', 'Account rejected', action: 'Reject'),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
          ),
        if (role == 'FARMER') TextButton.icon(onPressed: () => context.go('/listings?farmer_id=$id'), icon: const Icon(Icons.grass), label: const Text('Their listings')),
        if (role == 'BUYER') TextButton.icon(onPressed: () => context.go('/bids?buyer_id=$id'), icon: const Icon(Icons.gavel), label: const Text('Their bids')),
        if (!emailVerified) const Padding(padding: EdgeInsets.all(8), child: Text('Email is not verified yet, so the account cannot be approved.')),
      ]),
    );
  }

  Widget _verificationCard(Map<String, dynamic> user, Map<String, dynamic> v) {
    final id = user['id'];
    final status = v['status'] as String? ?? 'NOT_SUBMITTED';
    final requirements = ((v['requirements'] as List?) ?? []).cast<Map<String, dynamic>>();
    final docs = ((v['documents'] as List?) ?? []).cast<Map<String, dynamic>>();
    return SectionCard(
      title: 'Identity verification',
      trailing: StatusChip(status),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InfoGrid({'Submitted': fmtDateTime(v['submitted_at']), 'Reviewed': fmtDateTime(v['reviewed_at']), if (v['rejection_reason'] != null) 'Rejection reason': v['rejection_reason']}),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in requirements)
            Chip(
              avatar: Icon(r['satisfied'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: r['satisfied'] == true ? Colors.green.shade700 : Colors.grey, size: 18),
              label: Text(r['label'] ?? r['key']),
            ),
        ]),
        const SizedBox(height: 12),
        ScrollTable(
          columns: const ['Document', 'File', 'Uploaded', 'Status', 'Note', 'Actions'],
          empty: 'No documents uploaded yet',
          rows: [for (final d in docs) _docRow(d)],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (status == 'UNDER_REVIEW') ...[
            FilledButton.icon(
              onPressed: () => _withReason('Approve verification', '$base/verifications/$id/approve', 'Identity verified', action: 'Approve'),
              icon: const Icon(Icons.verified),
              label: const Text('Approve verification'),
            ),
            OutlinedButton.icon(
              onPressed: () => _withReason('Reject verification', '$base/verifications/$id/reject', 'Verification rejected', action: 'Reject'),
              icon: const Icon(Icons.close),
              label: const Text('Reject verification'),
            ),
          ],
          if (status == 'VERIFIED')
            OutlinedButton.icon(
              onPressed: () => _withReason('Revoke verified badge', '$base/users/$id/verification/revoke', 'Verification revoked', action: 'Revoke'),
              icon: const Icon(Icons.remove_moderator_outlined),
              label: const Text('Revoke verification'),
            ),
          if (status == 'NOT_SUBMITTED' || status == 'REJECTED')
            const Padding(padding: EdgeInsets.all(8), child: Text('Waiting for the user to upload documents and submit them.')),
        ]),
      ]),
    );
  }

  DataRow _docRow(Map<String, dynamic> d) {
    final pending = d['status'] == 'PENDING';
    return DataRow(cells: [
      DataCell(Text(humanize(d['document_type']), style: const TextStyle(fontWeight: FontWeight.w500))),
      DataCell(Text('${d['file_name']} (${fmtNum((d['size_bytes'] as num) / 1024)} KB)')),
      DataCell(Text(fmtDateTime(d['uploaded_at']))),
      DataCell(StatusChip(d['status'])),
      DataCell(Text(d['review_reason'] ?? '')),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'View (recorded in the audit log)',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => showProtectedFile(context, api, path: '$base/documents/${d['id']}/file', title: humanize(d['document_type']), contentType: d['content_type'] ?? ''),
        ),
        if (pending) ...[
          IconButton(tooltip: 'Approve document', icon: Icon(Icons.check_circle_outline, color: Colors.green.shade700), onPressed: () => _act(() => api.post('$base/documents/${d['id']}/approve'), 'Document approved')),
          IconButton(
            tooltip: 'Reject document',
            icon: Icon(Icons.highlight_off, color: Colors.red.shade700),
            onPressed: () => _withReason('Reject ${humanize(d['document_type'])}', '$base/documents/${d['id']}/reject', 'Document rejected', action: 'Reject'),
          ),
        ],
      ])),
    ]);
  }

  Widget _profileCard(Map<String, dynamic> user, String role, Map<String, dynamic> profile, Map<String, dynamic> completion) {
    final farmer = role == 'FARMER';
    final missing = ((completion['missing'] as List?) ?? []).map(humanize).join(', ');
    return SectionCard(
      title: 'Profile',
      trailing: OutlinedButton.icon(onPressed: () => _editProfile(user, role, profile), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: LinearProgressIndicator(value: ((completion['percent'] ?? 0) as num) / 100, minHeight: 8, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Text('${completion['percent'] ?? 0}% complete'),
        ]),
        if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Missing: $missing', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
        const SizedBox(height: 16),
        InfoGrid(farmer
            ? {
                'District': profile['district'],
                'Village / tehsil': profile['village_tehsil'],
                'Land size': '${fmtNum(profile['land_size_acres'])} acres',
                'Address': profile['address'],
                'Main crops': ((profile['main_crops'] as List?) ?? []).map(humanize).join(', '),
              }
            : {
                'District': profile['district'],
                'Business name': profile['business_name'],
                'Buyer type': humanize(profile['buyer_type']),
                'Business address': profile['business_address'],
                'NTN': profile['ntn_number'],
                'Purchase capacity': profile['purchase_capacity_tons'] == null ? '-' : '${fmtNum(profile['purchase_capacity_tons'])} t',
                'Interested grains': ((profile['interested_grains'] as List?) ?? []).map(humanize).join(', '),
              }),
      ]),
    );
  }

  Widget _historyCard(List<dynamic> allDocs) {
    final docs = allDocs.cast<Map<String, dynamic>>();
    return SectionCard(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('All documents ever uploaded (${docs.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [ScrollTable(columns: const ['Document', 'File', 'Uploaded', 'Status', 'Note', 'Actions'], rows: [for (final d in docs) _docRow(d)])],
      ),
    );
  }

  Future<void> _editProfile(Map<String, dynamic> user, String role, Map<String, dynamic> profile) async {
    final changes = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditProfileDialog(user: user, role: role, profile: profile),
    );
    if (changes == null) return;
    await _act(() => api.put('$base/users/${user['id']}/profile', body: changes), 'Profile updated');
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.user, required this.role, required this.profile});

  final Map<String, dynamic> user;
  final String role;
  final Map<String, dynamic> profile;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final bool farmer = widget.role == 'FARMER';
  late final Map<String, TextEditingController> _text = {
    'full_name': TextEditingController(text: widget.user['full_name']),
    'district': TextEditingController(text: widget.profile['district']),
    if (farmer) ...{
      'village_tehsil': TextEditingController(text: widget.profile['village_tehsil']),
      'land_size_acres': TextEditingController(text: widget.profile['land_size_acres']?.toString()),
      'address': TextEditingController(text: widget.profile['address']),
    } else ...{
      'business_name': TextEditingController(text: widget.profile['business_name']),
      'business_address': TextEditingController(text: widget.profile['business_address']),
      'ntn_number': TextEditingController(text: widget.profile['ntn_number']),
      'purchase_capacity_tons': TextEditingController(text: widget.profile['purchase_capacity_tons']?.toString()),
    },
  };
  late String? _buyerType = widget.profile['buyer_type'] as String?;
  late final Set<String> _grains = {...((widget.profile[farmer ? 'main_crops' : 'interested_grains'] as List?) ?? []).cast<String>()};
  final _reason = TextEditingController();

  static const _required = {'full_name', 'district', 'village_tehsil', 'land_size_acres', 'business_name'};
  static const _numbers = {'land_size_acres', 'purchase_capacity_tons'};
  static const _labels = {
    'full_name': 'Full name',
    'district': 'District',
    'village_tehsil': 'Village / tehsil',
    'land_size_acres': 'Land size (acres)',
    'address': 'Address',
    'business_name': 'Business name',
    'business_address': 'Business address',
    'ntn_number': 'NTN number',
    'purchase_capacity_tons': 'Purchase capacity (tons)',
  };

  Map<String, dynamic> _changes() {
    final out = <String, dynamic>{};
    for (final entry in _text.entries) {
      final key = entry.key;
      final text = entry.value.text.trim();
      final original = key == 'full_name' ? widget.user[key] : widget.profile[key];
      final value = text.isEmpty ? null : (_numbers.contains(key) ? num.parse(text) : text);
      final same = _numbers.contains(key) ? (original == null ? value == null : value != null && (original as num) == value) : (original ?? '') == (value ?? '');
      if (!same) out[key] = value;
    }
    if (!farmer && _buyerType != widget.profile['buyer_type']) out['buyer_type'] = _buyerType;
    final listKey = farmer ? 'main_crops' : 'interested_grains';
    final before = {...((widget.profile[listKey] as List?) ?? []).cast<String>()};
    if (before.length != _grains.length || !before.containsAll(_grains)) out[listKey] = _grains.isEmpty ? null : grains.where(_grains.contains).toList();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${farmer ? 'farmer' : 'buyer'} profile'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final entry in _text.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: _labels[entry.key]),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (_required.contains(entry.key) && text.length < 2) return 'Required (at least 2 characters)';
                      if (_numbers.contains(entry.key) && text.isNotEmpty && ((num.tryParse(text) ?? 0) <= 0)) return 'Enter a number above 0';
                      if (entry.key == 'ntn_number' && text.isNotEmpty && !RegExp(r'^[A-Za-z0-9-]{5,20}$').hasMatch(text)) return '5 to 20 letters, digits or dashes';
                      return null;
                    },
                  ),
                ),
              if (!farmer)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _buyerType,
                    decoration: const InputDecoration(labelText: 'Buyer type'),
                    items: [for (final t in buyerTypes) DropdownMenuItem(value: t, child: Text(humanize(t)))],
                    onChanged: (v) => setState(() => _buyerType = v),
                  ),
                ),
              Align(alignment: Alignment.centerLeft, child: Text(farmer ? 'Main crops' : 'Interested grains')),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final g in grains)
                  FilterChip(label: Text(humanize(g)), selected: _grains.contains(g), onSelected: (on) => setState(() => on ? _grains.add(g) : _grains.remove(g))),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason for the change (audit log)'),
                validator: (v) => (v?.trim().length ?? 0) < 3 ? 'A reason of at least 3 characters is required' : null,
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final changes = _changes();
            if (changes.isEmpty) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context, {...changes, 'reason': _reason.text.trim()});
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
