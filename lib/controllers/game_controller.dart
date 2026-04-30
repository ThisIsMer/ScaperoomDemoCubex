import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/habitacion.dart';

class MovimientoResultado {
  final String tipo; // pared | bloqueada | avanzar | salida | encuentro_monstruo
  final bool monstruoCerca;
  final bool encuentroMonstruo;
  final bool puertaForzada;
  final int? probabilidad;
  final int? tirada;

  const MovimientoResultado({
    required this.tipo,
    this.monstruoCerca = false,
    this.encuentroMonstruo = false,
    this.puertaForzada = false,
    this.probabilidad,
    this.tirada,
  });
}

enum EstadoMonstruo { normal, cerca, encuentro }

class GameController extends ChangeNotifier {
  static const int filas = 4;
  static const int cols = 4;
  static const int maxErrores = 5;
  static const int maxIntentosForzar = 3;
  static const int _movsFrozenTotal = 6;

  // Habitaciones que deben cambiar tras espantar al monstruo
  // antes de que pueda volver a aparecer en la misma casilla
  static const int _cooldownEncuentroInicial = 3;

  final Random _rng = Random();

  int portadasCount = 0;
  bool introMostrada = false;
  int erroresRonda = 0;
  int intentosForzar = 0;
  bool puertaForzadaEnIntento = false;
  int _movimientosFrozen = 0;

  /// Habitaciones restantes hasta que el monstruo pueda
  /// volver a provocar un encuentro. 0 = puede aparecer.
  int _cooldownEncuentro = 0;

  List<int> posAct = [3, 0];
  List<int> posMonstruo = [0, 0];

  late List<List<Habitacion>> tablero;
  bool tableroIniciado = false;

  int get intentosForzarRestantes => maxIntentosForzar - intentosForzar;
  bool get monstruoCongelado => _movimientosFrozen > 0;

  /// Cuántas habitaciones quedan antes de que el monstruo
  /// pueda volver a aparecer (para mostrarlo en UI si se quiere).
  int get cooldownEncuentro => _cooldownEncuentro;

  int get probabilidadActualForzar {
    final valor = 25 - (erroresRonda * 5) + (intentosForzar * 20);
    if (valor < 0) return 0;
    if (valor > 100) return 100;
    return valor;
  }

  void iniciarTablero() {
    portadasCount++;
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;
    _movimientosFrozen = 0;
    _cooldownEncuentro = 0;

    tablero = List.generate(
      filas,
          (_) => List.generate(cols, (_) => Habitacion()),
    );

    _poblarTablero();
    _asignarFondos();
    tableroIniciado = true;
    notifyListeners();
  }

  void _asignarFondos() {
    final imagenes =
    List.generate(10, (i) => 'assets/images/Recorrido${i + 1}.png');

    for (int r = 0; r < filas; r++) {
      for (int c = 0; c < cols; c++) {
        if (r == 3 && c == 0) {
          tablero[r][c].fondo = 'assets/images/PortadaSinTexto.png';
          continue;
        }
        final usados = <String>{};
        if (r > 0) usados.add(tablero[r - 1][c].fondo);
        if (c > 0) usados.add(tablero[r][c - 1].fondo);
        final disponibles =
        imagenes.where((img) => !usados.contains(img)).toList()
          ..shuffle(_rng);
        tablero[r][c].fondo = disponibles.first;
      }
    }
  }

  void _poblarTablero() {
    for (int f = 0; f < filas; f++) {
      for (int c = 0; c < cols; c++) {
        tablero[f][c] = Habitacion(posDir: [], puertasBloqueadas: []);
      }
    }

    tablero[3][0] = Habitacion(posDir: [1, 2], explorada: true);
    tablero[2][0] = Habitacion(posDir: [1, 2, 4]);
    tablero[1][0] = Habitacion(posDir: [2]);

    tablero[2][1] = Habitacion(
      posDir: [3],
      puertasBloqueadas: [1, 4],
    );

    tablero[1][1] = Habitacion(posDir: [1, 2]);
    tablero[0][1] = Habitacion(posDir: [2, 4]);
    tablero[0][2] = Habitacion(posDir: [3, 4]);

    tablero[2][2] = Habitacion(posDir: [3, 2]);
    tablero[3][2] = Habitacion(posDir: [1, 4]);
    tablero[3][3] = Habitacion(posDir: [3, 1]);
    tablero[2][3] = Habitacion(posDir: [2, 1]);
    tablero[1][3] = Habitacion(posDir: [2, 1]);

    tablero[0][3] = Habitacion(posDir: []);
  }

