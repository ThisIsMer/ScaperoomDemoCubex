class Habitacion {
  bool explorada;
  final List<int> posDir;
  final List<int> puertasBloqueadas;
  final List<int> bloqsF;
  String fondo;

  Habitacion({
    this.explorada = false,
    List<int>? posDir,
    List<int>? puertasBloqueadas,
    List<int>? bloqsF,
    this.fondo = '',
  })  : posDir = posDir ?? [],
        puertasBloqueadas = puertasBloqueadas ?? [],
        bloqsF = bloqsF ?? [];
}