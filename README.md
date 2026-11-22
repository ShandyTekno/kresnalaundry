# Kresna Laundry

Aplikasi manajemen operasional laundry (Flutter + SQLite) untuk satu pengguna: Admin/Pemilik.

## Menjalankan

Folder ini berisi `pubspec.yaml` dan `lib/`. Folder platform (android/ios) belum ada, buat dulu:

```bash
cd kresna_laundry
flutter create . --org com.kresna --project-name kresna_laundry --platforms=android,ios
flutter pub get
flutter run
```

`flutter create .` tidak menimpa `lib/` dan `pubspec.yaml` yang sudah ada.
Jika `flutter pub get` melaporkan konflik versi `intl`, sesuaikan versinya dengan yang diminta `flutter_localizations` pada SDK Anda.

## Pengaturan platform

**Android** — `android/app/src/main/AndroidManifest.xml`, di dalam `<manifest>` (sejajar dengan `<application>`):

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
</queries>
```

Untuk Android 9 ke bawah, tambahkan juga `<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />` agar nota JPG bisa disimpan ke galeri.
`minSdkVersion` minimal 21 (atau 24 jika diminta plugin `gal` versi Anda).

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Untuk menyimpan nota laundry ke galeri.</string>
```

## Struktur

```
lib/
  main.dart                 inisialisasi DB, locale id_ID
  core/                     tema biru-putih, format rupiah/tanggal, normalisasi nomor +62
  models/models.dart        paket, jenis barang, pesanan, label & warna status
  data/database.dart        SQLite: skema, seed, query, laporan
  services/whatsapp_service.dart   pesan + wa.me (Click to Chat)
  screens/                  dashboard, pesanan, form, detail, nota, pelanggan, layanan, laporan, pengaturan
```

## Aturan penting yang diterapkan

- Status pengerjaan dan status pembayaran terpisah; mengubah satu tidak mengubah yang lain.
- Lunas hanya berubah lewat dialog "Konfirmasi Pembayaran" (Tunai / QRIS manual). Dapat dibatalkan.
- Nama paket, estimasi, nama barang, dan harga satuan disalin ke setiap pesanan, jadi perubahan harga tidak mengubah transaksi lama.
- Kode pesanan: `KODEBARANG-yyMMdd-nnn` (contoh `KLO-261122-001`), nomor urut harian per kode barang, unik di database.
- WhatsApp: membuka `https://wa.me/62…?text=…` setelah admin meninjau/mengedit pesan; admin menekan Kirim sendiri. Tidak ada API berbayar.
  - Konfirmasi: selalu tersedia. Selesai: aktif jika status pengerjaan Selesai/Sudah Diambil. Pembayaran: aktif jika Lunas.
- Nota: dirender dari widget, QR berisi kode pesanan, diekspor ke JPG dan disimpan ke galeri.
- Pendapatan = jumlah pesanan berstatus Lunas. "Pesanan selesai" = Selesai + Sudah Diambil.

## Data awal (contoh, ubah di menu Layanan)

| Barang | Hemat | Standar | Express |
|---|---|---|---|
| Kiloan (per kg) | 5.000 | 7.000 | 10.000 |
| Sepatu | 20.000 | 25.000 | 35.000 |
| Boneka | 15.000 | 20.000 | 30.000 |
| Selimut | 20.000 | 25.000 | 35.000 |
| Gorden | 25.000 | 30.000 | 40.000 |
| Karpet | 30.000 | 40.000 | 55.000 |

Estimasi awal: Hemat 3 hari, Standar 2 hari, Express 1 hari.
