import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils.dart';
import '../data/database.dart';
import '../models/models.dart';
import 'order_detail_screen.dart';

class OrderFormScreen extends StatefulWidget {
  final LaundryOrder? order; // null = pesanan baru
  const OrderFormScreen({super.key, this.order});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _qty = TextEditingController();
  final _unit = TextEditingController();
  final _notes = TextEditingController();

  DateTime _date = DateTime.now();
  DateTime _estimatedDoneAt = DateTime.now().add(const Duration(hours: 72));
  bool _manualEstimate = false;

  List<ItemType> _items = [];
  List<LaundryPackage> _packages = [];
  Map<int, Map<int, double>> _prices = {};
  ItemType? _item;
  LaundryPackage? _pkg;

  String _payMethod = 'Tunai';
  int _payStatus = 0; // 0 = Belum Lunas, 1 = Lunas

  String _codePreview = '';
  bool _ready = false;
  bool _saving = false;

  bool get _editing => widget.order != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _qty, _unit, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDb.instance;
    final allItems = await db.getItemTypes();
    final allPkgs = await db.getPackages();
    final prices = await db.getPrices();
    final o = widget.order;

    // Untuk pesanan baru tampilkan yang aktif; untuk ubah pesanan sertakan juga pilihan lama jika sempat dinonaktifkan.
    final items = allItems
        .where((e) => e.active || (o != null && e.id == o.itemTypeId))
        .toList();
    final pkgs = allPkgs
        .where((e) => e.active || (o != null && e.id == o.packageId))
        .toList();

    ItemType? item;
    LaundryPackage? pkg;
    if (o != null) {
      _name.text = o.customerName;
      _phone.text = o.phone;
      _date = o.date;
      _qty.text = fmtQty(o.qty);
      _unit.text = fmtQty(o.unitPrice);
      _notes.text = o.notes;
      _payMethod = o.payMethod ?? 'Tunai';
      _payStatus = o.payStatus;
      item = items.where((e) => e.id == o.itemTypeId).firstOrNull;
      pkg = pkgs.where((e) => e.id == o.packageId).firstOrNull;
      if (o.estimatedDoneAt != null) {
        _estimatedDoneAt = o.estimatedDoneAt!;
        _manualEstimate = true;
      }
    }
    // Default layanan baru: Cuci + Gosok (jika tersedia), waktu: Reguler (atau pertama).
    item ??= items.where((e) => e.code == 'CGS').firstOrNull ??
        (items.isNotEmpty ? items.first : null);
    pkg ??= pkgs.where((e) => e.name == 'Reguler').firstOrNull ??
        (pkgs.isNotEmpty ? pkgs.first : null);

