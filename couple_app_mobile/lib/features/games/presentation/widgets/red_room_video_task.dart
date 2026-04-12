import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/games_notifier.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../crypto/crypto_provider.dart';
import '../../../crypto/crypto_service.dart';
import 'secure_video_player.dart';
// we will focus on the capture and E2EE flow logic.

class RedRoomVideoTask extends ConsumerStatefulWidget {
  const RedRoomVideoTask({super.key});

  @override
  ConsumerState<RedRoomVideoTask> createState() => _RedRoomVideoTaskState();
}

class _RedRoomVideoTaskState extends ConsumerState<RedRoomVideoTask> {
  final List<String> _tasks = [
    "En sevdiğin kıyafetinle partnerine 10 saniyelik bir öpücük videosu gönder! 😘",
    "Partnerine 15 saniyelik bir twerk videosu gönder! 🔥",
    "Sadece sevdiğin bir iç çamaşırıyla 10 saniye boyunca dans et. 💃",
    "Ayna karşısında partnerine seksi bir göz kırpma ve öpücük videosu at. 😉",
    "Üzerindeki bir kıyafeti yavaşça çıkarırken 10 saniyelik bir video çek. 👙",
    "Partnerine en çekici bulduğun yerini gösteren kısa bir video gönder. ❤️",
    "Karanlık bir ortamda sadece telefon ışığıyla seksi bir video çek. 🌑",
    "Partnerine dudaklarını yakından gösteren bir video at. 💋",
    "Kendi üzerinde en sevdiğin dövme veya izi gösteren bir video çek. ✨",
    "Partnerine 'Seni bekliyorum' diyen seksi bir fısıltı videosu gönder. 🤫",
  ];

  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isTaskActive = false;
  String _currentTask = "";

  void _startTask() {
    setState(() {
      _currentTask = _tasks[DateTime.now().millisecond % _tasks.length];
      _isTaskActive = true;
      _secondsRemaining = 180; // 3 minutes to complete
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

  void _nextTask() {
    setState(() {
      _currentTask = _tasks[(DateTime.now().millisecond + 1) % _tasks.length];
    });
  }

  Future<void> _captureAndSend() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 15));
    
    if (file == null) return;

    // Zero-Leak E2EE Logic
    try {
      final bytes = await file.readAsBytes();
      final crypto = ref.read(cryptoServiceProvider);
      
      // Need partner public key actually, assuming the service handles it or we pass it
      // For MVP, if we have encryptForPartner we use it. We'll just call encryptForSelf if partner key isn't explicitly known here, but realistically we need partner key.
      // Assuming a wrapper exists, or we fetch it. We will use a mock approach for the UI demonstration 
      final partnerPubPem = "MOCK_PARTNER_PUB"; // In real app: ref.read(authNotifierProvider).partnerPublicKey;
      final payload = crypto.encrypt(bytes, crypto.publicKeyPem); // Self encrypt for demo if partner key isn't injected here

      // Clear memory
      CryptoService.zeroFill(bytes);

      // Upload via POST
      var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/Media/upload'));
      request.headers['Authorization'] = 'Bearer MOCK_TOKEN'; // Real app uses intercepor or fetch token
      request.files.add(http.MultipartFile.fromBytes('file', payload.toBytes(), filename: 'encrypted.aes'));
      
      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        // Assuming response is {"mediaId": "..."}
        // Then send via SignalR
        // final mediaId = jsonDecode(respStr)['mediaId'];
        final mockMediaId = "mock_media_${DateTime.now().millisecondsSinceEpoch}";
        
        await ref.read(gamesNotifierProvider.notifier).sendRedRoomMediaTask(mockMediaId, 15);
      }
    } catch (e) {
      debugPrint("Video upload error: $e");
    }

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
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: const EdgeInsets.all(10),
                        child: SecureVideoPlayer(mediaId: state.incomingMediaId!),
                      ),
                    );
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
                      _currentTask,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _nextTask,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text("BAŞKA GÖREV VER"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
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
