import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool loading = false;
  GoogleSignInAccount? akun;
  String? terakhir;

  @override
  void initState() {
    super.initState();
    _muatAwal();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _pesan(Object e) => e.toString().replaceFirst('Exception: ', '');

  String _fmt(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  // Login diam-diam (tanpa popup) kalau akun sudah pernah dipilih sebelumnya
  Future<void> _muatAwal() async {
    setState(() => loading = true);
    try {
      final a = await BackupService.akunTersimpan();
      if (!mounted) return;
      setState(() => akun = a);
      if (a != null) await cekWaktu();
    } catch (_) {
      // abaikan: pengguna bisa menghubungkan akun manual
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> hubungkan({bool ganti = false}) async {
    setState(() => loading = true);
    try {
      final a = ganti
          ? await BackupService.gantiAkun()
          : await BackupService.pilihAkun();
      if (!mounted) return;
      setState(() {
        akun = a;
        terakhir = null;
      });
      if (a != null) await cekWaktu();
    } catch (e) {
      if (mounted) _snack("Gagal: ${_pesan(e)}");
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> cekWaktu() async {
    try {
      final t = await BackupService.waktuBackupTerakhir();
      if (!mounted) return;
      setState(() {
        akun = BackupService.akun ?? akun;
        terakhir = t == null ? "Belum ada backup" : _fmt(t);
      });
    } catch (e) {
      if (mounted) _snack("Gagal: ${_pesan(e)}");
    }
  }

  Future<void> _jalankan(Future<void> Function() aksi, String sukses) async {
    setState(() => loading = true);
    try {
      await aksi();
      if (!mounted) return;
      setState(() => akun = BackupService.akun ?? akun);
      _snack(sukses);
    } catch (e) {
      if (!mounted) return;
      _snack("Gagal: ${_pesan(e)}");
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> backup() async {
    await _jalankan(BackupService.backup, "Backup berhasil diunggah");
    await cekWaktu();
  }

  Future<void> restore() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Konfirmasi Restore"),
        content: const Text(
          "Semua data saat ini (buku, anggota, peminjaman, admin) "
          "akan DIGANTI dengan data dari backup. Lanjutkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Pulihkan"),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await _jalankan(BackupService.restore, "Data berhasil dipulihkan");
  }

  Future<void> keluarGoogle() async {
    await BackupService.logout();
    if (!mounted) return;
    setState(() {
      akun = null;
      terakhir = null;
    });
    _snack("Akun Google dikeluarkan");
  }

  //=========================================
  // KARTU AKUN GOOGLE
  //=========================================
  Widget _kartuAkun() {
    if (akun == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.account_circle, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                "Belum terhubung ke akun Google",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: loading ? null : () => hubungkan(),
                icon: const Icon(Icons.login),
                label: const Text("Hubungkan Akun Google"),
              ),
            ],
          ),
        ),
      );
    }

    final a = akun!;
    final nama = (a.displayName ?? '').trim();
    final inisial = (nama.isNotEmpty ? nama : a.email)[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.shade100,
                  backgroundImage:
                      a.photoUrl != null ? NetworkImage(a.photoUrl!) : null,
                  child: a.photoUrl == null
                      ? Text(inisial, style: const TextStyle(fontSize: 22))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (nama.isNotEmpty)
                        Text(
                          nama,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      Text(
                        a.email,
                        style: const TextStyle(color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            "Terhubung",
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Backup terakhir: ${terakhir ?? '-'}",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  tooltip: "Periksa ulang",
                  icon: const Icon(Icons.refresh),
                  onPressed: loading ? null : cekWaktu,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: loading ? null : () => hubungkan(ganti: true),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text("Ganti akun"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Backup Google Drive"),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kartuAkun(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(15),
            ),
            onPressed: loading ? null : backup,
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Backup Sekarang"),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(15)),
            onPressed: loading ? null : restore,
            icon: const Icon(Icons.cloud_download),
            label: const Text("Pulihkan dari Google Drive"),
          ),
          if (akun != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: loading ? null : keluarGoogle,
              icon: const Icon(Icons.logout),
              label: const Text("Keluar dari akun Google"),
            ),
          ],
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 20),
          const Text(
            "Backup disimpan di folder tersembunyi milik aplikasi di Google Drive "
            "(tidak tampil di daftar file Drive Anda).",
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}