    _items = items;
    _packages = pkgs;
    _prices = prices;
    _item = item;
    _pkg = pkg;
    if (o == null) {
      _applyPrice();
      _recalcEstimate();
    } else if (o.estimatedDoneAt == null) {
      _recalcEstimate();
    }
    await _refreshCode();
    if (mounted) setState(() => _ready = true);
  }

  double _priceFor(ItemType i, LaundryPackage p) => _prices[i.id]?[p.id] ?? 0;

  void _applyPrice() {
    if (_item == null || _pkg == null) return;
    _unit.text = fmtQty(_priceFor(_item!, _pkg!));
  }

  void _recalcEstimate() {
    if (_pkg == null) return;
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final base = isToday
        ? now
        : DateTime(_date.year, _date.month, _date.day, now.hour, now.minute);
    _estimatedDoneAt = base.add(Duration(hours: _pkg!.estimateHours));
    _manualEstimate = false;
  }

  Future<void> _refreshCode() async {
    if (_editing) {
      _codePreview = widget.order!.code;
    } else if (_item != null) {
      _codePreview = await AppDb.instance.nextCode(_item!.code, _date);
    }
    if (mounted) setState(() {});
  }

  double get _qtyVal => parseNum(_qty.text);
  double get _unitVal => parseNum(_unit.text);
  double get _total => _qtyVal * _unitVal;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        _date = d;
        if (!_manualEstimate) _recalcEstimate();
      });
      _refreshCode();
    }
  }

  Future<void> _pickEstimateDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _estimatedDoneAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_estimatedDoneAt),
    );
    if (!mounted) return;
    final hour = t?.hour ?? _estimatedDoneAt.hour;
    final minute = t?.minute ?? _estimatedDoneAt.minute;
    setState(() {
      _estimatedDoneAt = DateTime(d.year, d.month, d.day, hour, minute);
      _manualEstimate = true;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_item == null || _pkg == null) return;
    setState(() => _saving = true);
    try {
      final old = widget.order;
      final item = _item!;
      final pkg = _pkg!;
      final keepItem = old != null && old.itemTypeId == item.id;
      final keepPkg = old != null && old.packageId == pkg.id;
      final qty = _qtyVal;
      final unit = _unitVal;
      final code = old?.code ?? await AppDb.instance.nextCode(item.code, _date);
      final paidAt = _payStatus == 1
          ? (old?.paidAt ?? DateTime.now())
          : null;

      final o = LaundryOrder(
        id: old?.id,
        code: code,
        customerName: _name.text.trim(),
        phone: _phone.text.trim(),
        date: DateTime(_date.year, _date.month, _date.day),
        itemTypeId: item.id,
        itemCode: keepItem ? old.itemCode : item.code,
        itemName: keepItem ? old.itemName : item.name,
        isKiloan: keepItem ? old.isKiloan : item.isKiloan,
        qty: qty,
        packageId: pkg.id,
        // Snapshot layanan, waktu pengerjaan, dan estimasi selesai di transaksi.
        packageName: keepPkg ? old.packageName : pkg.name,
        estimateHours: keepPkg ? old.estimateHours : pkg.estimateHours,
        estimatedDoneAt: _estimatedDoneAt,
        unitPrice: unit,
        total: qty * unit,
        notes: _notes.text.trim(),
        workStatus: old?.workStatus ?? 0,
        payStatus: _payStatus,
        payMethod: _payMethod,
        paidAt: paidAt,
      );

      if (old == null) {
        final id = await AppDb.instance.insertOrder(o);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: id)));
      } else {
        await AppDb.instance.updateOrder(o);
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Ubah Pesanan' : 'Pesanan Baru')),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty || _packages.isEmpty)
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Tidak ada layanan atau waktu pengerjaan yang aktif.\nAktifkan terlebih dahulu di menu Layanan.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Form(
                  key: _form,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _formChildren(),
                      ),
                    ),
                  ),
                ),
    );
  }

  List<Widget> _formChildren() {
    final cs = Theme.of(context).colorScheme;
    final tint = cs.primary.withValues(alpha: 0.12);
    final item = _item!;
    final kiloan = item.isKiloan;
    final unitSuffix = kiloan ? 'kg' : 'pcs';

    return [
      // Ringkasan Kode & Tanggal Transaksi
      Card(
        color: tint,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kode Pesanan',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    Text(_codePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
              ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(fmtDate(_date),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: cs.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 1. Nama pelanggan & 2. Nomor WhatsApp
      _section('1. Data Pelanggan'),
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nama pelanggan',
          prefixIcon: Icon(Icons.person_outline),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Nama pelanggan wajib diisi' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Nomor WhatsApp',
          hintText: '08123456789',
          prefixIcon: Icon(Icons.chat),
          helperText: 'Dipakai untuk pemberitahuan lewat WhatsApp',
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          return normalizePhone(v) == null ? 'Nomor WhatsApp tidak valid' : null;
        },
      ),

      // 3. Jenis layanan
      _section('2. Jenis Layanan'),
      for (final s in _items) ...[
        _serviceCard(s),
        const SizedBox(height: 8),
      ],

      // 4. Pilihan waktu pengerjaan
      _section('3. Waktu Pengerjaan'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _packages.length; i++)
            Expanded(
              child: Padding(
                padding:
                    EdgeInsets.only(right: i < _packages.length - 1 ? 8 : 0),
                child: _speedCard(_packages[i], item),
              ),
            ),
        ],
      ),

      // 5. Berat cucian (kg) & 6. Harga per kilogram
      _section('4. Berat & Tarif'),
      TextFormField(
        controller: _qty,
        onChanged: (_) => setState(() {}),
        keyboardType: TextInputType.numberWithOptions(decimal: kiloan),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              kiloan ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
        ],
        decoration: InputDecoration(
          labelText: kiloan ? 'Berat cucian (kg)' : 'Jumlah barang (pcs)',
          hintText: kiloan ? 'Contoh: 4 atau 2.5' : 'Contoh: 2',
          prefixIcon: const Icon(Icons.scale_outlined),
          suffixText: unitSuffix,
        ),
        validator: (v) =>
            parseNum(v ?? '') <= 0 ? 'Isi berat lebih dari 0' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _unit,
        onChanged: (_) => setState(() {}),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: kiloan ? 'Harga per kilogram' : 'Harga per pcs',
          prefixText: 'Rp ',
          suffixText: '/$unitSuffix',
          helperText:
              'Terisi otomatis dari kombinasi layanan & waktu pengerjaan; dapat disesuaikan',
        ),
        validator: (v) =>
            parseNum(v ?? '') <= 0 ? 'Harga harus lebih dari 0' : null,
      ),

      // 7. Estimasi selesai
      const SizedBox(height: 12),
      InkWell(
        onTap: _pickEstimateDateTime,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Estimasi selesai',
            prefixIcon: const Icon(Icons.schedule),
            suffixIcon: _manualEstimate
                ? IconButton(
                    tooltip: 'Hitung ulang otomatis',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(_recalcEstimate),
                  )
                : const Icon(Icons.edit_calendar_outlined),
            helperText: _manualEstimate
                ? 'Disesuaikan manual oleh admin (ketuk untuk ubah)'
                : 'Otomatis ${_pkg != null ? fmtEstimate(_pkg!.estimateHours) : ''} dari waktu transaksi (ketuk untuk sesuaikan)',
          ),
          child: Text(
            fmtDateTime(_estimatedDoneAt),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),

      // 8. Total biaya (rincian perhitungan otomatis)
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Biaya',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text(fmtRp(_total),
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: cs.primary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.name} • ${_pkg?.name ?? '-'} (${_pkg != null ? fmtEstimate(_pkg!.estimateHours) : '-'})',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Perhitungan: ${fmtQty(_qtyVal)} $unitSuffix × ${fmtRp(_unitVal)}/$unitSuffix = ${fmtRp(_total)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),

      // 9. Metode pembayaran & 10. Status pembayaran
      _section('5. Pembayaran'),
      const Text('Metode pembayaran',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      SegmentedButton<String>(
        segments: [
          for (final m in payMethods)
            ButtonSegment(
              value: m,
              label: Text(m),
              icon: Icon(
                  m == 'QRIS' ? Icons.qr_code_2 : Icons.payments_outlined),
            ),
        ],
        selected: {_payMethod},
        onSelectionChanged: (s) => setState(() => _payMethod = s.first),
      ),
      const SizedBox(height: 12),
      const Text('Status pembayaran',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Belum Lunas'),
            icon: Icon(Icons.pending_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Lunas'),
            icon: Icon(Icons.check_circle_outline),
          ),
        ],
        selected: {_payStatus},
        onSelectionChanged: (s) => setState(() => _payStatus = s.first),
      ),
      if (_payStatus == 1 && _payMethod == 'QRIS')
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Pastikan pembayaran QRIS sudah diterima sebelum menyimpan sebagai Lunas.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),

      // 11. Catatan tambahan
      _section('6. Catatan Tambahan'),
      TextFormField(
        controller: _notes,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Catatan tambahan (opsional)',
          hintText: 'Contoh: pisahkan pakaian putih, pewangi lembut',
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save),
        label: Text(_editing ? 'Simpan Perubahan' : 'Simpan Pesanan'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(t,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary)),
      );

  Widget _serviceCard(ItemType s) {
    final cs = Theme.of(context).colorScheme;
    final selected = _item?.id == s.id;
    final currentPrice = _pkg == null ? 0.0 : _priceFor(s, _pkg!);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _item = s;
          if (!s.isKiloan && _qty.text.isNotEmpty) {
            final q = parseNum(_qty.text);
            if (q != q.roundToDouble()) {
              _qty.text = q.round().toString();
            }
          }
          _applyPrice();
        });
        _refreshCode();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: selected ? cs.primary : cs.onSurface)),
                  if (s.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(s.description,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtRp(currentPrice),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: cs.primary)),
                Text('/${s.unit}',
                    style:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedCard(LaundryPackage p, ItemType item) {
    final cs = Theme.of(context).colorScheme;
    final selected = _pkg?.id == p.id;
    final price = _priceFor(item, p);
    final express = p.estimateHours <= 6;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _pkg = p;
        _applyPrice();
        _recalcEstimate();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(p.name,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selected ? cs.primary : cs.onSurface)),
          ),
          const SizedBox(height: 2),
          Text(fmtEstimate(p.estimateHours),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      express ? const Color(0xFFEF6C00) : cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${fmtRp(price)}/${item.unit}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }
}
