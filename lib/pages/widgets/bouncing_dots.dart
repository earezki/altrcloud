import 'package:flutter/material.dart';

class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key});

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animation!,
          builder: (context, child) {
            return Transform.scale(
//              offset: Offset(0, 10 * _animation!.value),
              scale: 0.2 + _animation!.value,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0),
                child: Dot(),
              ),
            );
          },
        );
      }),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5.0,
      height: 5.0,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary,
        shape: BoxShape.circle,
      ),
    );
  }
}
