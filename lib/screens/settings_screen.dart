import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_settings.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/database.dart';
import '../services/backup_service.dart';
import '../services/qris_service.dart';

/// Bottom sheet cepat dari tombol pojok kanan atas untuk ubah ukuran huruf,
/// warna tema, dan Mode Ramah Orang Tua secara instan.
Future<void> showQuickAppearanceSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _QuickAppearanceSheet(),
  );
}

class _QuickAppearanceSheet extends StatelessWidget {
  const _QuickAppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<AppearanceState>(
      valueListenable: AppAppearance.instance,
      builder: (context, s, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: cs.primary),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Atur Tampilan & Huruf',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                      child: const Text('Lengkap'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Card(
                  color: cs.primary.withValues(alpha: 0.08),
                  child: SwitchListTile(
                    title: const Text(
                      'Mode Ramah Orang Tua',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Huruf besar, teks tebal, kontras tinggi & tombol lega'),
                    value: s.isSeniorFriendly,
                    onChanged: (v) =>
                        AppAppearance.instance.toggleSeniorMode(v),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ukuran Huruf',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('${(s.fontScale * 100).round()}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: cs.primary)),
                  ],
                ),
                Slider(
                  value: s.fontScale,
                  min: 0.9,
                  max: 1.45,
                  divisions: 11,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) =>
                      AppAppearance.instance.update(s.copyWith(fontScale: v)),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in const [
                      ('Normal', 1.0),
                      ('Besar', 1.15),
                      ('Sangat Besar', 1.30),
                      ('Ekstra', 1.45),
                    ])
                      ChoiceChip(
                        label: Text(preset.$1),
                        selected: (s.fontScale - preset.$2).abs() < 0.03,
                        onSelected: (_) => AppAppearance.instance
                            .update(s.copyWith(fontScale: preset.$2)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Warna Tema',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final p in kThemePalettes)
                      _ColorSwatch(
                        palette: p,
                        selected: s.paletteId == p.id,
                        onTap: () => AppAppearance.instance
                            .update(s.copyWith(paletteId: p.id)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Mode Layar',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Terang'),
                          icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Gelap'),
                          icon: Icon(Icons.dark_mode_outlined)),
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('HP'),
                          icon: Icon(Icons.phone_android)),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (m) => AppAppearance.instance
                        .update(s.copyWith(themeMode: m.first)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final ThemePalette palette;
  final bool selected;
  final VoidCallback onTap;
  const _ColorSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? palette.color
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: palette.color,
              child: selected
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(palette.name,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _qris = TextEditingController();
  DateTime? _lastBackup;
  bool _busyBackup = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = AppDb.instance;
    _name.text = await db.getSetting('store_name', 'Kresna Laundry');
    _address.text = await db.getSetting('store_address');
    _phone.text = await db.getSetting('store_phone');
    _qris.text = await db.getSetting('qris_static');
    final lastStr = await db.getSetting('last_backup_at');
    _lastBackup = lastStr.isEmpty ? null : DateTime.tryParse(lastStr);
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _backupNow() async {
    setState(() => _busyBackup = true);
    try {
      final at = await BackupService.backupToDrive();
      if (mounted) {
        setState(() => _lastBackup = at);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Pilih "Drive" (Google Drive) pada menu bagikan untuk menyimpan cadangan ke akun Google Anda.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuat cadangan: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _restoreNow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data dari Cadangan?'),
        content: const Text(
          'Semua data pesanan, tarif layanan, dan pengaturan di HP ini akan diganti dengan isi file cadangan yang Anda pilih dari Google Drive / penyimpanan HP.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Pilih File Cadangan')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busyBackup = true);
    try {
      final count = await BackupService.restoreFromFile();
      if (count != null && mounted) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Berhasil memulihkan $count pesanan beserta layanan & pengaturan.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memulihkan data: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _qris.dispose();
    super.dispose();
  }

  Future<void> _saveQris() async {
    final raw = QrisService.sanitize(_qris.text);
    if (raw.isNotEmpty && !QrisService.isValid(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Kode QRIS tidak valid. Pastikan salin seluruh teks QRIS (diawali 000201...).'),
      ));
      return;
    }
    _qris.text = raw;
    await AppDb.instance.setSetting('qris_static', raw);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(raw.isEmpty
            ? 'Kode QRIS dihapus.'
            : 'Kode QRIS Dinamis berhasil disimpan.'),
      ));
    }
  }

  Future<void> _saveStore() async {
    final db = AppDb.instance;
    final name =
        _name.text.trim().isEmpty ? 'Kresna Laundry' : _name.text.trim();
    await db.setSetting('store_name', name);
    await db.setSetting('store_address', _address.text.trim());
    await db.setSetting('store_phone', _phone.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Identitas usaha disimpan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<AppearanceState>(
              valueListenable: AppAppearance.instance,
              builder: (context, s, _) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Bagian 1: Mode Ramah Orang Tua & Pratinjau Langsung
                        Card(
                          color: cs.primary.withValues(alpha: 0.08),
                          child: SwitchListTile(
                            secondary: CircleAvatar(
                              backgroundColor: cs.primary,
                              child: const Icon(Icons.visibility,
                                  color: Colors.white),
                            ),
                            title: const Text(
                              'Mode Ramah Orang Tua',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Otomatis memperbesar huruf (130%), menebalkan teks, meningkatkan kontras, dan memperbesar tombol.',
                            ),
                            value: s.isSeniorFriendly,
                            onChanged: (v) =>
                                AppAppearance.instance.toggleSeniorMode(v),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pratinjau Langsung
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pratinjau Tampilan',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Budi • CGS-261122-001',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cuci + Gosok 4 kg • One Day (1 hari) • Rp 60.000',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 8),
                                const Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    StatusBadge(
                                        'Sedang Diproses', Color(0xFF1565C0)),
                                    StatusBadge(
                                        'Belum Lunas', Color(0xFFC62828)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bagian 2: Tampilan, Huruf & Warna
                        _sectionTitle(context, 'Tampilan & Kenyamanan Mata'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Ukuran Huruf',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text('${(s.fontScale * 100).round()}%',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: cs.primary)),
                                  ],
                                ),
                                Slider(
                                  value: s.fontScale,
                                  min: 0.9,
                                  max: 1.45,
                                  divisions: 11,
                                  label: '${(s.fontScale * 100).round()}%',
                                  onChanged: (v) => AppAppearance.instance
                                      .update(s.copyWith(fontScale: v)),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final preset in const [
                                      ('Normal', 1.0),
                                      ('Besar', 1.15),
                                      ('Sangat Besar', 1.30),
                                      ('Ekstra Besar', 1.45),
                                    ])
                                      ChoiceChip(
                                        label: Text(preset.$1),
                                        selected:
                                            (s.fontScale - preset.$2).abs() <
                                                0.03,
                                        onSelected: (_) =>
                                            AppAppearance.instance.update(
                                                s.copyWith(
                                                    fontScale: preset.$2)),
                                      ),
                                  ],
                                ),
                                const Divider(height: 28),
                                const Text('Warna Tema',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final p in kThemePalettes)
                                      _ColorSwatch(
                                        palette: p,
                                        selected: s.paletteId == p.id,
                                        onTap: () => AppAppearance.instance
                                            .update(
                                                s.copyWith(paletteId: p.id)),
                                      ),
                                  ],
                                ),
                                const Divider(height: 28),
                                const Text('Mode Layar',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: SegmentedButton<ThemeMode>(
                                    segments: const [
                                      ButtonSegment(
                                          value: ThemeMode.light,
                                          label: Text('Terang'),
                                          icon:
                                              Icon(Icons.light_mode_outlined)),
                                      ButtonSegment(
                                          value: ThemeMode.dark,
                                          label: Text('Gelap'),
                                          icon: Icon(Icons.dark_mode_outlined)),
                                      ButtonSegment(
                                          value: ThemeMode.system,
                                          label: Text('Ikuti HP'),
                                          icon: Icon(Icons.phone_android)),
                                    ],
                                    selected: {s.themeMode},
                                    onSelectionChanged: (m) =>
                                        AppAppearance.instance.update(
                                            s.copyWith(themeMode: m.first)),
                                  ),
                                ),
                                const Divider(height: 24),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Kontras Tinggi'),
                                  subtitle: const Text(
                                      'Garis tepi & teks lebih tajam agar mudah dibaca'),
                                  value: s.highContrast,
                                  onChanged: (v) => AppAppearance.instance
                                      .update(s.copyWith(highContrast: v)),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Huruf Lebih Tebal'),
                                  subtitle: const Text(
                                      'Membuat semua tulisan lebih jelas dibaca'),
                                  value: s.boldText,
                                  onChanged: (v) => AppAppearance.instance
                                      .update(s.copyWith(boldText: v)),
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Tombol Lebih Besar'),
                                  subtitle: const Text(
                                      'Area sentuh tombol lebih lega & nyaman'),
                                  value: s.largeButtons,
                                  onChanged: (v) => AppAppearance.instance
                                      .update(s.copyWith(largeButtons: v)),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        AppAppearance.instance.reset(),
                                    icon: const Icon(Icons.restart_alt),
                                    label: const Text('Reset ke Default'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bagian 3: Identitas Usaha
                        _sectionTitle(context,
                            'Identitas Usaha (tampil di nota & WhatsApp)'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                TextField(
                                    controller: _name,
                                    decoration: const InputDecoration(
                                        labelText: 'Nama usaha',
                                        prefixIcon: Icon(Icons.store_outlined))),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: _address,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                        labelText: 'Alamat',
                                        prefixIcon:
                                            Icon(Icons.location_on_outlined))),
                                const SizedBox(height: 12),
                                TextField(
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                        labelText: 'Telepon / WhatsApp usaha',
                                        prefixIcon: Icon(Icons.phone_outlined))),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _saveStore,
                                    icon: const Icon(Icons.save),
                                    label: const Text('Simpan Identitas Usaha'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bagian 4: Pembayaran QRIS Dinamis (DANA Bisnis / Bank)
                        _sectionTitle(context,
                            'Pembayaran QRIS Dinamis (DANA Bisnis / Bank)'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tempel teks QRIS statis milik Anda (dari DANA Bisnis, GoPay Merchant, BRI, BCA, Mandiri, dll.). '
                                  'Nominal tagihan akan terisi otomatis setiap kali pelanggan scan.',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _qris,
                                  maxLines: 3,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Kode Teks QRIS Statis',
                                    hintText: '00020101021126...',
                                    helperText:
                                        'Tips: Scan gambar QRIS Anda pakai Google Lens / pemindai QR HP, lalu salin teksnya ke sini.',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_qris.text.trim().isNotEmpty) ...[
                                  if (QrisService.isValid(_qris.text))
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E7D32)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: QrImageView(
                                              data: _qris.text.trim(),
                                              size: 56,
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'QRIS Valid & Siap Dipakai',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                                Text(
                                                  'Merchant: ${QrisService.parseMerchantName(_qris.text) ?? '-'}',
                                                  style: const TextStyle(
                                                      fontSize: 12.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Format QRIS belum valid (harus diawali 000201...).',
                                      style: TextStyle(
                                          color: Color(0xFFC62828),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _saveQris,
                                        icon: const Icon(Icons.qr_code_2),
                                        label: const Text('Simpan QRIS'),
                                      ),
                                    ),
                                    if (_qris.text.trim().isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: () {
                                          setState(_qris.clear);
                                          _saveQris();
                                        },
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Bagian 5: Cadangan Data (Google Drive)
                        _sectionTitle(
                            context, 'Cadangan Data (Google Drive)'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF15803D)
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.cloud_upload_outlined,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Cadangan ke Akun Google Drive',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                          Text(
                                            _lastBackup == null
                                                ? 'Belum pernah dicadangkan'
                                                : 'Terakhir backup: ${fmtDateTime(_lastBackup!)}',
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Simpan semua pesanan, pelanggan, tarif layanan, dan QRIS ke Google Drive Anda agar data tidak hilang saat ganti HP atau hapus aplikasi.',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF15803D),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _busyBackup ? null : _backupNow,
                                    icon: _busyBackup
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Icon(Icons.backup),
                                    label: const Text('Backup ke Google Drive'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _busyBackup ? null : _restoreNow,
                                    icon: const Icon(
                                        Icons.cloud_download_outlined),
                                    label: const Text(
                                        'Pulihkan (Restore) dari Google Drive'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tarif layanan, waktu pengerjaan, dan status aktif layanan diatur di menu Layanan.',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12.5),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}
