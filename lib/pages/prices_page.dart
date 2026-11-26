import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../widgets/common.dart';

class PricesPage extends StatefulWidget {
  const PricesPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends State<PricesPage> {
  static const _pageSize = 50;
  String? _grain;
  String _market = '';
  int _page = 1;
  late Future<Map<String, dynamic>> Function() _loader = _makeLoader();

  Future<Map<String, dynamic>> Function() _makeLoader() {
    final query = {'grain': _grain, 'market': _market, 'page': _page, 'page_size': _pageSize};
    return () async => await widget.api.get('/api/v1/prices', query: query) as Map<String, dynamic>;
  }

  void _apply(VoidCallback change, {bool resetPage = true}) => setState(() {
        change();
        if (resetPage) _page = 1;
        _loader = _makeLoader();
      });

  Future<void> _edit([Map<String, dynamic>? price]) async {
    final body = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _PriceDialog(price: price));
    if (body == null || !mounted) return;
    final ok = await runAction(
      context,
      () => price == null ? widget.api.post('/api/v1/admin/prices', body: body) : widget.api.put('/api/v1/admin/prices/${price['id']}', body: body),
      success: price == null ? 'Price saved' : 'Price updated',
    );
    if (ok) _apply(() {}, resetPage: false);
  }

  Future<void> _delete(Map<String, dynamic> price) async {
    final reason = await reasonDialog(context, 'Delete ${humanize(price['grain'])} price for ${price['market']} on ${fmtDate(price['price_date'])}', action: 'Delete');
    if (reason == null || !mounted) return;
    final ok = await runAction(context, () => widget.api.delete('/api/v1/admin/prices/${price['id']}', body: {'reason': reason}), success: 'Price deleted');
    if (ok) _apply(() {}, resetPage: false);
  }

