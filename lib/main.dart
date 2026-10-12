import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const EscapeApp());
}

class EscapeApp extends StatelessWidget {
  const EscapeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Escape del Laboratorio',
        theme: ThemeData.dark(useMaterial3: true),
        home: const GameScreen(),
      );
}

enum GameMode { menu, playing, gameOver, won, levelIntro }

class LevelTheme {
  final String name;
  final Color sky;
  final Color wall;
  final Color accent;
  final String subtitle;
  const LevelTheme(this.name, this.sky, this.wall, this.accent, this.subtitle);
}

const levelThemes = <LevelTheme>[
  LevelTheme('Laboratorio principal', Color(0xFF142B35), Color(0xFF35535B), Color(0xFF62D6BA), 'Encuentra la tarjeta de acceso.'),
  LevelTheme('Pasillo contaminado', Color(0xFF30202A), Color(0xFF593744), Color(0xFFE46C65), 'Las alarmas atrajeron más infectados.'),
  LevelTheme('Invernadero mutante', Color(0xFF18372A), Color(0xFF315C43), Color(0xFF9DD96C), 'Las plantas mutantes bloquean el camino.'),
  LevelTheme('Almacén de suministros', Color(0xFF342A1B), Color(0xFF635037), Color(0xFFFFC45C), 'Salta entre cajas y busca la llave.'),
  LevelTheme('Zona de cuarentena', Color(0xFF252A3F), Color(0xFF414C70), Color(0xFF8FAEFF), 'No te quedes atrapado entre las barreras.'),
  LevelTheme('Túneles de servicio', Color(0xFF1C2E32), Color(0xFF3D595D), Color(0xFF63D5D0), 'Los túneles son estrechos y oscuros.'),
  LevelTheme('Laboratorio criogénico', Color(0xFF1A3448), Color(0xFF416B82), Color(0xFF9DEBFF), 'El suelo helado hace difícil detenerse.'),
  LevelTheme('Sector de mutación', Color(0xFF351E38), Color(0xFF62376A), Color(0xFFE99BFF), 'Los especímenes mutados son más rápidos.'),
  LevelTheme('Núcleo de investigación', Color(0xFF35251D), Color(0xFF67483A), Color(0xFFFF9D68), 'Cruza el núcleo y consigue la tarjeta final.'),
  LevelTheme('Salida de emergencia', Color(0xFF172D27), Color(0xFF355B4A), Color(0xFF78F0A5), '¡Último tramo! Llega a la salida exterior.'),
];

class PlatformRect {
  double x, y, w, h;
  PlatformRect(this.x, this.y, this.w, this.h);
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

class Enemy {
  double x, y, speed, minX, maxX;
  bool right;
  Enemy(this.x, this.y, this.speed, this.minX, this.maxX, this.right);
  Rect get rect => Rect.fromLTWH(x, y, 30, 36);
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double worldW = 900, worldH = 500;
  Timer? timer;
  GameMode mode = GameMode.menu;
  int level = 0, lives = 3, score = 0, keysCollected = 0;
  double px = 35, py = 400, vx = 0, vy = 0;
  bool onGround = false, hasKey = false;
  bool leftHeld = false, rightHeld = false;
  double invulnerable = 0;
  int elapsedTicks = 0;
  late List<PlatformRect> platforms;
  late List<Enemy> enemies;
  late Rect keyRect, doorRect;
  final FocusNode focusNode = FocusNode();

  LevelTheme get theme => levelThemes[level];
  int get levelNumber => level + 1;

