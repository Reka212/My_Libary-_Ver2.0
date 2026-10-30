import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../database/database_helper.dart';

class BackupService {
  static final GoogleSignIn _signIn =
      GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  static const String _fileName = 'perpustakaan_backup.json';

  //=========================================
  // AKUN GOOGLE
  //=========================================

  /// Akun yang sedang login (null kalau belum)
  static GoogleSignInAccount? get akun => _signIn.currentUser;

  /// Login diam-diam tanpa popup, dipakai saat halaman dibuka
  static Future<GoogleSignInAccount?> akunTersimpan() async {
    return _signIn.currentUser ?? await _signIn.signInSilently();
  }

  /// Tampilkan pemilih akun Google
  static Future<GoogleSignInAccount?> pilihAkun() => _signIn.signIn();

  /// Ganti ke akun Google lain
  static Future<GoogleSignInAccount?> gantiAkun() async {
    await _signIn.signOut();
    return _signIn.signIn();
  }

  static Future<void> logout() => _signIn.signOut();

  //=========================================
  // DRIVE
  //=========================================

  static Future<drive.DriveApi> _api() async {
    var acc = _signIn.currentUser ?? await _signIn.signInSilently();
    acc ??= await _signIn.signIn();
    if (acc == null) throw Exception('Login Google dibatalkan');

    final client = await _signIn.authenticatedClient();
    if (client == null) {
      throw Exception('Gagal mendapatkan akses Google Drive');
    }
    return drive.DriveApi(client);
  }

  static Future<drive.File?> _cariBackup(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id, modifiedTime, size)',
    );
    return (res.files?.isNotEmpty ?? false) ? res.files!.first : null;
  }

  /// Waktu backup terakhir (null kalau belum ada)
  static Future<DateTime?> waktuBackupTerakhir() async {
    final api = await _api();
    return (await _cariBackup(api))?.modifiedTime?.toLocal();
  }

  static Future<void> backup() async {
    final api = await _api();
    final bytes = utf8.encode(jsonEncode(DatabaseHelper.exportAll()));
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final ada = await _cariBackup(api);
    if (ada != null) {
      await api.files.update(drive.File(), ada.id!, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File(name: _fileName, parents: ['appDataFolder']),
        uploadMedia: media,
      );
    }
  }

  static Future<void> restore() async {
    final api = await _api();
    final ada = await _cariBackup(api);
    if (ada == null) throw Exception('Belum ada backup di Google Drive');

    final media = await api.files.get(
      ada.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    await DatabaseHelper.importAll(data);
  }
}