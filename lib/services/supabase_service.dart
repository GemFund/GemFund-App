import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Replace these with your Supabase credentials
  static const String supabaseUrl = 'https://zoitxpaqnkxfxmgstfmx.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvaXR4cGFxbmt4ZnhtZ3N0Zm14Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MzM1MjksImV4cCI6MjA4MDMwOTUyOX0.Kor1vYvoLbp0gTTwEeCF0L2QCE99xAdvWrZdzE5FQhk';
  static const String bucketName = 'campaign-images';

  late final SupabaseClient _client;
  bool _isInitialized = false;

  // Initialize Supabase
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      throw Exception('Failed to initialize Supabase: $e');
    }
  }

  // Upload image to Supabase Storage
  Future<String> uploadImage(File imageFile) async {
    try {
      await initialize();

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      // Use .jpg as default if no extension
      final fileName = 'campaign_$timestamp${extension.isEmpty ? '.jpg' : extension}';
      final filePath = 'campaigns/$fileName';

      print('Uploading image: $filePath');

      // Upload file to Supabase Storage
      await _client.storage
          .from(bucketName)
          .upload(
            filePath,
            imageFile,
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      print('Public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Upload image from bytes (for Windows compatibility)
  Future<String> uploadImageBytes(List<int> bytes, String originalFileName) async {
    try {
      await initialize();

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(originalFileName);
      // Use .jpg as default if no extension
      final fileName = 'campaign_$timestamp${extension.isEmpty ? '.jpg' : extension}';
      final filePath = 'campaigns/$fileName';

      print('Uploading image from bytes: $filePath');

      // Convert List<int> to Uint8List
      final uint8bytes = Uint8List.fromList(bytes);

      // Upload bytes to Supabase Storage
      await _client.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            uint8bytes,
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      print('Public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('Error uploading image bytes: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  // Delete image from Supabase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      await initialize();

      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the index where 'campaign-images' bucket appears
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1) {
        throw Exception('Invalid image URL');
      }

      // Get the path after bucket name
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      print('Deleting image: $filePath');

      // Delete file from Supabase Storage
      await _client.storage
          .from(bucketName)
          .remove([filePath]);

      print('Image deleted successfully');
    } catch (e) {
      print('Error deleting image: $e');
      // Don't throw error, just log it
    }
  }

  // Check if URL is from Supabase
  bool isSupabaseUrl(String url) {
    return url.contains(supabaseUrl) && url.contains(bucketName);
  }

  // Get file size in MB
  static double getFileSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }

  // Check if file size is within limit (max 5MB for free tier)
  static bool isFileSizeValid(File file, {double maxSizeMB = 5.0}) {
    return getFileSizeInMB(file) <= maxSizeMB;
  }
}