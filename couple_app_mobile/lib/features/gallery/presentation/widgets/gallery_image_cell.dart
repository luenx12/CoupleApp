import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/gallery_item_model.dart';
import '../../domain/gallery_notifier.dart';

class GalleryImageCell extends ConsumerStatefulWidget {
  const GalleryImageCell({super.key, required this.item});
  final GalleryItemModel item;

  @override
  ConsumerState<GalleryImageCell> createState() => _GalleryImageCellState();
}

class _GalleryImageCellState extends ConsumerState<GalleryImageCell> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    try {
      final bytes = await ref
          .read(galleryNotifierProvider.notifier)
          .downloadImage(widget.item.mediaId);
      
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: AppColors.surface.withAlpha(50),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_error != null || _imageBytes == null) {
      return Container(
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: AppColors.onSurfaceMuted),
        ),
      );
    }

    return Image.memory(
      _imageBytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}
