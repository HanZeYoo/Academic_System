import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AvatarUtils {
  /// Safely resolves any string (base64 data URI, raw base64, URL, or local file path) into an ImageProvider.
  static ImageProvider? getImageProvider(String? pathOrBase64) {
    if (pathOrBase64 == null) return null;
    final trimmed = pathOrBase64.trim();
    if (trimmed.isEmpty) return null;

    // 1. Network URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    // 2. Base64 (Data URI or raw base64)
    if (trimmed.startsWith('data:image') || trimmed.length > 200) {
      try {
        final base64Content = trimmed.contains(',') ? trimmed.split(',').last : trimmed;
        final cleanBase64 = base64Content.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleanBase64);
        return MemoryImage(bytes);
      } catch (_) {}
    }

    // 3. Local file path
    try {
      final file = File(trimmed);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}

    return null;
  }

  /// Builds a CircleAvatar displaying the photo or fallback initials/icon
  static Widget buildAvatar({
    String? photo,
    String? name,
    double radius = 24,
    Color? backgroundColor,
    Color? foregroundColor,
    IconData fallbackIcon = Icons.person,
  }) {
    final imageProvider = getImageProvider(photo);
    final themeColor = foregroundColor ?? const Color(0xFF1664C5);
    final bgColor = backgroundColor ?? const Color(0xFFE2E8F0);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? (name != null && name.trim().isNotEmpty
              ? Text(
                  name.trim()[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * 0.85,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                )
              : Icon(
                  fallbackIcon,
                  size: radius * 1.1,
                  color: themeColor,
                ))
          : null,
    );
  }

  /// Interactive picker modal that returns a Base64-encoded image string, or empty string if removed.
  static Future<String?> showPhotoPickerModal({
    required BuildContext context,
    required Color primaryColor,
    bool hasExistingPhoto = false,
  }) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.camera_alt_rounded, color: primaryColor),
                ),
                title: const Text('Take a photo', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.photo_library_rounded, color: primaryColor),
                ),
                title: const Text('Choose from gallery', style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (hasExistingPhoto)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE8E8),
                    child: Icon(Icons.delete_outline_rounded, color: Colors.red),
                  ),
                  title: const Text('Remove photo', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    if (source == 'remove') return '';

    final imageSource = source == 'camera' ? ImageSource.camera : ImageSource.gallery;
    try {
      final XFile? picked = await picker.pickImage(
        source: imageSource,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.red),
        );
      }
    }
    return null;
  }
}
