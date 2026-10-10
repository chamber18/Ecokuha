import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'doc_mapper.dart';
import 'supabase_config.dart';

export 'doc_mapper.dart';
export 'supabase_config.dart';
export 'timestamp.dart';

/// Shared Supabase client (initialised in `main.dart`).
SupabaseClient get supabase => Supabase.instance.client;

/// Signed-in user id (== `auth.users.id`, also the id of the user's
/// households / collectors / junkshops row), or null when signed out.
String? get currentUid => supabase.auth.currentUser?.id;

/// Same as [currentUid] but throws when signed out.
String requireUid() {
  final id = currentUid;
  if (id == null) throw const AuthException('Not signed in');
  return id;
}

/// Maps a list of rows to document maps (see doc_mapper.dart).
List<Map<String, dynamic>> rowsToDocs(String table, List<dynamic> rows) =>
    rows.map((r) => rowToDoc(table, Map<String, dynamic>.from(r as Map))).toList();

/// Uploads [file] to [bucket]/[path] (upsert) and returns its public URL.
/// Public buckets only (everything except [SupabaseConfig.documentsBucket]).
/// A cache-busting `?v=` query is appended so replaced images refresh.
Future<String> uploadPublicFile({
  required String bucket,
  required String path,
  File? file,
  Uint8List? bytes,
  String contentType = 'image/jpeg',
}) async {
  assert(file != null || bytes != null, 'Provide file or bytes');
  final storage = supabase.storage.from(bucket);
  final options = FileOptions(upsert: true, contentType: contentType);
  if (bytes != null) {
    await storage.uploadBinary(path, bytes, fileOptions: options);
  } else {
    await storage.upload(path, file!, fileOptions: options);
  }
  final url = storage.getPublicUrl(path);
  return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
}

/// Uploads to the PRIVATE documents bucket and returns the object path
/// (store the path, not a URL; resolve with [signedDocumentUrl]).
Future<String> uploadPrivateDocument({
  required String path,
  File? file,
  Uint8List? bytes,
  String contentType = 'image/jpeg',
}) async {
  assert(file != null || bytes != null, 'Provide file or bytes');
  final storage = supabase.storage.from(SupabaseConfig.documentsBucket);
  final options = FileOptions(upsert: true, contentType: contentType);
  if (bytes != null) {
    await storage.uploadBinary(path, bytes, fileOptions: options);
  } else {
    await storage.upload(path, file!, fileOptions: options);
  }
  return path;
}

/// Short-lived URL for a private document path.
Future<String> signedDocumentUrl(String path, {int expiresInSeconds = 3600}) =>
    supabase.storage.from(SupabaseConfig.documentsBucket).createSignedUrl(path, expiresInSeconds);

/// Removes an object from a bucket (ignores "not found").
Future<void> deleteStorageObject(String bucket, String path) async {
  try {
    await supabase.storage.from(bucket).remove([path]);
  } catch (_) {}
}
