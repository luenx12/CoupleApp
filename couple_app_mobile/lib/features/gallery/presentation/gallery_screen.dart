// Removed typed_data
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/gallery_notifier.dart';
import 'widgets/gallery_image_cell.dart';
import 'widgets/vault_cell.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUpload() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();

    // Show locked until dialog
    if (!mounted) return;
    
    // Dialog returns:
    // null -> User cancelled
    // DateTime -> The lock end date (if past date, means "Share Now")
    final selectedDate = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) => _TimeCapsuleDialog(),
    );

    if (selectedDate == null) {
      // User cancelled upload
      return; 
    }

    final DateTime? lockedUntil = selectedDate.year < 2000 ? null : selectedDate;

    try {
      await ref.read(galleryNotifierProvider.notifier).uploadPhoto(bytes, lockedUntil);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // Let main_screen gradient show
      appBar: AppBar(
        title: const Text('Ortak Galeri', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ref.read(galleryNotifierProvider.notifier).fetchItems(),
          ),
        ],
      ),
      body: _buildBody(state),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUpload,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildBody(GalleryState state) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Text(
          'Hata: ${state.error}',
          style: const TextStyle(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: Text(
          'Henüz fotoğraf yüklenmedi.\nİlk anınızı paylaşın!',
          style: TextStyle(color: AppColors.onSurfaceMuted),
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // bottom padding for FAB
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: item.isLocked
              ? VaultCell(item: item)
              : GalleryImageCell(item: item),
        ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index % 10)));
      },
    );
  }
}

class _TimeCapsuleDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.lock_clock_rounded, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Zaman Kapsülü', style: TextStyle(color: AppColors.onSurface, fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Bu fotoğrafı ne zaman açılır şekilde yollamak istersin?',
            style: TextStyle(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, DateTime(1970)), // Hemen Paylaş
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('Hemen Paylaş'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, DateTime.now().add(const Duration(minutes: 5))), 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('⏳ 5 Dakika Sonra (Test)', style: TextStyle(color: AppColors.onSurface)),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, DateTime.now().add(const Duration(days: 90))), 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('🔒 3 Ay Sonra', style: TextStyle(color: AppColors.onSurface)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('İptal', style: TextStyle(color: AppColors.onSurfaceMuted)),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}