  @override
  void initState() {
    super.initState();
    _buildLevel();
    timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  @override
  void dispose() {
    timer?.cancel();
    focusNode.dispose();
    super.dispose();
  }

  void _buildLevel() {
    px = 35; py = 400; vx = 0; vy = 0; onGround = false;
    hasKey = false; invulnerable = 0;
    platforms = [
      PlatformRect(0, 452, 900, 48),
      PlatformRect(105, 375, 120, 16),
      PlatformRect(280, 310, 125, 16),
      PlatformRect(465, 365, 130, 16),
      PlatformRect(665, 295, 130, 16),
    ];
    if (level >= 2) platforms.add(PlatformRect(55, 275, 95, 16));
    if (level >= 3) platforms.add(PlatformRect(390, 220, 120, 16));
    if (level >= 4) platforms.add(PlatformRect(565, 235, 85, 16));
    if (level >= 6) platforms.add(PlatformRect(205, 220, 90, 16));
    if (level >= 8) platforms.add(PlatformRect(735, 205, 90, 16));

    final count = 2 + (level ~/ 2);
    final baseSpeed = 1.15 + level * 0.16;
    final starts = <double>[220, 370, 560, 125, 700, 450, 300];
    enemies = List.generate(math.min(count, 7), (i) {
      final x = starts[i];
      return Enemy(x, 416, baseSpeed + i * .09,
          math.max(4, x - 55 - level * 3), math.min(850, x + 60 + level * 3), i.isEven);
    });
    keyRect = Rect.fromLTWH(level.isEven ? 700 : 330, level >= 5 ? 180 : 270, 24, 26);
    doorRect = const Rect.fromLTWH(842, 380, 38, 72);
  }

  void _startGame() {
    setState(() {
      if (mode == GameMode.menu || mode == GameMode.gameOver || mode == GameMode.won) {
        level = 0; lives = 3; score = 0; keysCollected = 0; _buildLevel();
      }
      mode = GameMode.playing;
    });
  }

  void _jump() {
    if (mode == GameMode.playing && onGround) {
      vy = -11.8;
      onGround = false;
    }
  }

  void _loseLife() {
    if (invulnerable > 0 || mode != GameMode.playing) return;
    lives--;
    invulnerable = 95;
    px = 35; py = 400; vx = 0; vy = 0;
    if (lives <= 0) mode = GameMode.gameOver;
  }

  bool _overlap(Rect a, Rect b) => a.overlaps(b);

  void _tick() {
    if (!mounted || mode != GameMode.playing) return;
    setState(() {
      elapsedTicks++;
      final speed = 3.5 + level * .12;
      vx = (rightHeld ? speed : 0) - (leftHeld ? speed : 0);
      final oldBottom = py + 38;
      px = (px + vx).clamp(0, worldW - 30).toDouble();
      vy = math.min(12, vy + .52);
      py += vy;
      onGround = false;
      final playerRect = Rect.fromLTWH(px, py, 28, 38);
      for (final p in platforms) {
        if (playerRect.right > p.x &&
            playerRect.left < p.x + p.w &&
            oldBottom <= p.y + 7 &&
            py + 38 >= p.y &&
            vy >= 0) {
          py = p.y - 38;
          vy = 0;
          onGround = true;
        }
      }
      if (py > worldH) _loseLife();

      for (final e in enemies) {
        e.x += e.right ? e.speed : -e.speed;
        if (e.x <= e.minX) { e.x = e.minX; e.right = true; }
        if (e.x >= e.maxX) { e.x = e.maxX; e.right = false; }
        if (_overlap(Rect.fromLTWH(px, py, 28, 38), e.rect)) _loseLife();
      }
      if (!hasKey && _overlap(Rect.fromLTWH(px, py, 28, 38), keyRect)) {
        hasKey = true; keysCollected++; score += 100;
      }
      if (hasKey && _overlap(Rect.fromLTWH(px, py, 28, 38), doorRect)) {
        score += 250;
        if (level == levelThemes.length - 1) {
          mode = GameMode.won;
        } else {
          level++;
          _buildLevel();
          mode = GameMode.levelIntro;
        }
      }
      if (invulnerable > 0) invulnerable--;
    });
  }

  void _continueLevel() {
    setState(() => mode = GameMode.playing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1117),
      body: SafeArea(
        child: Focus(
          focusNode: focusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) leftHeld = true;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) rightHeld = true;
              if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp) _jump();
            } else if (event is KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.keyA) leftHeld = false;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.keyD) rightHeld = false;
            }
            return KeyEventResult.handled;
          },
          child: Column(
            children: [
              _buildHud(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final ratio = worldW / worldH;
                    double width = constraints.maxWidth;
                    double height = width / ratio;
                    if (height > constraints.maxHeight) { height = constraints.maxHeight; width = height * ratio; }
                    return Center(
                      child: SizedBox(
                        width: width, height: height,
                        child: Stack(children: [
                          CustomPaint(size: Size(width, height), painter: GamePainter(
                            level: level, playerX: px, playerY: py, platforms: platforms,
                            enemies: enemies, keyRect: keyRect, doorRect: doorRect,
                            hasKey: hasKey, theme: theme, invulnerable: invulnerable,
                          )),
                          if (mode != GameMode.playing) _buildOverlay(),
                        ]),
                      ),
                    );
                  }),
                ),
              ),
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    color: const Color(0xFF14212A),
    child: Row(children: [
      const Icon(Icons.science, color: Color(0xFF78E0BD), size: 22),
      const SizedBox(width: 6),
      const Flexible(child: Text('ESCAPE DEL LABORATORIO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 12),
      Text('NIVEL ${level + 1}/10', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
      const SizedBox(width: 10),
      Text('❤️ $lives', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(width: 10),
      Text('⭐ $score', style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildControls() => Container(
    padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _holdButton(Icons.arrow_left, 'IZQUIERDA', (v) => leftHeld = v),
      const SizedBox(width: 10),
      _actionButton(Icons.arrow_upward, 'SALTAR', _jump),
      const SizedBox(width: 10),
      _holdButton(Icons.arrow_right, 'DERECHA', (v) => rightHeld = v),
    ]),
  );

  Widget _holdButton(IconData icon, String label, ValueChanged<bool> change) =>
      GestureDetector(
        onTapDown: (_) => setState(() => change(true)),
        onTapUp: (_) => setState(() => change(false)),
        onTapCancel: () => setState(() => change(false)),
        child: Container(
          width: 105, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF253A45), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF5D7885))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 24), const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _actionButton(IconData icon, String label, VoidCallback action) =>
      GestureDetector(
        onTap: action,
        child: Container(
          width: 105, height: 48,
          decoration: BoxDecoration(color: const Color(0xFF285445), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF70B99D))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22), const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _buildOverlay() {
    String title, description, button;
    VoidCallback action;
    switch (mode) {
      case GameMode.menu:
        title = 'Escape del Laboratorio';
        description = 'Diez sectores distintos, zombis, llaves y plataformas. Sobrevive y encuentra la salida.';
        button = 'COMENZAR';
        action = _startGame;
        break;
      case GameMode.gameOver:
        title = 'GAME OVER';
        description = 'Te atraparon los infectados. Puntuación: $score. Inténtalo otra vez.';
        button = 'REINTENTAR';
        action = _startGame;
        break;
      case GameMode.won:
        title = '¡ESCAPASTE!';
        description = 'Completaste los diez niveles. Puntuación final: $score.';
        button = 'JUGAR OTRA VEZ';
        action = _startGame;
        break;
      case GameMode.levelIntro:
        title = 'NIVEL ${level + 1}: ${theme.name}';
        description = theme.subtitle;
        button = 'CONTINUAR';
        action = _continueLevel;
        break;
      case GameMode.playing:
        title = ''; description = ''; button = ''; action = () {};
        break;
    }
    return Container(
      color: Colors.black.withOpacity(.76),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF182832), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.accent, width: 1.5)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(mode == GameMode.won ? Icons.emoji_events : mode == GameMode.gameOver ? Icons.warning_rounded : Icons.biotech, color: theme.accent, size: 34),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD0DDE2), fontSize: 12)),
          const SizedBox(height: 12),
          FilledButton(onPressed: action, child: Text(button)),
        ]),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final int level;
  final double playerX, playerY, invulnerable;
  final List<PlatformRect> platforms;
  final List<Enemy> enemies;
  final Rect keyRect, doorRect;
  final bool hasKey;
  final LevelTheme theme;
  GamePainter({required this.level, required this.playerX, required this.playerY, required this.platforms, required this.enemies, required this.keyRect, required this.doorRect, required this.hasKey, required this.theme, required this.invulnerable});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 900, sy = size.height / 500;
    canvas.save(); canvas.scale(sx, sy);
    final bg = Paint()..shader = LinearGradient(colors: [theme.sky, theme.wall], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(const Rect.fromLTWH(0, 0, 900, 500));
    canvas.drawRect(const Rect.fromLTWH(0, 0, 900, 500), bg);
    final line = Paint()..color = Colors.white.withOpacity(.055)..strokeWidth = 1;
    for (int x=0;x<900;x+=45) canvas.drawLine(Offset(x.toDouble(),0),Offset(x.toDouble(),500),line);
    for (int y=0;y<500;y+=45) canvas.drawLine(Offset(0,y.toDouble()),Offset(900,y.toDouble()),line);
    _drawThemeDecor(canvas);
    for (final p in platforms) {
      canvas.drawRRect(RRect.fromRectAndRadius(p.rect, const Radius.circular(4)), Paint()..color = const Color(0xFF24363B));
      canvas.drawRect(Rect.fromLTWH(p.x,p.y,p.w,4), Paint()..color=theme.accent);
      for(double x=p.x+10;x<p.x+p.w-5;x+=22) canvas.drawLine(Offset(x,p.y+6),Offset(x,p.y+p.h-2),Paint()..color=Colors.white.withOpacity(.08));
    }
    _drawDoor(canvas);
    if (!hasKey) _drawKey(canvas, keyRect.center);
    for (final e in enemies) _drawZombie(canvas, e.x, e.y);
    _drawPlayer(canvas, playerX, playerY, invulnerable);
    final textPainter = TextPainter(text: TextSpan(text: 'SECTOR ${level+1}  •  ${theme.name.toUpperCase()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)), textDirection: TextDirection.ltr)..layout(maxWidth: 600);
    textPainter.paint(canvas, const Offset(20, 17));
    final hint = TextPainter(text: TextSpan(text: hasKey ? 'TARJETA OBTENIDA · LLEGA A LA SALIDA' : 'BUSCA LA LLAVE / TARJETA DE ACCESO', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold, fontSize: 11)), textDirection: TextDirection.ltr)..layout(maxWidth: 600);
    hint.paint(canvas, const Offset(20, 38));
    canvas.restore();
  }

  void _drawThemeDecor(Canvas c) {
    final a = Paint()..color = theme.accent.withOpacity(.22);
    switch (level) {
      case 0:
        for(int i=0;i<4;i++){c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(50+i*180,80,100,45),const Radius.circular(5)),a);c.drawRect(Rect.fromLTWH(60+i*180,90,80,25),Paint()..color=theme.accent.withOpacity(.12));}
        break;
      case 1:
        for(int i=0;i<6;i++){c.drawRect(Rect.fromLTWH(40+i*145,70,18,110),Paint()..color=const Color(0xFFDA6262).withOpacity(.35));}
        c.drawCircle(const Offset(780,90),36,Paint()..color=Colors.red.withOpacity(.16));
        break;
      case 2:
        for(int i=0;i<8;i++){final x=30.0+i*115;c.drawLine(Offset(x,120),Offset(x+18,70),Paint()..color=theme.accent..strokeWidth=4);c.drawCircle(Offset(x+18,70),11,a);c.drawCircle(Offset(x-6,133),8,a);}
        break;
      case 3:
        for(int i=0;i<5;i++){final x=35.0+i*165;c.drawRect(Rect.fromLTWH(x,270,65,65),Paint()..color=const Color(0xFF987047));c.drawLine(Offset(x,285),Offset(x+65,285),Paint()..color=const Color(0xFFFFD28B)..strokeWidth=3);c.drawLine(Offset(x+32,270),Offset(x+32,335),Paint()..color=const Color(0xFFFFD28B)..strokeWidth=2);}
        break;
      case 4:
        for(int i=0;i<6;i++){final x=50.0+i*140;c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,80,70,120),const Radius.circular(30)),a);c.drawLine(Offset(x+35,80),Offset(x+35,200),Paint()..color=theme.accent.withOpacity(.3)..strokeWidth=2);}
        break;
      case 5:
        for(int i=0;i<6;i++){final x=40.0+i*150;c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,90,85,75),const Radius.circular(18)),a);c.drawCircle(Offset(x+42,128),15,Paint()..color=theme.sky);}
        break;
      case 6:
        for(int i=0;i<5;i++){final x=55.0+i*170;c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,75,75,120),const Radius.circular(28)),Paint()..color=const Color(0xFFB5F0FF).withOpacity(.12)..style=PaintingStyle.fill);c.drawLine(Offset(x+15,95),Offset(x+60,95),Paint()..color=theme.accent..strokeWidth=3);}
        break;
      case 7:
        for(int i=0;i<5;i++){final x=70.0+i*170;c.drawCircle(Offset(x,125),25,a);c.drawCircle(Offset(x,125),12,Paint()..color=theme.accent.withOpacity(.25));}
        break;
      case 8:
        for(int i=0;i<5;i++){final x=35.0+i*175;c.drawRect(Rect.fromLTWH(x,80,110,85),Paint()..color=const Color(0xFF8E6551).withOpacity(.25));c.drawLine(Offset(x,80),Offset(x+110,165),Paint()..color=theme.accent.withOpacity(.4)..strokeWidth=3);c.drawLine(Offset(x+110,80),Offset(x,165),Paint()..color=theme.accent.withOpacity(.4)..strokeWidth=3);}
        break;
      case 9:
        for(int i=0;i<8;i++){final x=30.0+i*115;c.drawRect(Rect.fromLTWH(x,75,70,8),Paint()..color=theme.accent.withOpacity(.6));c.drawRect(Rect.fromLTWH(x,88,70,4),Paint()..color=Colors.white.withOpacity(.25));}
        break;
    }
  }

  void _drawDoor(Canvas c) {
    c.drawRRect(RRect.fromRectAndRadius(doorRect.inflate(5), const Radius.circular(5)), Paint()..color=Colors.black.withOpacity(.35));
    c.drawRRect(RRect.fromRectAndRadius(doorRect, const Radius.circular(4)), Paint()..color=hasKey?const Color(0xFF3AD18C):const Color(0xFF82949A));
    c.drawRect(Rect.fromLTWH(doorRect.left+7,doorRect.top+8,doorRect.width-14,doorRect.height-8),Paint()..color=const Color(0xFF20333A));
    c.drawCircle(Offset(doorRect.right-10,doorRect.center.dy),3,Paint()..color=theme.accent);
  }
  void _drawKey(Canvas c, Offset p) {
    final gold=Paint()..color=const Color(0xFFFFD65A)..strokeWidth=5..style=PaintingStyle.stroke;
    c.drawCircle(Offset(p.dx-4,p.dy-4),8,gold);
    c.drawLine(Offset(p.dx+4,p.dy+2),Offset(p.dx+19,p.dy+17),gold);
    c.drawLine(Offset(p.dx+12,p.dy+10),Offset(p.dx+18,p.dy+4),gold);
    c.drawLine(Offset(p.dx+16,p.dy+14),Offset(p.dx+22,p.dy+8),gold);
  }
  void _drawZombie(Canvas c,double x,double y) {
    final green=Paint()..color=const Color(0xFF75B66B), dark=Paint()..color=const Color(0xFF253C32), red=Paint()..color=const Color(0xFFFF5D64);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+4,y+13,23,22),const Radius.circular(5)),dark);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+3,y+1,24,21),const Radius.circular(8)),green);
    c.drawCircle(Offset(x+10,y+10),3,red);c.drawCircle(Offset(x+20,y+10),3,red);
    c.drawLine(Offset(x+7,y+35),Offset(x+4,y+39),Paint()..color=green..strokeWidth=5);
    c.drawLine(Offset(x+23,y+35),Offset(x+26,y+39),Paint()..color=green..strokeWidth=5);
    c.drawLine(Offset(x+3,y+19),Offset(x-2,y+27),Paint()..color=green..strokeWidth=4);
    c.drawLine(Offset(x+27,y+19),Offset(x+33,y+25),Paint()..color=green..strokeWidth=4);
  }
  void _drawPlayer(Canvas c,double x,double y,double inv) {
    if(inv>0 && inv.toInt()%8<4)return;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+4,y+13,21,22),const Radius.circular(4)),Paint()..color=const Color(0xFF4DA9D7));
    c.drawCircle(Offset(x+14,y+8),9,Paint()..color=const Color(0xFFFFD2A3));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+3,y,23,7),const Radius.circular(3)),Paint()..color=const Color(0xFFE9F2F3));
    c.drawLine(Offset(x+8,y+34),Offset(x+6,y+38),Paint()..color=const Color(0xFF253D55)..strokeWidth=5);
    c.drawLine(Offset(x+21,y+34),Offset(x+24,y+38),Paint()..color=const Color(0xFF253D55)..strokeWidth=5);
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
