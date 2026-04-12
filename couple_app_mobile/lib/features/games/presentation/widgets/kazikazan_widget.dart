import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:scratcher/scratcher.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';

class KazikazanWidget extends StatefulWidget {
  const KazikazanWidget({super.key});

  @override
  State<KazikazanWidget> createState() => _KazikazanWidgetState();
}

class _KazikazanWidgetState extends State<KazikazanWidget> {
  bool _isFinished = false;
  bool _isLoading = true;
  String? _taskId;
  String _taskText = "Bugün partnerine en sevdiği kahveyi ısmarla! ☕";
  bool _isAccepted = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _fetchDailyTask();
  }

  Future<void> _fetchDailyTask() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/MiniGames/daily-task'),
        headers: {'Authorization': 'Bearer MOCK_TOKEN'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _taskId = data['id'];
          _taskText = data['taskText'];
          _isAccepted = data['isAccepted'] ?? false;
          _isCompleted = data['isCompleted'] ?? false;
        });
      } else {
        setState(() => _taskText = "Günün görevi bulunamadı. (Admin beklemede)");
      }
    } catch (e) {
       // fallback silently on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptTask() async {
    if (_taskId == null) return;
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/MiniGames/accept-task'),
        headers: {'Authorization': 'Bearer MOCK_TOKEN', 'Content-Type': 'application/json'},
        body: jsonEncode(_taskId),
      );
      setState(() => _isAccepted = true);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _completeTask() async {
    if (_taskId == null) return;
    try {
      await http.patch(
        Uri.parse('${AppConfig.baseUrl}/api/MiniGames/complete-task/$_taskId'),
        headers: {'Authorization': 'Bearer MOCK_TOKEN'},
      );
      setState(() => _isCompleted = true);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Görev Tamamlandı! +10 Puan 🎉"), backgroundColor: Colors.green),
         );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Günün Tatlı Görevi",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Scratcher(
              brushSize: 40,
              threshold: 50,
              color: Colors.grey[400]!,
              image: Image.network(
                "https://images.unsplash.com/photo-1614850523296-d8c1af93d400?q=80&w=500&auto=format&fit=crop",
                fit: BoxFit.cover,
              ),
              onChange: (value) => debugPrint("Scratch progress: $value%"),
              onThreshold: () => setState(() => _isFinished = true),
              child: Container(
                height: 150,
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(20),
                color: AppColors.primary.withAlpha(20),
                child: _isLoading ? const CircularProgressIndicator() : Text(
                  _taskText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isFinished ? AppColors.accent : Colors.transparent,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_isFinished)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isCompleted 
              ? const Text("Görev Tamamlandı ✅", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
              : ElevatedButton(
                onPressed: _isAccepted ? _completeTask : _acceptTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAccepted ? Colors.purpleAccent : AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isAccepted ? "Görevi Tamamla" : "Görevi Kabul Et"),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                "Görevi görmek için kazı!",
                style: TextStyle(color: AppColors.onSurfaceMuted),
              ),
            ),
        ],
      ),
    );
  }
}
