import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/games_notifier.dart';
// Note: We would use VideoPlayer for actual playback, but for the UI mockup
// we will focus on the capture and E2EE flow logic.

class RedRoomVideoTask extends ConsumerStatefulWidget {
  const RedRoomVideoTask({super.key});

  @override
  ConsumerState<RedRoomVideoTask> createState() => _RedRoomVideoTaskState();
}

class _RedRoomVideoTaskState extends ConsumerState<RedRoomVideoTask> {
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isTaskActive = false;
  final String _mockTask = "En sevdiğin kıyafetinle partnerine 10 saniyelik bir öpücük videosu gönder! 😘";

  void _startTask() {
    setState(() {
      _isTaskActive = true;
      _secondsRemaining = 120; // 2 minutes to complete
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        setState(() => _isTaskActive = false);
      }
    });
  }

  Future<void> _captureAndSend() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 15));
    
    if (file == null) return;

    // Zero-Leak E2EE Logic (Conceptual here, using CryptoService)
    // 1. Read bytes
    // 2. Encrypt with partner's public key (already implemented in GalleryRepository style)
    // 3. Upload to /api/Media/upload
    // 4. Send SignalR notify
    
    _timer?.cancel();
    setState(() => _isTaskActive = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔥 Özel video şifrelendi ve partnerine uçuruldu!"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gamesNotifierProvider);

    return Column(
      children: [
        // Incoming Media Notification (Self-Destruct UI)
        if (state.incomingMediaId != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D0000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent),
              boxShadow: [
                BoxShadow(color: Colors.redAccent.withAlpha(80), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, color: Colors.redAccent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Gelen Gizli Mesaj!",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Tek seferlik video. İzledikten sonra silinecek.",
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Logic: Fetch, Decrypt in RAM, Play, then Delete.
                    ref.read(gamesNotifierProvider.notifier).clearIncomingMedia();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("İZLE", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

        // Create Task Section
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.purpleAccent.withAlpha(50)),
          ),
          child: Column(
            children: [
              const Text(
                "Süreli Medya Görevi",
                style: TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              if (!_isTaskActive)
                Column(
                  children: [
                    const Icon(Icons.videocam_rounded, size: 48, color: Colors.white24),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent.withAlpha(50),
                        foregroundColor: Colors.purpleAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        side: const BorderSide(color: Colors.purpleAccent),
                      ),
                      child: const Text("RASGELE GÖREV AL"),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Text(
                      _mockTask,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Süre: $_secondsRemaining sn",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _captureAndSend,
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text("ŞİMDİ ÇEK VE GÖNDER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
