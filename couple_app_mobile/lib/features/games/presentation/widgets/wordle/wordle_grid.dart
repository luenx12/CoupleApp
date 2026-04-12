import 'dart:math';
import 'package:flutter/material.dart';
import '../../../domain/wordle_notifier.dart';

class WordleGrid extends StatelessWidget {
  final WordleState state;

  const WordleGrid({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(6, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (c) {
            String char = state.board[r][c];
            LetterState lState = state.boardStates[r][c];
            bool isActiveRow = r == state.currentRow;

            return _WordleTile(
              char: char,
              letterState: lState,
              isActiveRow: isActiveRow,
            );
          }),
        );
      }),
    );
  }
}

class _WordleTile extends StatefulWidget {
  final String char;
  final LetterState letterState;
  final bool isActiveRow;

  const _WordleTile({
    required this.char,
    required this.letterState,
    required this.isActiveRow,
  });

  @override
  State<_WordleTile> createState() => _WordleTileState();
}

class _WordleTileState extends State<_WordleTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  LetterState _oldState = LetterState.initial;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animation = Tween<double>(begin: 0, end: pi).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _oldState = widget.letterState;
  }

  @override
  void didUpdateWidget(covariant _WordleTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.letterState != LetterState.initial && oldWidget.letterState == LetterState.initial) {
      _controller.forward();
    }
    _oldState = widget.letterState;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBgColor(LetterState s) {
    switch (s) {
      case LetterState.correct: return Colors.green;
      case LetterState.present: return Colors.amber;
      case LetterState.absent: return Colors.grey.shade800;
      case LetterState.initial: return Colors.transparent;
    }
  }

  Color _getBorderColor(LetterState s, bool hasChar) {
    if (s != LetterState.initial) return Colors.transparent;
    return hasChar ? Colors.grey.shade400 : Colors.grey.shade800;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _animation.value;
        final isFront = angle < (pi / 2);
        
        final displayState = isFront ? LetterState.initial : widget.letterState;
        final bgColor = _getBgColor(displayState);
        final borderColor = _getBorderColor(displayState, widget.char.isNotEmpty);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          alignment: Alignment.center,
          child: Container(
            width: 55,
            height: 55,
            margin: const EdgeInsets.all(4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: isFront 
              ? Text(
                  widget.char,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                )
              : Transform(
                  transform: Matrix4.identity()..rotateX(pi),
                  alignment: Alignment.center,
                  child: Text(
                    widget.char,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
          ),
        );
      },
    );
  }
}
