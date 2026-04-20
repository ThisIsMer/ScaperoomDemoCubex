import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ═══════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL
// ═══════════════════════════════════════════════════════════

class CamarasScreen extends StatefulWidget {
  const CamarasScreen({super.key});

  @override
  State<CamarasScreen> createState() => _CamarasScreenState();
}

class _CamarasScreenState extends State<CamarasScreen> {
  int? _camaraFocusada; // null = vista grid | 1-4 = cámara enfocada

  void _toggleFocus(int camId) {
    setState(() {
      _camaraFocusada = _camaraFocusada == camId ? null : camId;
    });
  }

  Widget _buildCamara(int camId) {
    switch (camId) {
      case 1:
        return _CameraImage(
          camId: camId,
          asset: 'assets/images/Camara1.png',
          onTap: () => _toggleFocus(camId),
        );
      case 2:
        return _CameraImage(
          camId: camId,
          asset: 'assets/images/Camara2.png',
          onTap: () => _toggleFocus(camId),
        );
      case 3:
        return _CameraVideo(
          camId: camId,
          asset: 'assets/videos/camara3.mp4',
          onTap: () => _toggleFocus(camId),
        );
      case 4:
      default:
        return _CameraEmpty(
          camId: camId,
          onTap: () => _toggleFocus(camId),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Barra superior ──────────────────────────────
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _camaraFocusada != null
                      ? () => setState(() => _camaraFocusada = null)
                      : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  label: Text(
                    _camaraFocusada != null ? 'TODAS' : 'VOLVER',
                    style: const TextStyle(
                        color: Colors.white70, letterSpacing: 2),
                  ),
                ),
                const SizedBox(width: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _camaraFocusada != null
                        ? 'CAM $_camaraFocusada — ENFOCADA'
                        : 'SISTEMA DE VIGILANCIA',
                    key: ValueKey(_camaraFocusada),
                    style: const TextStyle(
                        color: Colors.green, letterSpacing: 4, fontSize: 13),
                  ),
                ),
                const Spacer(),
                const _RecordingDot(),
              ],
            ),
          ),

          // ── Contenido principal ──────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _camaraFocusada != null
                // ── Vista enfocada: una cámara a pantalla completa ──
                    ? KeyedSubtree(
                  key: ValueKey('focus_$_camaraFocusada'),
                  child: _buildCamara(_camaraFocusada!),
                )
                // ── Vista grid 2×2 ──────────────────────────────────
                    : KeyedSubtree(
                  key: const ValueKey('grid'),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildCamara(1)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildCamara(4)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _buildCamara(3)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildCamara(2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CONTENEDOR GENÉRICO DE CÁMARA
// ═══════════════════════════════════════════════════════════

class _CameraShell extends StatelessWidget {
  final int camId;
  final Widget content;
  final String? subLabel;
  final double staticIntensity;
  final VoidCallback? onTap;

  const _CameraShell({
    required this.camId,
    required this.content,
    this.subLabel,
    this.staticIntensity = 0.35,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: Colors.green.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,

              if (staticIntensity > 0)
                _StaticOverlay(intensity: staticIntensity),

              // Etiqueta superior izquierda
              Positioned(
                top: 6,
                left: 8,
                child: Text(
                  'CAM $camId',
                  style: const TextStyle(
                      color: Colors.green, fontSize: 11, letterSpacing: 2),
                ),
              ),

              if (subLabel != null)
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Text(
                    subLabel!,
                    style: TextStyle(
                        color: Colors.green.withOpacity(0.6), fontSize: 10),
                  ),
                ),

              Positioned(
                top: 6,
                right: 8,
                child: _Timestamp(),
              ),

              // Icono de enfoque en la esquina inferior izquierda
              Positioned(
                bottom: 6,
                left: 8,
                child: Icon(
                  Icons.zoom_in,
                  color: Colors.green.withOpacity(0.45),
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CÁMARA CON IMAGEN
// ═══════════════════════════════════════════════════════════

class _CameraImage extends StatelessWidget {
  final int camId;
  final String asset;
  final VoidCallback? onTap;

  const _CameraImage({
    required this.camId,
    required this.asset,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CameraShell(
      camId: camId,
      onTap: onTap,
      content: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[900],
          child: Center(
            child: Icon(Icons.image_not_supported,
                color: Colors.green.withOpacity(0.15), size: 40),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CÁMARA CON VÍDEO EN BUCLE
// ═══════════════════════════════════════════════════════════

class _CameraVideo extends StatefulWidget {
  final int camId;
  final String asset;
  final VoidCallback? onTap;

  const _CameraVideo({
    required this.camId,
    required this.asset,
    this.onTap,
  });

  @override
  State<_CameraVideo> createState() => _CameraVideoState();
}

class _CameraVideoState extends State<_CameraVideo> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.asset(widget.asset)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _ctrl
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CameraShell(
      camId: widget.camId,
      onTap: widget.onTap,
      content: _initialized
          ? FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _ctrl.value.size.width,
          height: _ctrl.value.size.height,
          child: VideoPlayer(_ctrl),
        ),
      )
          : Container(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Colors.green.withOpacity(0.5),
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CÁMARA SIN SEÑAL
// ═══════════════════════════════════════════════════════════

class _CameraEmpty extends StatelessWidget {
  final int camId;
  final VoidCallback? onTap;

  const _CameraEmpty({required this.camId, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CameraShell(
      camId: camId,
      onTap: onTap,
      subLabel: 'SIN SEÑAL',
      staticIntensity: 0.75,
      content: Container(color: const Color(0xFF0A0A0A)),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EFECTO DE ESTÁTICA / TV ANTIGUA
// ═══════════════════════════════════════════════════════════

class _StaticOverlay extends StatefulWidget {
  final double intensity;
  const _StaticOverlay({this.intensity = 0.35});

  @override
  State<_StaticOverlay> createState() => _StaticOverlayState();
}

class _StaticOverlayState extends State<_StaticOverlay> {
  final _repaint = ValueNotifier(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      _repaint.value++;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StaticPainter(_repaint, widget.intensity),
    );
  }
}

class _StaticPainter extends CustomPainter {
  static final _rng = Random();
  final ValueNotifier _tick;
  final double intensity;

  _StaticPainter(this._tick, this.intensity) : super(repaint: _tick);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;

    // ── 1. Ruido ──────────────────────────────────────────
    final numPixeles = (250 * intensity).toInt();
    for (int i = 0; i < numPixeles; i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final w = _rng.nextDouble() * 3 + 0.5;
      final h = _rng.nextDouble() * 2 + 0.5;
      final brightness = 160 + _rng.nextInt(95);
      paint.color = Color.fromRGBO(
        brightness, brightness, brightness,
        _rng.nextDouble() * 0.45 * intensity,
      );
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), paint);
    }

    // ── 2. Scanlines ──────────────────────────────────────
    paint.color = Colors.black.withOpacity(0.18 * intensity);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), paint);
    }

    // ── 3. Glitch ocasional ───────────────────────────────
    if (_rng.nextDouble() < 0.18 * intensity) {
      final gy = _rng.nextDouble() * size.height;
      final gh = _rng.nextDouble() * 10 + 2;
      paint.color =
          Colors.white.withOpacity(_rng.nextDouble() * 0.12 * intensity);
      canvas.drawRect(Rect.fromLTWH(0, gy, size.width, gh), paint);
    }

    // ── 4. Viñeta ─────────────────────────────────────────
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.55 * intensity),
        ],
        stops: const [0.55, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: size.width,
          height: size.height,
        ),
      );
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignette);
  }

  @override
  bool shouldRepaint(_StaticPainter old) => true;
}

// ═══════════════════════════════════════════════════════════
// TIMESTAMP
// ═══════════════════════════════════════════════════════════

class _Timestamp extends StatefulWidget {
  @override
  State<_Timestamp> createState() => _TimestampState();
}

class _TimestampState extends State<_Timestamp> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return Text(
      '$h:$m:$s',
      style: TextStyle(
          color: Colors.green.withOpacity(0.7),
          fontSize: 9,
          letterSpacing: 1),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// REC PARPADEANTE
// ═══════════════════════════════════════════════════════════

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: const Row(
        children: [
          Icon(Icons.circle, color: Colors.red, size: 10),
          SizedBox(width: 4),
          Text('REC', style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ),
    );
  }
}