  String clasificarDireccion(int direccion) {
    const deltas = {
      1: [-1, 0],
      2: [1, 0],
      3: [0, -1],
      4: [0, 1],
    };

    final d = deltas[direccion];
    if (d == null) return 'pared';

    final nFila = posAct[0] + d[0];
    final nCol = posAct[1] + d[1];

    if (nFila < 0 || nFila >= filas || nCol < 0 || nCol >= cols) {
      return 'pared';
    }

    final habitActual = tablero[posAct[0]][posAct[1]];

    if (habitActual.posDir.contains(direccion)) return 'abierta';

    if (!habitActual.puertasBloqueadas.contains(direccion)) {
      habitActual.puertasBloqueadas.add(direccion);
    }

    return 'puerta_bloqueada';
  }

  MovimientoResultado moverHacia(int direccion) {
    final tipo = clasificarDireccion(direccion);

    if (tipo == 'pared') {
      erroresRonda++;
      notifyListeners();
      return const MovimientoResultado(tipo: 'pared');
    }

    if (tipo == 'puerta_bloqueada') {
      return const MovimientoResultado(tipo: 'bloqueada');
    }

    return _completarMovimiento(direccion);
  }

  MovimientoResultado rechazarPuerta(int direccion) {
    final habitActual = tablero[posAct[0]][posAct[1]];

    if (!habitActual.puertasBloqueadas.contains(direccion)) {
      habitActual.puertasBloqueadas.add(direccion);
    }
    if (!habitActual.bloqsF.contains(direccion)) {
      habitActual.bloqsF.add(direccion);
    }

    erroresRonda++;
    _desbloquearRutaRescateSiHaceFalta();
    notifyListeners();

    return const MovimientoResultado(tipo: 'bloqueada');
  }

