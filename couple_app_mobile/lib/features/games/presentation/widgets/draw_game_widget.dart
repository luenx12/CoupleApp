import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/draw_game_model.dart';
import '../../domain/draw_game_notifier.dart';
import 'draw_canvas_painter.dart';

class DrawGameWidget extends ConsumerStatefulWidget {
  const DrawGameWidget({super.key});

  @override
  ConsumerState<DrawGameWidget> createState() => _DrawGameWidgetState();
}

class _DrawGameWidgetState extends ConsumerState<DrawGameWidget> {
  DrawStroke? _currentStroke;

  @override
  void initState() {
    super.initState();
    // Fetch initial words when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawGameNotifierProvider.notifier).fetchWordOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drawGameNotifierProvider);
    final notifier = ref.read(drawGameNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çizim & Tahmin'),
        actions: [
          if (state.phase == DrawPhase.drawing)
             Center(child: Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Text(
                 '${state.secondsLeft}s',
                 style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: state.secondsLeft <= 10 ? Colors.red : Colors.white,
                 ),
               ),
             )),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => notifier.resetGame(),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
             _buildStatusBar(state, notifier),
             
             // Canvas Area
            Expanded(
              child: _buildCanvasArea(state, notifier),
            ),

            // Controls Area
            _buildControlsArea(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(DrawGameState state, DrawGameNotifier notifier) {
    if (state.phase == DrawPhase.idle || state.phase == DrawPhase.wordSelection) {
      if (state.isLoading) {
        return const LinearProgressIndicator();
      }
      if (state.error != null) {
        return Container(
          color: Colors.red.withOpacity(0.8),
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          child: Text(state.error!, style: const TextStyle(color: Colors.white)),
        );
      }
      return const SizedBox(height: 4); // Spacer
    }
    
    if (state.phase == DrawPhase.drawing) {
       if (state.role == DrawRole.drawer) {
          return Container(
            color: Colors.blueGrey.shade800,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: Text('Çizeceğin Kelime: ${state.secretWord}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
       } else {
         return Container(
            color: Colors.blueGrey.shade800,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            child: const Text('Partnerin çiziyor... Tahmin et!', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          );
       }
    }

    if (state.phase == DrawPhase.guessed) {
       return Container(
         color: Colors.green.shade700,
         width: double.infinity,
         padding: const EdgeInsets.all(12),
         child: Text(
           state.role == DrawRole.guesser 
            ? 'Bildin! Kazandığın puan: ${state.scoreAwarded}'
            : 'Partnerin bildi! Kelime: ${state.secretWord}',
           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
           textAlign: TextAlign.center,
         ),
       );
    }
    
     if (state.phase == DrawPhase.timeUp) {
       return Container(
         color: Colors.red.shade800,
         width: double.infinity,
         padding: const EdgeInsets.all(12),
         child: const Text(
           'Süre doldu! Kimse bilemedi.',
           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
           textAlign: TextAlign.center,
         ),
       );
    }

    return const SizedBox();
  }

  Widget _buildCanvasArea(DrawGameState state, DrawGameNotifier notifier) {
    if (state.phase == DrawPhase.wordSelection) {
      return _buildWordSelection(state, notifier);
    }

    return Stack(
      children: [
        GestureDetector(
          onPanStart: (details) {
            if (state.phase != DrawPhase.drawing || state.role != DrawRole.drawer) return;
            // Removed unused renderbox offset
             
            setState(() {
              _currentStroke = DrawStroke(
                points: [details.localPosition],
                color: state.selectedColor,
                strokeWidth: state.strokeWidth,
                isEraser: state.isEraser,
              );
            });
          },
          onPanUpdate: (details) {
            if (state.phase != DrawPhase.drawing || state.role != DrawRole.drawer || _currentStroke == null) return;
             setState(() {
              _currentStroke!.points.add(details.localPosition);
            });
          },
          onPanEnd: (details) {
             if (state.phase != DrawPhase.drawing || state.role != DrawRole.drawer || _currentStroke == null) return;
             notifier.addStroke(_currentStroke!);
             setState(() {
               _currentStroke = null;
             });
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: DrawCanvasPainter(
              localStrokes: state.localStrokes,
              remoteStrokes: state.remoteStrokes,
              currentStroke: _currentStroke,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordSelection(DrawGameState state, DrawGameNotifier notifier) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Çizmek için bir kelime seç', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          ...state.wordOptions.map((opt) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () => notifier.selectWord(opt.id),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(opt.word, style: const TextStyle(fontSize: 18)),
                    _buildDifficultyIndicator(opt.difficulty),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDifficultyIndicator(int level) {
    Color color;
    String text;
    switch(level) {
      case 0: color = Colors.green; text = 'Kolay'; break;
      case 1: color = Colors.orange; text = 'Orta'; break;
      case 2: color = Colors.red; text = 'Zor'; break;
      default: color = Colors.grey; text = '?';
    }
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
       child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  Widget _buildControlsArea(DrawGameState state, DrawGameNotifier notifier) {
    if (state.phase != DrawPhase.drawing) return const SizedBox();

    if (state.role == DrawRole.drawer) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black.withOpacity(0.5),
        child: Column(
          children: [
            // Colors
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Colors.white, Colors.black, Colors.red, Colors.blue, 
                  Colors.green, Colors.yellow, Colors.orange, Colors.purple, Colors.pink
                ].map((color) => GestureDetector(
                  onTap: () => notifier.setColor(color),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: state.selectedColor == color && !state.isEraser ? Colors.white : Colors.transparent, 
                        width: 2
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            // Tools
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: !state.isEraser ? Colors.blue : Colors.grey,
                  onPressed: () => notifier.setEraser(false),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services), // Eraser
                  color: state.isEraser ? Colors.blue : Colors.grey,
                  onPressed: () => notifier.setEraser(true),
                ),
                Expanded(
                  child: Slider(
                    value: state.strokeWidth,
                    min: 1.0,
                    max: 20.0,
                    onChanged: (val) => notifier.setStrokeWidth(val),
                  ),
                ),
                 IconButton(
                  icon: const Icon(Icons.delete_forever), 
                  color: Colors.redAccent,
                  onPressed: () => notifier.clearCanvas(),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Guesser area
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.black.withOpacity(0.5),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tahminini yaz...',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                onChanged: notifier.updateGuessText,
                onSubmitted: (_) => notifier.submitGuess(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: state.isLoading ? null : () => notifier.submitGuess(),
              child: state.isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Gönder'),
            )
          ],
        ),
      );
    }
  }
}
