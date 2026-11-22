import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(context, null, const [], const {}),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Layanan'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: dataVersion,
        builder: (context, _, __) => FutureBuilder<List<Object>>(
          future: Future.wait<Object>([
            AppDb.instance.getPackages(),
            AppDb.instance.getItemTypes(),
            AppDb.instance.getPrices(),
          ]),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pkgs = snap.data![0] as List<LaundryPackage>;
            final items = snap.data![1] as List<ItemType>;
            final prices = snap.data![2] as Map<int, Map<int, double>>;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Title('Waktu Pengerjaan'),
                Row(children: [
                  for (var i = 0; i < pkgs.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i < pkgs.length - 1 ? 8 : 0),
                        child: _PackageCard(pkgs[i]),
                      ),
                    ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'Ketuk kartu waktu pengerjaan untuk mengubah estimasi jam atau mengaktifkan/menonaktifkan. '
                  'Perubahan tarif & estimasi tidak mengubah transaksi lama.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                const _Title('Jenis Layanan & Daftar Tarif (per kg)'),
                for (final it in items) ...[
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          _editItem(context, it, pkgs, prices[it.id] ?? {}),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: it.active
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.14)
                                        : Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(it.code,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: it.active
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(it.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: it.active
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant)),
                                      if (it.description.isNotEmpty)
                                        Text(it.description,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: it.active,
                                  onChanged: (v) =>
                                      AppDb.instance.setItemTypeActive(it.id, v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (final p in pkgs)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: p.active ? 0.6 : 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${p.name} (${fmtEstimate(p.estimateHours)}): '
                                      '${fmtRp(prices[it.id]?[p.id] ?? 0)}/${it.unit}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: p.active
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 70),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editItem(BuildContext context, ItemType? it,
      List<LaundryPackage> pkgs, Map<int, double> prices) async {
    final allPkgs = pkgs.isEmpty ? await AppDb.instance.getPackages() : pkgs;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ItemDialog(item: it, packages: allPkgs, prices: prices),
    );
  }
}

class _Title extends StatelessWidget {
  final String t;
  const _Title(this.t);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)),
      );
}

class _PackageCard extends StatelessWidget {
  final LaundryPackage p;
  const _PackageCard(this.p);

  Future<void> _edit(BuildContext context) async {
    final res = await showDialog<({int? hours, bool active})>(
      context: context,
      builder: (_) => _EditPackageDialog(package: p),
    );
    if (res != null) {
      await AppDb.instance.updatePackage(
        p.id,
        estimateHours: res.hours,
        active: res.active,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _edit(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(p.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: p.active
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 4),
            Text(fmtEstimate(p.estimateHours),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: p.active
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(p.active ? 'Aktif' : 'Nonaktif',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.active
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828))),
          ]),
        ),
      ),
    );
  }
}

class _EditPackageDialog extends StatefulWidget {
  final LaundryPackage package;
  const _EditPackageDialog({required this.package});

  @override
  State<_EditPackageDialog> createState() => _EditPackageDialogState();
}

class _EditPackageDialogState extends State<_EditPackageDialog> {
  late final TextEditingController _ctrl;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.package.estimateHours.toString());
    _active = widget.package.active;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Waktu: ${widget.package.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Estimasi pengerjaan',
              suffixText: 'jam',
              helperText: '72 jam = 3 hari, 24 jam = 1 hari, 3 jam = Express',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aktifkan pilihan ini'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            final h = int.tryParse(_ctrl.text);
            Navigator.pop(
              context,
              (hours: (h != null && h > 0) ? h : null, active: _active),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _ItemDialog extends StatefulWidget {
  final ItemType? item;
  final List<LaundryPackage> packages;
  final Map<int, double> prices;
  const _ItemDialog(
      {required this.item, required this.packages, required this.prices});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _desc;
  late final Map<int, TextEditingController> _price;
  late bool _kiloan;
  late bool _active;
  String? _error;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _code = TextEditingController(text: it?.code ?? '');
    _desc = TextEditingController(text: it?.description ?? '');
    _kiloan = it?.isKiloan ?? true;
    _active = it?.active ?? true;
    _price = {
      for (final p in widget.packages)
        p.id: TextEditingController(
            text:
                widget.prices[p.id] == null ? '' : fmtQty(widget.prices[p.id]!)),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _desc.dispose();
    for (final c in _price.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final code = _code.text.trim().toUpperCase();
    if (name.isEmpty) {
      setState(() => _error = 'Nama layanan wajib diisi');
      return;
    }
    if (_isNew && !RegExp(r'^[A-Z0-9]{2,4}$').hasMatch(code)) {
      setState(() => _error = 'Kode 2-4 huruf/angka (dipakai di kode pesanan)');
      return;
    }
    final prices = <int, double>{};
    for (final e in _price.entries) {
      final v = parseNum(e.value.text);
      if (v <= 0) {
        setState(() => _error = 'Semua tarif waktu pengerjaan harus > 0');
        return;
      }
      prices[e.key] = v;
    }
    final nav = Navigator.of(context);
    try {
      await AppDb.instance.saveItemType(
        id: widget.item?.id,
        code: code,
        name: name,
        isKiloan: _kiloan,
        description: _desc.text.trim(),
        active: _active,
        prices: prices,
      );
      nav.pop();
    } catch (_) {
      setState(() => _error = 'Kode "$code" sudah dipakai layanan lain');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus jenis layanan?'),
        content: const Text(
            'Pesanan lama tidak berubah karena tarif dan nama layanan sudah tersimpan di transaksi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.instance.deleteItemType(widget.item!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Tambah Jenis Layanan' : 'Atur ${widget.item!.name}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama layanan'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              enabled: _isNew,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              decoration: const InputDecoration(
                  labelText: 'Kode (untuk kode pesanan)', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Deskripsi singkat'),
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Layanan aktif'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            for (final p in widget.packages) ...[
              TextField(
                controller: _price[p.id],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      'Tarif ${p.name} (${fmtEstimate(p.estimateHours)})',
                  prefixText: 'Rp ',
                  suffixText: _kiloan ? '/kg' : '/pcs',
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ]),
        ),
      ),
      actions: [
        if (!_isNew)
          TextButton(
              onPressed: _delete,
              child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