  MovimientoResultado intentarForzarPuerta(int direccion) {
    if (clasificarDireccion(direccion) != 'puerta_bloqueada') {
      return moverHacia(direccion);
    }

    final habitActual = tablero[posAct[0]][posAct[1]];

    if (intentosForzar >= maxIntentosForzar) {
      return rechazarPuerta(direccion);
    }

    final probabilidad = probabilidadActualForzar;
    intentosForzar++;

    final tirada = _rng.nextInt(100) + 1;
    final exito = tirada <= probabilidad;

    if (exito) {
      // ── Habitación actual ────────────────────────────
      habitActual.puertasBloqueadas.remove(direccion);
      habitActual.bloqsF.remove(direccion); // ← limpia el candado del mapa
      if (!habitActual.posDir.contains(direccion)) {
        habitActual.posDir.add(direccion);
      }

      // ── Habitación vecina (dirección opuesta) ────────
      const opuesta = {1: 2, 2: 1, 3: 4, 4: 3};
      const _deltas = {1: [-1, 0], 2: [1, 0], 3: [0, -1], 4: [0, 1]};
      final d = _deltas[direccion]!;
      final nFila = posAct[0] + d[0];
      final nCol  = posAct[1] + d[1];
      if (nFila >= 0 && nFila < filas && nCol >= 0 && nCol < cols) {
        final habitVecina  = tablero[nFila][nCol];
        final dirOpuesta   = opuesta[direccion]!;
        habitVecina.puertasBloqueadas.remove(dirOpuesta);
        habitVecina.bloqsF.remove(dirOpuesta);
        if (!habitVecina.posDir.contains(dirOpuesta)) {
          habitVecina.posDir.add(dirOpuesta);
        }
      }

      puertaForzadaEnIntento = true;

      return _completarMovimiento(
        direccion,
        puertaForzada: true,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    if (!habitActual.bloqsF.contains(direccion)) {
      habitActual.bloqsF.add(direccion);
    }

    erroresRonda++;
    _desbloquearRutaRescateSiHaceFalta();
    notifyListeners();

    return MovimientoResultado(
      tipo: 'bloqueada',
      probabilidad: probabilidad,
      tirada: tirada,
    );
  }

  MovimientoResultado _completarMovimiento(
      int direccion, {
        bool puertaForzada = false,
        int? probabilidad,
        int? tirada,
      }) {
    const deltas = {
      1: [-1, 0],
      2: [1, 0],
      3: [0, -1],
      4: [0, 1],
    };

    final d = deltas[direccion]!;
    final nFila = posAct[0] + d[0];
    final nCol = posAct[1] + d[1];

    posAct = [nFila, nCol];
    tablero[nFila][nCol].explorada = true;

    // Descontar cooldown de encuentro al cambiar de habitación
    if (_cooldownEncuentro > 0) {
      _cooldownEncuentro--;
    }

    // Movimiento 1: el jugador entra a la sala
    _moverMonstruo();

    final encuentro = _cooldownEncuentro == 0 &&
        posAct[0] == posMonstruo[0] &&
        posAct[1] == posMonstruo[1];

    final cerca = _esAdyacente(posAct, posMonstruo);

    notifyListeners();

    if (encuentro) {
      return MovimientoResultado(
        tipo: 'encuentro_monstruo',
        encuentroMonstruo: true,
        puertaForzada: puertaForzada,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    if (nFila == 0 && nCol == 3) {
      return MovimientoResultado(
        tipo: 'salida',
        puertaForzada: puertaForzada,
        probabilidad: probabilidad,
        tirada: tirada,
      );
    }

    return MovimientoResultado(
      tipo: 'avanzar',
      monstruoCerca: cerca,
      puertaForzada: puertaForzada,
      probabilidad: probabilidad,
      tirada: tirada,
    );
  }

  // Movimiento 2: el jugador decide dirección
  EstadoMonstruo moverMonstruoDecision() {
    _moverMonstruo();
    notifyListeners();

    // Solo encuentro si el cooldown ya ha llegado a 0
    if (_cooldownEncuentro == 0 &&
        posAct[0] == posMonstruo[0] &&
        posAct[1] == posMonstruo[1]) {
      return EstadoMonstruo.encuentro;
    }

    if (_esAdyacente(posAct, posMonstruo)) {
      return EstadoMonstruo.cerca;
    }

    return EstadoMonstruo.normal;
  }

  void _moverMonstruo() {
    if (_movimientosFrozen > 0) {
      _movimientosFrozen--;
      return;
    }

    const deltas = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    final movimientosValidos = <List<int>>[];

    for (final delta in deltas) {
      final nf = posMonstruo[0] + delta[0];
      final nc = posMonstruo[1] + delta[1];
      if (nf >= 0 && nf < filas && nc >= 0 && nc < cols) {
        movimientosValidos.add([nf, nc]);
      }
    }

    if (movimientosValidos.isEmpty) return;

    movimientosValidos.sort((a, b) {
      final da = _distancia(a, posAct);
      final db = _distancia(b, posAct);
      return da.compareTo(db);
    });

    if (_rng.nextDouble() < 0.8) {
      posMonstruo = movimientosValidos.first;
    } else {
      posMonstruo =
      movimientosValidos[_rng.nextInt(movimientosValidos.length)];
    }
  }

  int _distancia(List<int> a, List<int> b) {
    return (a[0] - b[0]).abs() + (a[1] - b[1]).abs();
  }

  bool _esAdyacente(List<int> a, List<int> b) {
    return _distancia(a, b) == 1;
  }

  /// Congela el monstruo 3 turnos e impone cooldown de encuentro
  /// de 3 cambios de habitación.
  void ahuyentarMonstruo() {
    _movimientosFrozen = _movsFrozenTotal;
    _cooldownEncuentro = _cooldownEncuentroInicial;
    notifyListeners();
  }

  void _desbloquearRutaRescateSiHaceFalta() {
    if (intentosForzar < maxIntentosForzar) return;
    if (puertaForzadaEnIntento) return;

    final habitCambio = tablero[2][1];
    final direccionRescate = portadasCount.isOdd ? 4 : 1;

    habitCambio.puertasBloqueadas.remove(direccionRescate);
    if (!habitCambio.posDir.contains(direccionRescate)) {
      habitCambio.posDir.add(direccionRescate);
    }
  }

  void resetRecorrido() {
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;
    _movimientosFrozen = 0;
    _cooldownEncuentro = 0;
    notifyListeners();
  }

  void resetJuego() {
    posAct = [3, 0];
    posMonstruo = [0, 0];
    erroresRonda = 0;
    intentosForzar = 0;
    puertaForzadaEnIntento = false;
    _movimientosFrozen = 0;
    _cooldownEncuentro = 0;
    tableroIniciado = false;
    introMostrada = false;
    notifyListeners();
  }

  String get posActTexto => '(${posAct[0] + 1}, ${posAct[1] + 1})';
  bool get enSalidaCamara => posAct[0] == 1 && posAct[1] == 0;
}