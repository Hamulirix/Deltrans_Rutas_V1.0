import 'package:flutter/material.dart';

class OptimizingDialog extends StatefulWidget {
  const OptimizingDialog({super.key});

  @override
  State<OptimizingDialog> createState() => _OptimizingDialogState();
}

class _OptimizingDialogState extends State<OptimizingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // gira infinito
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Evita que el usuario cierre con back o tocando fuera
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _ctrl,
              child: Icon(Icons.settings, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Optimizando rutas',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esto puede tardar unos minutos...',
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 4),
          ],
        ),
      ),
    );
  }
}
