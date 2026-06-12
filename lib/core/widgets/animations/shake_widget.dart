import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShakeWidget extends StatefulWidget {
  final Widget child;

  const ShakeWidget({super.key, required this.child});

  @override
  State<ShakeWidget> createState() => ShakeWidgetState();
}

class ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offset = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  void shake() {
    _ctrl.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _offset,
        builder: (_, child) => Transform.translate(
          offset: Offset(_offset.value, 0),
          child: child,
        ),
        child: widget.child,
      );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
