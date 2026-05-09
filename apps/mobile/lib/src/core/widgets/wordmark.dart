import 'package:flutter/material.dart';

import '../design/typography.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({this.color, this.size = 24, super.key});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).textTheme.bodyLarge?.color;
    return Text(
      'TRIBELY',
      semanticsLabel: 'Tribely',
      style: TribelyType.wordmark(c ?? Colors.black).copyWith(fontSize: size),
    );
  }
}
