import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Coloured pill for any status value from the API.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final Object? status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(humanize(status), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge(this.verified, {super.key});

  final bool verified;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: verified ? 'Identity verified' : 'Not verified',
        child: Icon(verified ? Icons.verified : Icons.verified_outlined, size: 18, color: verified ? AppColors.success : AppColors.border),
      );
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.text, behavior: SnackBarBehavior.floating, width: 480));
}

/// Runs an API action, shows success or the server's error message, and returns whether it worked.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (context.mounted && success != null) showMessage(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showMessage(context, e.toString(), error: true);
    return false;
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String message, {String action = 'Confirm'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for the reason the API requires on rejections, suspensions and removals (3 to 1000 characters).
Future<String?> reasonDialog(BuildContext context, String title, {String action = 'Submit', bool required = true, String hint = 'Reason (shown in the audit log)'}) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(labelText: hint),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (!required && text.isEmpty) return null;
              return text.length < 3 ? 'Enter at least 3 characters' : null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(context, controller.text.trim());
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Loads data once, shows a spinner or an error with Retry, and rebuilds on [reload].
class AsyncPage<T> extends StatefulWidget {
  const AsyncPage({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<AsyncPage<T>> createState() => _AsyncPageState<T>();
}

class _AsyncPageState<T> extends State<AsyncPage<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  void didUpdateWidget(covariant AsyncPage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _future = widget.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(strokeWidth: 3)));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, color: AppColors.danger, size: 40),
                const SizedBox(height: 12),
                Text(snapshot.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ]),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

/// Page header with a title, an optional subtitle and action buttons on the right.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            ],
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// A card with an optional title row, used for every section of a page.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(20)});

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 14, padding.right, 14),
            child: Row(children: [
              Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
              ?trailing,
            ]),
          ),
          const Divider(),
        ],
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

/// Label / value rows for detail pages.
class InfoGrid extends StatelessWidget {
  const InfoGrid(this.items, {super.key});

  final Map<String, Object?> items;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500);
    return Wrap(
      spacing: 32,
      runSpacing: 14,
      children: [
        for (final entry in items.entries)
          SizedBox(
            width: 220,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.key, style: labelStyle),
              const SizedBox(height: 4),
              entry.value is Widget ? entry.value as Widget : SelectableText(entry.value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
            ]),
          ),
      ],
    );
  }
}

/// A horizontally scrollable DataTable that keeps wide tables usable on small screens.
class ScrollTable extends StatelessWidget {
  const ScrollTable({super.key, required this.columns, required this.rows, this.empty = 'Nothing to show'});

  final List<String> columns;
  final List<DataRow> rows;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.border),
          const SizedBox(height: 8),
          Text(empty, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 0),
            child: DataTable(
              showCheckboxColumn: false,
              columns: [for (final c in columns) DataColumn(label: Text(c.toUpperCase()))],
              rows: rows,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Page 2 of 7 · 160 total" with previous / next buttons. Pass [total] = null when the API gives none.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pageSize, required this.onPage, this.total, this.itemsOnPage});

  final int page;
  final int pageSize;
  final int? total;
  final int? itemsOnPage;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final pages = total == null ? null : (total! / pageSize).ceil().clamp(1, 1 << 30);
    final hasNext = pages != null ? page < pages : (itemsOnPage ?? 0) >= pageSize;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(child: Text(pages != null ? 'Page $page of $pages · $total total' : 'Page $page', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        const SizedBox(width: 8),
        IconButton(onPressed: page > 1 ? () => onPage(page - 1) : null, icon: const Icon(Icons.chevron_left), tooltip: 'Previous'),
        IconButton(onPressed: hasNext ? () => onPage(page + 1) : null, icon: const Icon(Icons.chevron_right), tooltip: 'Next'),
      ]),
    );
  }
}

/// A compact dropdown filter whose first option clears the filter.
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({super.key, required this.label, required this.value, required this.options, required this.onChanged, this.allLabel = 'All'});

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
          for (final option in options) DropdownMenuItem<String?>(value: option, child: Text(humanize(option))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
