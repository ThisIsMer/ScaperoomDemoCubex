import 'package:flutter/material.dart';

class SimboloButton extends StatelessWidget {
  final int direccion;
  final VoidCallback onPressed;

  const SimboloButton(
      {super.key, required this.direccion, required this.onPressed});

  static const _datos = [
    ('○', 'Norte'),
    ('□', 'Este'),
    ('△', 'Sur'),
    ('✕', 'Oeste'),
  ];

  @override
  Widget build(BuildContext context) {
    final (simbolo, label) = _datos[direccion];
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38, width: 1.5),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(simbolo,
                style:
                const TextStyle(color: Colors.white, fontSize: 32)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}