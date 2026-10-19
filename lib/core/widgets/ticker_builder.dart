import 'dart:async';

import 'package:flutter/widgets.dart';

/// Przebudowuje [builder] co [interval], np. dla czasu treningu i przerwy.
/// Czas odczytuje sam builder (z zegara aplikacji), więc w testach stały
/// zegar daje stabilny wynik.
class TickerBuilder extends StatefulWidget {
  const TickerBuilder({
    required this.builder,
    this.interval = const Duration(seconds: 1),
    super.key,
  });

  final WidgetBuilder builder;
  final Duration interval;

  @override
  State<TickerBuilder> createState() => _TickerBuilderState();
}

class _TickerBuilderState extends State<TickerBuilder> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