  Future<void> _importCsv() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv'], dialogTitle: 'Choose a price CSV');
    if (files.isEmpty || !mounted) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Map<String, dynamic>? result;
    final ok = await runAction(context, () async {
      result = await widget.api.upload('/api/v1/admin/prices/import-csv', bytes: bytes, filename: file.name) as Map<String, dynamic>;
    });
    if (ok && mounted) {
      showMessage(context, 'Imported ${file.name}: ${result?['created']} new, ${result?['updated']} updated');
      _apply(() {});
    }
  }

  void _showCsvHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV format'),
        content: const SelectableText(
          'First row (header):\n'
          'grain,market,province,min_price,max_price,avg_price,unit,price_date,source,source_url,notes\n\n'
          'Example row:\n'
          'WHEAT,Lahore,Punjab,9800,10200,,QUINTAL,2026-11-25,AMIS_PUNJAB,https://www.amis.pk/,\n\n'
          'Required: grain, market, price_date, and avg_price or both min_price and max_price.\n'
          'unit defaults to QUINTAL (AMIS reports per 100 kg). Up to 2000 rows.\n'
          'If any row is invalid, nothing is imported and the first error is shown.\n'
          'Re-importing the same grain, market, date and source updates that price.',
          style: TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader('Official prices', subtitle: 'Benchmarks shown to farmers next to every bid', actions: [
        TextButton.icon(onPressed: _showCsvHelp, icon: const Icon(Icons.help_outline), label: const Text('CSV format')),
        OutlinedButton.icon(onPressed: _importCsv, icon: const Icon(Icons.upload_file), label: const Text('Import CSV')),
        FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add price')),
      ]),
      SectionCard(
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          FilterDropdown(label: 'Grain', value: _grain, options: grains, onChanged: (v) => _apply(() => _grain = v)),
          SizedBox(
            width: 240,
            child: TextField(
              decoration: const InputDecoration(labelText: 'Market (press Enter)', prefixIcon: Icon(Icons.location_city)),
              onSubmitted: (v) => _apply(() => _market = v.trim()),
            ),
          ),
        ]),
      ),
      if (_grain != null && _market.isNotEmpty) _HistoryChart(api: widget.api, grain: _grain!, market: _market),
      AsyncPage<Map<String, dynamic>>(
        load: _loader,
        builder: (context, data, reload) {
          final items = (data['items'] as List).cast<Map<String, dynamic>>();
          return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScrollTable(
                columns: const ['Date', 'Grain', 'Market', 'Min', 'Max', 'Average', 'Unit', 'Per maund', 'Source', ''],
                empty: 'No prices yet. Add one or import a CSV.',
                rows: [
                  for (final p in items)
                    DataRow(cells: [
                      DataCell(Text(fmtDate(p['price_date']))),
                      DataCell(Text(humanize(p['grain']))),
                      DataCell(Text('${p['market']}, ${p['province']}')),
                      DataCell(Text(fmtNum(p['min_price']))),
                      DataCell(Text(fmtNum(p['max_price']))),
                      DataCell(Text(fmtNum(p['avg_price']), style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(humanize(p['unit']))),
                      DataCell(Text(fmtPkr(p['price_per_maund']))),
                      DataCell(Text(p['source'] ?? '')),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(p)),
                        IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline, color: Colors.red.shade700), onPressed: () => _delete(p)),
                      ])),
                    ]),
                ],
              ),
              Pager(page: _page, pageSize: _pageSize, total: data['total'] as int?, onPage: (p) => _apply(() => _page = p, resetPage: false)),
              if (data['disclaimer'] != null) Text(data['disclaimer'], style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          );
        },
      ),
    ]);
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.api, required this.grain, required this.market});

  final ApiClient api;
  final String grain;
  final String market;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '${humanize(grain)} in ${market[0].toUpperCase()}${market.substring(1)}: price per maund, last 180 days',
      child: AsyncPage<Map<String, dynamic>>(
        key: ValueKey('$grain|$market'),
        load: () async => await api.get('/api/v1/prices/history', query: {'grain': grain, 'market': market, 'days': 180}) as Map<String, dynamic>,
        builder: (context, data, reload) {
          final points = (data['points'] as List).cast<Map<String, dynamic>>();
          if (points.length < 2) return const Padding(padding: EdgeInsets.all(16), child: Text('At least two dated prices are needed to draw a chart.'));
          final color = Theme.of(context).colorScheme.primary;
          final label = DateFormat('d MMM');
          final step = (points.length / 6).ceil();
          return SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 8),
              child: LineChart(LineChartData(
                gridData: const FlGridData(drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 56, getTitlesWidget: (v, meta) => Text(fmtNum(v.round()), style: const TextStyle(fontSize: 11)))),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i != v || i % step != 0 || i >= points.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label.format(DateTime.parse(points[i]['price_date'])), style: const TextStyle(fontSize: 11)));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), (points[i]['price_per_maund'] as num).toDouble())],
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(show: points.length <= 40),
                    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
                  ),
                ],
              )),
            ),
          );
        },
      ),
    );
  }
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({this.price});

  final Map<String, dynamic>? price;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _form = GlobalKey<FormState>();
  late final p = widget.price ?? const {};
  late String _grain = (p['grain'] ?? 'WHEAT') as String;
  late String _unit = (p['unit'] ?? 'QUINTAL') as String;
  late DateTime _date = p['price_date'] != null ? DateTime.parse(p['price_date']) : DateTime.now();
  late final _market = TextEditingController(text: p['market']);
  late final _province = TextEditingController(text: p['province'] ?? 'Punjab');
  late final _min = TextEditingController(text: p['min_price']?.toString());
  late final _max = TextEditingController(text: p['max_price']?.toString());
  late final _avg = TextEditingController(text: p['avg_price']?.toString());
  late final _source = TextEditingController(text: p['source'] ?? 'AMIS_PUNJAB');
  late final _url = TextEditingController(text: p['source_url']);
  final _notes = TextEditingController();

  num? _num(TextEditingController c) => c.text.trim().isEmpty ? null : num.tryParse(c.text.trim());

  String? _price(String? v) {
    if ((v ?? '').trim().isEmpty) return null;
    final n = num.tryParse(v!.trim());
    return n == null || n <= 0 ? 'Enter a price above 0' : null;
  }

  Widget _field(TextEditingController c, String label, {String? Function(String?)? validator, double width = 230}) => SizedBox(
        width: width,
        child: TextFormField(controller: c, validator: validator, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.price == null ? 'Add official price' : 'Edit official price'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _grain,
                  decoration: const InputDecoration(labelText: 'Grain'),
                  items: [for (final g in grains) DropdownMenuItem(value: g, child: Text(humanize(g)))],
                  onChanged: (v) => setState(() => _grain = v!),
                ),
              ),
              SizedBox(
                width: 230,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2015), lastDate: DateTime.now());
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Price date', isDense: true, suffixIcon: Icon(Icons.calendar_today, size: 18)),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
              ),
              _field(_market, 'Market (city or mandi)', validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Required' : null),
              _field(_province, 'Province', validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Required' : null),
              _field(_min, 'Min price', validator: _price, width: 150),
              _field(_max, 'Max price', validator: _price, width: 150),
              _field(_avg, 'Average (optional)', validator: _price, width: 150),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Prices are per'),
                  items: [for (final u in units) DropdownMenuItem(value: u, child: Text(humanize(u)))],
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
              _field(_source, 'Source code', validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Required' : null),
              _field(_url, 'Source URL (optional)', width: 472),
              _field(_notes, 'Notes (optional)', width: 472),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final min = _num(_min), max = _num(_max), avg = _num(_avg);
            if (avg == null && (min == null || max == null)) {
              showMessage(context, 'Enter the average, or both the min and max price', error: true);
              return;
            }
            if (min != null && max != null && min > max) {
              showMessage(context, 'Min price cannot be above max price', error: true);
              return;
            }
            Navigator.pop(context, {
              'grain': _grain,
              'market': _market.text.trim(),
              'province': _province.text.trim(),
              'min_price': min,
              'max_price': max,
              'avg_price': avg,
              'unit': _unit,
              'price_date': DateFormat('yyyy-MM-dd').format(_date),
              'source': _source.text.trim(),
              'source_url': _url.text.trim().isEmpty ? null : _url.text.trim(),
              'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
