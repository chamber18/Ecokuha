import 'package:flutter/painting.dart';

/// Image provider for remote images (profile photos, posting photos, ...).
///
/// Supabase Storage buckets used for images are public, so a plain
/// [NetworkImage] is all that is needed. Usage: `AppImageProvider(url)`.
typedef AppImageProvider = NetworkImage;
