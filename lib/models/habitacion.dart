class Habitacion {
  bool explorada;
  final List<int> posDir;
  final List<int> bloqsF;
  String fondo; // ← imagen de fondo asignada al inicio

  Habitacion({
    this.explorada = false,
    List<int>? posDir,
    List<int>? bloqsF,
    this.fondo = '',
  })  : posDir = posDir ?? [],
        bloqsF = bloqsF ?? [];
}