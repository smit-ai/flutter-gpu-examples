import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vec;

ByteData float32(List<double> values) {
  return Float32List.fromList(values).buffer.asByteData();
}

ByteData float32Mat(vec.Matrix4 matrix) {
  return Float32List.fromList(matrix.storage).buffer.asByteData();
}

ByteData uint16(List<int> values) {
  return Uint16List.fromList(values).buffer.asByteData();
}

ByteData uint32(List<int> values) {
  return Uint32List.fromList(values).buffer.asByteData();
}

const String _kShaderBundlePath =
    'build/shaderbundles/TestLibrary.shaderbundle';
gpu.ShaderLibrary? _shaderLibrary;
gpu.ShaderLibrary get shaderLibrary {
  if (_shaderLibrary != null) return _shaderLibrary!;
  _shaderLibrary = gpu.ShaderLibrary.fromAsset(_kShaderBundlePath);
  if (_shaderLibrary != null) return _shaderLibrary!;
  throw Exception("Failed to load shader bundle! ($_kShaderBundlePath)");
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  int widgetIndex = 0;
  @override
  Widget build(BuildContext context) {
    final widgets = [
      const GameDemoPage(),
      const PhysicsDemoPage(),
      const TetrisPhysicsPage(),
      const RigidSoftBodyPhysicsPage(),
      const SDFPhysicsPage(),
      const FlexWorldGamePage(),
      const ColorsPage(),
      const TextureCubePage(),
      const TrianglePage(),
      const JuliaSetPage(),
    ];
    final widgetsNames = <String>[
      'Game Demo - CPU Loop - WASD TO Move - Click To Shoot!',
      'PhysicsDemoPage()',
      'TetrisPhysicsPage()',
      'RigidSoftBodyPhysicsPage()',
      'SDFPhysicsPage() - Ray Marched Metaballs with Rigid/Soft Body Toggle',
      'FlexWorldGamePage() - FlexWorld - A 3D Indie Game Inspired By Fez With Real Time 2D/2.5D To 3D & Physics Toggle)',
      'ColorsPage() - vert/uniform example',
      'TextureCubePage() - vert/indices/uniform/texture/depth example',
      'TrianglePage() - vert/uniform example',
      'JuliaSetPage() - Texture example',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AnimatedOpacity(
              opacity: widgetIndex > 0 ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: IconButton(
                onPressed: () =>
                    setState(() => widgetIndex = max(0, widgetIndex - 1)),
                icon: const Icon(Icons.arrow_back_ios),
              ),
            ),
            Expanded(
              child: Text(
                'GPU demo ${widgetsNames[widgetIndex]}',
                textAlign: TextAlign.center,
              ),
            ),
            AnimatedOpacity(
              opacity: widgetIndex < widgets.length - 1 ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: IconButton(
                onPressed: () => setState(
                  () => widgetIndex = min(widgets.length - 1, widgetIndex + 1),
                ),
                icon: const Icon(Icons.arrow_forward_ios),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Expanded(child: widgets[widgetIndex])],
      ),
    );
  }
}

class ColorsPainter extends CustomPainter {
  ColorsPainter(this.red, this.green, this.blue);
  double red, green, blue;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      300,
      300,
    );
    final vertex = shaderLibrary['ColorsVertex']!;
    final fragment = shaderLibrary['ColorsFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    final gpu.DeviceBuffer vertexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      4 * 6 * 3,
    );
    vertexBuffer.overwrite(
      Float32List.fromList(<double>[
        -0.5,
        -0.5,
        1.0 * red,
        0.0,
        0.0,
        1.0,
        0,
        0.5,
        0.0,
        1.0 * green,
        0.0,
        1.0,
        0.5,
        -0.5,
        0.0,
        0.0,
        1.0 * blue,
        1.0,
      ]).buffer.asByteData(),
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: texture),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    pass.bindPipeline(pipeline);
    pass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
      3,
    );
    pass.draw();
    commandBuffer.submit();
    final image = texture.asImage();
    canvas.drawImage(image, Offset(-texture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ColorsPage extends StatefulWidget {
  const ColorsPage({super.key});
  @override
  State<ColorsPage> createState() => _ColorsPageState();
}

class _ColorsPageState extends State<ColorsPage> {
  Ticker? tick;
  double time = 0, red = 1.0, green = 1.0, blue = 1.0;
  @override
  void initState() {
    super.initState();
    tick = Ticker(
      (elapsed) => setState(() => time = elapsed.inMilliseconds / 1000.0),
    );
    tick!.start();
  }

  @override
  void dispose() {
    tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Slider(
          value: red,
          max: 1,
          min: 0,
          onChanged: (value) => {setState(() => red = value)},
        ),
        Slider(
          value: green,
          max: 1,
          min: 0,
          onChanged: (value) => {setState(() => green = value)},
        ),
        Slider(
          value: blue,
          max: 1,
          min: 0,
          onChanged: (value) => {setState(() => blue = value)},
        ),
        CustomPaint(painter: ColorsPainter(red, green, blue)),
      ],
    );
  }
}

class JuliaSetPainter extends CustomPainter {
  JuliaSetPainter(this.time, this.seedX, this.seedY);
  double time, seedX, seedY;
  final maxIterations = 100, escapeDistance = 10;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture texture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      21,
      9,
    );
    if (seedX > 0.0) {
      texture.overwrite(
        Uint32List.fromList(
          List<int>.generate(texture.width * texture.height, (int index) {
            int onColor = seedY < 0
                ? (0xFF * seedY).toInt() | 0x00FFFF00
                : (0xFF * -seedY).toInt() << 8 | 0x00FF00FF;
            return index.isEven
                ? (time.toInt().isEven ? onColor : 0xFF000000)
                : (time.toInt().isEven ? 0xFF000000 : onColor);
          }, growable: false),
        ).buffer.asByteData(),
      );
    } else {
      var buffer = Int32List(texture.width * texture.height);
      for (int i = 0; i < buffer.length; i++) {
        int xi = i % texture.width, yi = i ~/ texture.width;
        double x = (xi.toDouble() - texture.width / 2) / (texture.width * 0.75),
            y = (yi.toDouble() - texture.height / 2) / (texture.height * 0.75);
        int iterations = 0;
        for (int it = 0; it < maxIterations; it++) {
          double newX = x * x - y * y + seedX;
          y = 2 * x * y + seedY;
          x = newX;
          if (x * x + y * y > escapeDistance * escapeDistance) {
            iterations = it;
            break;
          }
        }
        int shade = (iterations / maxIterations * 0xFF).toInt();
        buffer[i] = Color.fromARGB(
          0xFF,
          (shade * time).toInt(),
          (seedX * time).toInt(),
          (seedY * time).toInt(),
        ).toARGB32();
      }
      texture.overwrite(buffer.buffer.asByteData());
    }
    final ui.Image image = texture.asImage();
    canvas.scale(50);
    canvas.drawImage(image, Offset(-texture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class JuliaSetPage extends StatefulWidget {
  const JuliaSetPage({super.key});
  @override
  State<JuliaSetPage> createState() => _JuliaSetPageState();
}

class _JuliaSetPageState extends State<JuliaSetPage> {
  Ticker? tick;
  double time = 0, seedX = -0.512511498387847167, seedY = 0.521295573094847167;
  @override
  void initState() {
    super.initState();
    tick = Ticker(
      (elapsed) => setState(() => time = elapsed.inMilliseconds / 1000.0),
    );
    tick!.start();
  }

  @override
  void dispose() {
    tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Slider(
          value: seedX,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedX = value)},
        ),
        Slider(
          value: seedY,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedY = value)},
        ),
        CustomPaint(painter: JuliaSetPainter(time, seedX, seedY)),
      ],
    );
  }
}

class TextureCubePainter extends CustomPainter {
  TextureCubePainter(
    this.time,
    this.seedX,
    this.seedY,
    this.scale,
    this.depthClearValue,
  );
  double time, seedX, seedY, scale, depthClearValue;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      300,
      300,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      300,
      300,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: renderTexture),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: depthClearValue,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final vertex = shaderLibrary['TextureVertex']!;
    final fragment = shaderLibrary['TextureFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    pass.bindPipeline(pipeline);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    pass.setColorBlendEnable(true);
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.one,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      ),
    );
    final transients = gpu.gpuContext.createHostBuffer();
    final vertices = transients.emplace(
      float32(<double>[
        -1,
        -1,
        -1,
        0,
        0,
        1,
        0,
        0,
        1,
        1,
        -1,
        -1,
        1,
        0,
        0,
        1,
        0,
        1,
        1,
        1,
        -1,
        1,
        1,
        0,
        0,
        1,
        1,
        -1,
        1,
        -1,
        0,
        1,
        0,
        0,
        0,
        1,
        -1,
        -1,
        1,
        0,
        0,
        0,
        1,
        1,
        1,
        1,
        -1,
        1,
        1,
        0,
        1,
        0,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        0,
        1,
        -1,
        1,
        1,
        0,
        1,
        1,
        1,
        1,
        1,
      ]),
    );
    final indices = transients.emplace(
      uint16(<int>[
        0,
        1,
        3,
        3,
        1,
        2,
        1,
        5,
        2,
        2,
        5,
        6,
        5,
        4,
        6,
        6,
        4,
        7,
        4,
        0,
        7,
        7,
        0,
        3,
        3,
        2,
        7,
        7,
        2,
        6,
        4,
        5,
        0,
        0,
        5,
        1,
      ]),
    );
    final mvp = transients.emplace(
      float32Mat(
        vec.Matrix4(0.5, 0, 0, 0, 0, 0.5, 0, 0, 0, 0, 0.2, 0, 0, 0, 0.5, 1) *
            vec.Matrix4.rotationX(time) *
            vec.Matrix4.rotationY(time * seedX) *
            vec.Matrix4.rotationZ(time * seedY) *
            vec.Matrix4.diagonal3(vec.Vector3(scale, scale, scale)),
      ),
    );
    pass.bindVertexBuffer(vertices, 8);
    pass.bindIndexBuffer(indices, gpu.IndexType.int16, 36);
    final frameInfoSlot = vertex.getUniformSlot('FrameInfo');
    pass.bindUniform(frameInfoSlot, mvp);
    final sampledTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      5,
      5,
      enableShaderReadUsage: true,
    );
    sampledTexture.overwrite(
      uint32(<int>[
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
        0x00000000,
        0xFFFFFFFF,
      ]),
    );
    final texSlot = pipeline.fragmentShader.getUniformSlot('tex');
    pass.bindTexture(texSlot, sampledTexture);
    pass.draw();
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset(-renderTexture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TextureCubePage extends StatefulWidget {
  const TextureCubePage({super.key});
  @override
  State<TextureCubePage> createState() => _TextureCubePageState();
}

class _TextureCubePageState extends State<TextureCubePage> {
  Ticker? tick;
  double time = 0,
      seedX = -0.512511498387847167,
      seedY = 0.521295573094847167,
      scale = 1.0,
      depthClearValue = 1.0;
  @override
  void initState() {
    super.initState();
    tick = Ticker(
      (elapsed) => setState(() => time = elapsed.inMilliseconds / 1000.0),
    );
    tick!.start();
  }

  @override
  void dispose() {
    tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Slider(
          value: seedX,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedX = value)},
        ),
        Slider(
          value: seedY,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedY = value)},
        ),
        Slider(
          value: scale,
          max: 3,
          min: 0.1,
          onChanged: (value) => {setState(() => scale = value)},
        ),
        Slider(
          value: depthClearValue,
          max: 1,
          min: 0,
          onChanged: (value) => {setState(() => depthClearValue = value)},
        ),
        CustomPaint(
          painter: TextureCubePainter(
            time,
            seedX,
            seedY,
            scale,
            depthClearValue,
          ),
        ),
      ],
    );
  }
}

class TrianglePainter extends CustomPainter {
  TrianglePainter(this.time, this.seedX, this.seedY);
  double time, seedX, seedY;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      300,
      300,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      300,
      300,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: renderTexture),
      depthStencilAttachment: gpu.DepthStencilAttachment(texture: depthTexture),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final vertex = shaderLibrary['UnlitVertex']!;
    final fragment = shaderLibrary['UnlitFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    pass.bindPipeline(pipeline);
    pass.setColorBlendEnable(true);
    pass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.one,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
      ),
    );
    final transients = gpu.gpuContext.createHostBuffer();
    final vertices = transients.emplace(
      float32(<double>[-0.5, -0.5, 0, 0.5, 0.5, -0.5]),
    );
    pass.bindVertexBuffer(vertices, 3);
    final mvp =
        vec.Matrix4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0.5, 1) *
        vec.Matrix4.rotationX(time) *
        vec.Matrix4.rotationY(time * seedX) *
        vec.Matrix4.rotationZ(time * seedY);
    final color = <double>[0, 1, 0, 1];
    final frameInfoSlot = vertex.getUniformSlot('FrameInfo');
    final frameInfoFloats = Float32List.fromList([...mvp.storage, ...color]);
    final frameInfoView = transients.emplace(
      frameInfoFloats.buffer.asByteData(),
    );
    pass.bindUniform(frameInfoSlot, frameInfoView);
    pass.draw();
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset(-renderTexture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TrianglePage extends StatefulWidget {
  const TrianglePage({super.key});
  @override
  State<TrianglePage> createState() => _TrianglePageState();
}

class _TrianglePageState extends State<TrianglePage> {
  Ticker? tick;
  double time = 0, seedX = -0.512511498387847167, seedY = 0.521295573094847167;
  @override
  void initState() {
    super.initState();
    tick = Ticker(
      (elapsed) => setState(() => time = elapsed.inMilliseconds / 1000.0),
    );
    tick!.start();
  }

  @override
  void dispose() {
    tick?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Slider(
          value: seedX,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedX = value)},
        ),
        Slider(
          value: seedY,
          max: 1,
          min: -1,
          onChanged: (value) => {setState(() => seedY = value)},
        ),
        CustomPaint(painter: TrianglePainter(time, seedX, seedY)),
      ],
    );
  }
}

class EnemyCube {
  vec.Vector3 position;
  bool isAlive = true;
  double timeToDie = -1.0;
  EnemyCube(this.position);
}

class Projectile {
  vec.Vector3 position;
  vec.Vector3 direction;
  Projectile(this.position, this.direction);
}

class GameDemoPage extends StatefulWidget {
  const GameDemoPage({super.key});
  @override
  State<GameDemoPage> createState() => _GameDemoPageState();
}

class _GameDemoPageState extends State<GameDemoPage> {
  final vec.Vector3 _cameraOrbit = vec.Vector3(0.8, 1.2, 0.0);
  final double _cameraDistance = 25.0;
  final FocusNode _focusNode = FocusNode();
  final vec.Vector3 _playerPosition = vec.Vector3.zero();
  final List<EnemyCube> _enemies = [];
  final List<Projectile> _projectiles = [];
  final Queue<LogicalKeyboardKey> _keyQueue = Queue();
  double _lastShotTime = 0.0;
  Ticker? _ticker;
  double _time = 0;
  double _lastFrameTime = 0;
  gpu.DeviceBuffer? _cubeVertexBuffer;
  gpu.DeviceBuffer? _cubeIndexBuffer;
  gpu.RenderPipeline? _interactivePipeline;
  @override
  void initState() {
    super.initState();
    const int gridSize = 10;
    const double spacing = 2.5;
    for (int x = -gridSize; x <= gridSize; x++) {
      for (int z = -gridSize; z <= gridSize; z++) {
        _enemies.add(EnemyCube(vec.Vector3(x * spacing, 0, z * spacing)));
      }
    }
    _interactivePipeline = gpu.gpuContext.createRenderPipeline(
      shaderLibrary['InteractiveGameVertex']!,
      shaderLibrary['GameSceneFragment']!,
    );
    const List<double> cubeVertexData = [
      -1,
      1,
      -1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      -1,
      1,
      1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      -1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      -1,
      -1,
      -1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      -1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      -1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      -1,
      1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      1,
      1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      1,
      -1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      -1,
      -1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      1,
      -1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      -1,
      1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      -1,
      -1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      -1,
      1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      -1,
      -1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      -1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      -1,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
    ];
    _cubeVertexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      float32(cubeVertexData).lengthInBytes,
    );
    _cubeVertexBuffer!.overwrite(float32(cubeVertexData));
    const List<int> cubeIndexData = [
      0,
      1,
      2,
      0,
      2,
      3,
      4,
      5,
      6,
      4,
      6,
      7,
      8,
      9,
      10,
      8,
      10,
      11,
      12,
      13,
      14,
      12,
      14,
      15,
      16,
      17,
      18,
      16,
      18,
      19,
      20,
      21,
      22,
      20,
      22,
      23,
    ];
    _cubeIndexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      uint16(cubeIndexData).lengthInBytes,
    );
    _cubeIndexBuffer!.overwrite(uint16(cubeIndexData));
    _ticker = Ticker(_gameLoop);
    _ticker!.start();
  }

  void _gameLoop(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    final deltaTime = (currentTime - _lastFrameTime).clamp(0.0, 0.05);
    _lastFrameTime = currentTime;
    _handlePlayerMovement(deltaTime);
    _updateProjectiles(deltaTime);
    _checkCollisions();
    setState(() {
      _time = currentTime;
    });
  }

  void _handlePlayerMovement(double deltaTime) {
    const double moveSpeed = 10.0;
    if (_keyQueue.isEmpty) return;
    final key = _keyQueue.first;
    if (key == LogicalKeyboardKey.keyW) {
      _playerPosition.z -= moveSpeed * deltaTime;
    }
    if (key == LogicalKeyboardKey.keyS) {
      _playerPosition.z += moveSpeed * deltaTime;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _playerPosition.x -= moveSpeed * deltaTime;
    }
    if (key == LogicalKeyboardKey.keyD) {
      _playerPosition.x += moveSpeed * deltaTime;
    }
  }

  void _shoot() {
    if (_time - _lastShotTime < 0.2) return;
    _lastShotTime = _time;
    final fireDirection = vec.Vector3(
      -sin(_cameraOrbit.x) * sin(_cameraOrbit.y),
      0,
      -cos(_cameraOrbit.x) * sin(_cameraOrbit.y),
    ).normalized();
    _projectiles.add(
      Projectile(_playerPosition + fireDirection * 1.5, fireDirection),
    );
  }

  void _updateProjectiles(double deltaTime) {
    const double projectileSpeed = 30.0;
    for (var p in _projectiles) {
      p.position += p.direction * projectileSpeed * deltaTime;
    }
    _projectiles.removeWhere((p) => p.position.length > 50);
  }

  void _checkCollisions() {
    for (final projectile in _projectiles) {
      for (final enemy in _enemies) {
        if (enemy.isAlive) {
          final dist = projectile.position - enemy.position;
          if (dist.x.abs() < 1 && dist.y.abs() < 1 && dist.z.abs() < 1) {
            enemy.isAlive = false;
            enemy.timeToDie = _time;
            projectile.position.y = -1000;
            break;
          }
        }
      }
    }
    _projectiles.removeWhere((p) => p.position.y == -1000);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _cubeVertexBuffer = null;
    _cubeIndexBuffer = null;
    _interactivePipeline = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    if (_interactivePipeline == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      includeSemantics: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (!_keyQueue.contains(event.logicalKey)) {
            _keyQueue.addLast(event.logicalKey);
          }
        } else if (event is KeyUpEvent) {
          _keyQueue.remove(event.logicalKey);
        }
      },
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _cameraOrbit.x += details.delta.dx * 0.01;
          _cameraOrbit.y -= details.delta.dy * 0.01;
          _cameraOrbit.y = _cameraOrbit.y.clamp(0.1, pi - 0.1);
        }),
        onTap: _shoot,
        child: CustomPaint(
          size: Size.infinite,
          painter: GameScenePainter(
            pipeline: _interactivePipeline!,
            vertexBuffer: _cubeVertexBuffer!,
            indexBuffer: _cubeIndexBuffer!,
            cameraOrbit: _cameraOrbit,
            cameraDistance: _cameraDistance,
            playerPosition: _playerPosition,
            enemies: _enemies,
            projectiles: _projectiles,
            time: _time,
          ),
        ),
      ),
    );
  }
}

class GameScenePainter extends CustomPainter {
  GameScenePainter({
    required this.pipeline,
    required this.vertexBuffer,
    required this.indexBuffer,
    required this.cameraOrbit,
    required this.cameraDistance,
    required this.playerPosition,
    required this.enemies,
    required this.projectiles,
    required this.time,
  });
  final gpu.RenderPipeline pipeline;
  final gpu.DeviceBuffer vertexBuffer;
  final gpu.DeviceBuffer indexBuffer;
  final vec.Vector3 cameraOrbit;
  final double cameraDistance;
  final vec.Vector3 playerPosition;
  final List<EnemyCube> enemies;
  final List<Projectile> projectiles;
  final double time;
  static const int _cubeIndexCount = 36;
  static const int _cubeVertexCount = 24;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      size.width.toInt(),
      size.height.toInt(),
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(0.05, 0.06, 0.08, 1.0),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1.0,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    pass.bindPipeline(pipeline);
    final cameraFocusPoint = playerPosition;
    final cameraPosition =
        vec.Vector3(
          cameraDistance * sin(cameraOrbit.x) * sin(cameraOrbit.y),
          cameraDistance * cos(cameraOrbit.y),
          cameraDistance * cos(cameraOrbit.x) * sin(cameraOrbit.y),
        ) +
        cameraFocusPoint;
    final viewMatrix = vec.makeViewMatrix(
      cameraPosition,
      cameraFocusPoint,
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      pi / 4,
      size.width / size.height,
      0.1,
      1000.0,
    );
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    final transients = gpu.gpuContext.createHostBuffer();
    final sceneInfoSlot = pipeline.vertexShader.getUniformSlot('FrameInfo');
    final lightInfoSlot = pipeline.fragmentShader.getUniformSlot('LightInfo');
    final lightInfoData = Float32List.fromList([
      0.5,
      -1.0,
      -0.5,
      0.0,
      0.9,
      0.85,
      0.7,
      1.0,
      0.15,
      0.15,
      0.2,
      1.0,
    ]);
    final lightInfoView = transients.emplace(lightInfoData.buffer.asByteData());
    pass.bindUniform(lightInfoSlot, lightInfoView);
    pass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
      _cubeVertexCount,
    );
    pass.bindIndexBuffer(
      gpu.BufferView(
        indexBuffer,
        offsetInBytes: 0,
        lengthInBytes: indexBuffer.sizeInBytes,
      ),
      gpu.IndexType.int16,
      _cubeIndexCount,
    );
    const double deathAnimationDuration = 0.5;
    for (final enemy in enemies) {
      double animState = 0.0;
      if (!enemy.isAlive) {
        animState = (time - enemy.timeToDie) / deathAnimationDuration;
        if (animState >= 1.0) continue;
      }
      final modelMatrix = vec.Matrix4.translation(enemy.position);
      final mvp = viewProjectionMatrix * modelMatrix;
      final List<double> uniformData = [...mvp.storage, time, animState];
      final sceneInfoData = float32(uniformData);
      final sceneInfoView = transients.emplace(sceneInfoData);
      pass.bindUniform(sceneInfoSlot, sceneInfoView);
      pass.draw();
    }
    for (final projectile in projectiles) {
      final modelMatrix = vec.Matrix4.compose(
        projectile.position,
        vec.Quaternion.identity(),
        vec.Vector3(0.15, 0.15, 0.8),
      );
      final mvp = viewProjectionMatrix * modelMatrix;
      final List<double> uniformData = [...mvp.storage, time, 0.0];
      final sceneInfoData = float32(uniformData);
      final sceneInfoView = transients.emplace(sceneInfoData);
      pass.bindUniform(sceneInfoSlot, sceneInfoView);
      pass.draw();
    }
    final playerModelMatrix = vec.Matrix4.compose(
      playerPosition,
      vec.Quaternion.identity(),
      vec.Vector3(1.0, 1.5, 1.0),
    );
    final playerMvp = viewProjectionMatrix * playerModelMatrix;
    final List<double> uniformData = [...playerMvp.storage, time, 0.0];
    final sceneInfoData = float32(uniformData);
    final playerSceneInfoView = transients.emplace(sceneInfoData);
    pass.bindUniform(sceneInfoSlot, playerSceneInfoView);
    pass.draw();
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant GameScenePainter oldDelegate) => true;
}

class PhysicsCube {
  double physicsMode = 0.0;
  final vec.Vector3 position;
  final vec.Vector4 color;
  PhysicsCube(this.position, this.color);
}

class PhysicsDemoPage extends StatefulWidget {
  const PhysicsDemoPage({super.key});
  @override
  State<PhysicsDemoPage> createState() => _PhysicsDemoPageState();
}

class _PhysicsDemoPageState extends State<PhysicsDemoPage> {
  final vec.Vector3 _cameraOrbit = vec.Vector3(0.0, 0.5, 0.0);
  final double _cameraDistance = 50.0;
  final FocusNode _focusNode = FocusNode();
  final List<PhysicsCube> _cubes = [];
  Ticker? _ticker;
  double _time = 0;
  gpu.DeviceBuffer? _cubeVertexBuffer;
  gpu.DeviceBuffer? _cubeIndexBuffer;
  gpu.RenderPipeline? _pipeline;
  @override
  void initState() {
    super.initState();
    _resetSimulation();
    _pipeline = gpu.gpuContext.createRenderPipeline(
      shaderLibrary['PhysicsSandboxVertex']!,
      shaderLibrary['GameSceneFragment']!,
    );
    const List<double> cubeVertexData = [
      -1,
      1,
      -1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      -1,
      1,
      1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      -1,
      0,
      1,
      0,
      1,
      1,
      0,
      1,
      -1,
      -1,
      -1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      -1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      1,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      -1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      -1,
      1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      1,
      1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      -1,
      1,
      -1,
      -1,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      -1,
      -1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      1,
      -1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      1,
      -1,
      1,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      -1,
      -1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      -1,
      1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      1,
      -1,
      -1,
      0,
      0,
      -1,
      0,
      0,
      1,
      1,
      -1,
      -1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      -1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
      -1,
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      1,
    ];
    _cubeVertexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      float32(cubeVertexData).lengthInBytes,
    );
    _cubeVertexBuffer!.overwrite(float32(cubeVertexData));
    const List<int> cubeIndexData = [
      0,
      1,
      2,
      0,
      2,
      3,
      4,
      5,
      6,
      4,
      6,
      7,
      8,
      9,
      10,
      8,
      10,
      11,
      12,
      13,
      14,
      12,
      14,
      15,
      16,
      17,
      18,
      16,
      18,
      19,
      20,
      21,
      22,
      20,
      22,
      23,
    ];
    _cubeIndexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      uint16(cubeIndexData).lengthInBytes,
    );
    _cubeIndexBuffer!.overwrite(uint16(cubeIndexData));
    _ticker = Ticker((elapsed) {
      if (mounted) setState(() => _time = elapsed.inMilliseconds / 1000.0);
    });
    _ticker!.start();
  }

  void _resetSimulation() {
    setState(() {
      _cubes.clear();
      final rand = Random();
      const int gridSize = 4;
      const double spacing = 2.5;
      for (int x = -gridSize; x <= gridSize; x++) {
        for (int y = -gridSize; y <= gridSize; y++) {
          for (int z = -gridSize; z <= gridSize; z++) {
            final color = vec.Vector4(
              rand.nextDouble(),
              rand.nextDouble(),
              rand.nextDouble(),
              1.0,
            );
            _cubes.add(
              PhysicsCube(
                vec.Vector3(x * spacing, y * spacing, z * spacing),
                color,
              ),
            );
          }
        }
      }
    });
  }

  void _raycastAndExplode(Offset localPosition, Size size) {
    final viewMatrix = vec.makeViewMatrix(
      _getCameraPosition(),
      vec.Vector3.zero(),
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      pi / 4,
      size.width / size.height,
      0.1,
      1000.0,
    );
    final vpMatrix = projectionMatrix * viewMatrix;
    final invVP = vec.Matrix4.inverted(vpMatrix);
    final clipX = (localPosition.dx / size.width) * 2 - 1;
    final clipY = 1 - (localPosition.dy / size.height) * 2;
    final rayWorld = (invVP * vec.Vector4(clipX, clipY, 1, 1)).xyz;
    final rayDir = (rayWorld - _getCameraPosition()).normalized();
    PhysicsCube? closestCube;
    double closestDist = double.infinity;
    for (final cube in _cubes) {
      if (cube.physicsMode > 1.0) continue;
      final dist = (cube.position - _getCameraPosition()).dot(rayDir);
      if (dist < 0) continue;
      final p1 = _getCameraPosition() + rayDir * dist;
      final hitDist = (p1 - cube.position).length;
      if (hitDist < 1.5 && dist < closestDist) {
        closestDist = dist;
        closestCube = cube;
      }
    }
    if (closestCube != null) {
      setState(() => closestCube!.physicsMode = _time == 0.0 ? 0.0001 : _time);
    }
  }

  vec.Vector3 _getCameraPosition() => vec.Vector3(
    _cameraDistance * sin(_cameraOrbit.x) * cos(_cameraOrbit.y),
    _cameraDistance * sin(_cameraOrbit.y),
    _cameraDistance * cos(_cameraOrbit.x) * cos(_cameraOrbit.y),
  );
  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _cubeVertexBuffer = null;
    _cubeIndexBuffer = null;
    _pipeline = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    if (_pipeline == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyR) {
          _resetSimulation();
        }
      },
      child: Listener(
        onPointerDown: (details) {
          if (details.buttons == 1) {
            _raycastAndExplode(
              details.localPosition,
              (context.findRenderObject() as RenderBox).size,
            );
          } else if (details.buttons == 2) {
            setState(() {
              if (_cubes.isEmpty) return;
              final newMode =
                  _cubes
                          .firstWhere(
                            (c) => c.physicsMode <= 1.0,
                            orElse: () => _cubes.first,
                          )
                          .physicsMode ==
                      0.0
                  ? 1.0
                  : 0.0;
              for (var cube in _cubes) {
                if (cube.physicsMode <= 1.0) cube.physicsMode = newMode;
              }
            });
          }
        },
        child: GestureDetector(
          onPanUpdate: (details) => setState(() {
            _cameraOrbit.x += details.delta.dx * 0.01;
            _cameraOrbit.y -= details.delta.dy * 0.01;
            _cameraOrbit.y = _cameraOrbit.y.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
          }),
          child: CustomPaint(
            size: Size.infinite,
            painter: PhysicsScenePainter(
              pipeline: _pipeline!,
              vertexBuffer: _cubeVertexBuffer!,
              indexBuffer: _cubeIndexBuffer!,
              cameraPosition: _getCameraPosition(),
              cubes: _cubes,
              time: _time,
            ),
          ),
        ),
      ),
    );
  }
}

class PhysicsScenePainter extends CustomPainter {
  PhysicsScenePainter({
    required this.pipeline,
    required this.vertexBuffer,
    required this.indexBuffer,
    required this.cameraPosition,
    required this.cubes,
    required this.time,
  });
  final gpu.RenderPipeline pipeline;
  final gpu.DeviceBuffer vertexBuffer;
  final gpu.DeviceBuffer indexBuffer;
  final vec.Vector3 cameraPosition;
  final List<PhysicsCube> cubes;
  final double time;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      size.width.toInt(),
      size.height.toInt(),
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(0.05, 0.06, 0.08, 1.0),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1.0,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    pass.bindPipeline(pipeline);
    final viewMatrix = vec.makeViewMatrix(
      cameraPosition,
      vec.Vector3.zero(),
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      pi / 4,
      size.width / size.height,
      0.1,
      1000.0,
    );
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    final transients = gpu.gpuContext.createHostBuffer();
    final sceneInfoSlot = pipeline.vertexShader.getUniformSlot('FrameInfo');
    final lightInfoSlot = pipeline.fragmentShader.getUniformSlot('LightInfo');
    final lightInfoData = Float32List.fromList([
      0.5,
      1.0,
      0.5,
      0.0,
      0.9,
      0.85,
      0.7,
      1.0,
      0.15,
      0.15,
      0.2,
      1.0,
    ]);
    final lightInfoView = transients.emplace(lightInfoData.buffer.asByteData());
    pass.bindUniform(lightInfoSlot, lightInfoView);
    pass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
      24,
    );
    pass.bindIndexBuffer(
      gpu.BufferView(
        indexBuffer,
        offsetInBytes: 0,
        lengthInBytes: indexBuffer.sizeInBytes,
      ),
      gpu.IndexType.int16,
      36,
    );
    const double explosionDuration = 2.0;
    for (final cube in cubes) {
      if (cube.physicsMode > 1.0 &&
          time - cube.physicsMode > explosionDuration) {
        continue;
      }
      final modelMatrix = vec.Matrix4.translation(cube.position);
      final mvp = viewProjectionMatrix * modelMatrix;
      final List<double> uniformData = [
        ...mvp.storage,
        ...modelMatrix.storage,
        time,
        cube.physicsMode,
      ];
      final sceneInfoView = transients.emplace(float32(uniformData));
      pass.bindUniform(sceneInfoSlot, sceneInfoView);
      pass.draw();
    }
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant PhysicsScenePainter oldDelegate) => true;
}

class PhysicsVoxel {
  vec.Vector3 position;
  vec.Vector3 velocity = vec.Vector3.zero();
  final int colorIndex;
  PhysicsVoxel(this.position, this.colorIndex);
}

class Tetromino {
  List<vec.Vector3> localVoxels;
  vec.Vector3 position;
  final int colorIndex;
  Tetromino(this.position, this.localVoxels, this.colorIndex);
  List<vec.Vector3> get worldVoxels =>
      localVoxels.map((v) => v + position).toList();
  void rotateX() {
    localVoxels = localVoxels.map((v) => vec.Vector3(v.x, v.z, -v.y)).toList();
  }
}

class TetrisPhysicsPage extends StatefulWidget {
  const TetrisPhysicsPage({super.key});
  @override
  State<TetrisPhysicsPage> createState() => _TetrisPhysicsPageState();
}

class _TetrisPhysicsPageState extends State<TetrisPhysicsPage> {
  final vec.Vector3 _cameraOrbit = vec.Vector3(0.0, 0.7, 0.0);
  final double _cameraDistance = 45.0;
  final FocusNode _focusNode = FocusNode();
  final Map<String, PhysicsVoxel> _settledVoxels = {};
  Tetromino? _activeTetromino;
  final List<PhysicsVoxel> _particleVoxels = [];
  double _dropTimer = 0.0;
  bool _disintegrationMode = false;
  final Random _random = Random();
  final List<vec.Vector4> _colors = [
    vec.Vector4(1, 0.2, 0.2, 1),
    vec.Vector4(0.2, 1, 0.2, 1),
    vec.Vector4(0.2, 0.2, 1, 1),
    vec.Vector4(1, 1, 0.2, 1),
    vec.Vector4(0.2, 1, 1, 1),
    vec.Vector4(1, 0.2, 1, 1),
  ];
  static const int _boardWidth = 10;
  static const int _boardHeight = 22;
  Ticker? _ticker;
  double _lastFrameTime = 0;
  gpu.DeviceBuffer? _cubeVertexBuffer;
  gpu.DeviceBuffer? _cubeIndexBuffer;
  gpu.RenderPipeline? _pipeline;
  static final List<List<vec.Vector3>> _shapes = [
    [
      vec.Vector3(0, 0, 0),
      vec.Vector3(-1, 0, 0),
      vec.Vector3(1, 0, 0),
      vec.Vector3(2, 0, 0),
    ],
    [
      vec.Vector3(0, 0, 0),
      vec.Vector3(-1, 0, 0),
      vec.Vector3(1, 0, 0),
      vec.Vector3(1, -1, 0),
    ],
    [
      vec.Vector3(0, 0, 0),
      vec.Vector3(1, 0, 0),
      vec.Vector3(0, -1, 0),
      vec.Vector3(1, -1, 0),
    ],
    [
      vec.Vector3(0, 0, 0),
      vec.Vector3(-1, 0, 0),
      vec.Vector3(1, 0, 0),
      vec.Vector3(0, 1, 0),
    ],
  ];
  @override
  void initState() {
    super.initState();
    _pipeline = gpu.gpuContext.createRenderPipeline(
      shaderLibrary['TetrisVertex']!,
      shaderLibrary['TetrisFragment']!,
    );
    const List<double> cubeVertexData = [
      -0.5,
      0.5,
      -0.5,
      0,
      1,
      0,
      -0.5,
      0.5,
      0.5,
      0,
      1,
      0,
      0.5,
      0.5,
      0.5,
      0,
      1,
      0,
      0.5,
      0.5,
      -0.5,
      0,
      1,
      0,
      -0.5,
      -0.5,
      -0.5,
      0,
      -1,
      0,
      0.5,
      -0.5,
      -0.5,
      0,
      -1,
      0,
      0.5,
      -0.5,
      0.5,
      0,
      -1,
      0,
      -0.5,
      -0.5,
      0.5,
      0,
      -1,
      0,
      -0.5,
      -0.5,
      -0.5,
      -1,
      0,
      0,
      -0.5,
      -0.5,
      0.5,
      -1,
      0,
      0,
      -0.5,
      0.5,
      0.5,
      -1,
      0,
      0,
      -0.5,
      0.5,
      -0.5,
      -1,
      0,
      0,
      0.5,
      -0.5,
      -0.5,
      1,
      0,
      0,
      0.5,
      0.5,
      -0.5,
      1,
      0,
      0,
      0.5,
      0.5,
      0.5,
      1,
      0,
      0,
      0.5,
      -0.5,
      0.5,
      1,
      0,
      0,
      -0.5,
      -0.5,
      -0.5,
      0,
      0,
      -1,
      -0.5,
      0.5,
      -0.5,
      0,
      0,
      -1,
      0.5,
      0.5,
      -0.5,
      0,
      0,
      -1,
      0.5,
      -0.5,
      -0.5,
      0,
      0,
      -1,
      -0.5,
      -0.5,
      0.5,
      0,
      0,
      1,
      0.5,
      -0.5,
      0.5,
      0,
      0,
      1,
      0.5,
      0.5,
      0.5,
      0,
      0,
      1,
      -0.5,
      0.5,
      0.5,
      0,
      0,
      1,
    ];
    _cubeVertexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      float32(cubeVertexData).lengthInBytes,
    );
    _cubeVertexBuffer!.overwrite(float32(cubeVertexData));
    const List<int> cubeIndexData = [
      0,
      1,
      2,
      0,
      2,
      3,
      4,
      5,
      6,
      4,
      6,
      7,
      8,
      9,
      10,
      8,
      10,
      11,
      12,
      13,
      14,
      12,
      14,
      15,
      16,
      17,
      18,
      16,
      18,
      19,
      20,
      21,
      22,
      20,
      22,
      23,
    ];
    _cubeIndexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      uint16(cubeIndexData).lengthInBytes,
    );
    _cubeIndexBuffer!.overwrite(uint16(cubeIndexData));
    _spawnNewTetromino();
    _ticker = Ticker(_gameLoop)..start();
  }

  void _spawnNewTetromino() {
    final shape = _shapes[_random.nextInt(_shapes.length)];
    final color = _random.nextInt(_colors.length);
    _activeTetromino = Tetromino(
      vec.Vector3(0, _boardHeight.toDouble() - 2, 0),
      shape,
      color,
    );
    if (_checkCollision(_activeTetromino!)) {
      _settledVoxels.clear();
      _particleVoxels.clear();
      _spawnNewTetromino();
    }
  }

  void _gameLoop(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    final deltaTime = (_lastFrameTime == 0)
        ? 0.016
        : (currentTime - _lastFrameTime);
    _lastFrameTime = currentTime;
    _updateParticlePhysics(deltaTime);
    _dropTimer += deltaTime;
    if (_dropTimer > 0.5) {
      _dropTimer = 0.0;
      _moveActiveTetromino(vec.Vector3(0, -1, 0));
    }
    setState(() {});
  }

  void _updateParticlePhysics(double deltaTime) {
    if (_particleVoxels.isEmpty) return;
    final gravity = vec.Vector3(0, -30.0, 0);
    const restitution = 0.4;
    const floorLevel = 0.5;
    _particleVoxels.removeWhere((voxel) {
      voxel.velocity += gravity * deltaTime;
      voxel.position += voxel.velocity * deltaTime;
      if (voxel.position.y < floorLevel) {
        voxel.position.y = floorLevel;
        voxel.velocity.y *= -restitution;
        if (voxel.velocity.y.abs() < 0.1) {
          final x = voxel.position.x.round();
          final y = voxel.position.y.round();
          final z = voxel.position.z.round();
          _settledVoxels["$x,$y,$z"] = PhysicsVoxel(
            vec.Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
            voxel.colorIndex,
          );
          return true;
        }
      }
      return false;
    });
  }

  void _moveActiveTetromino(vec.Vector3 move, {bool rotate = false}) {
    if (_activeTetromino == null) return;
    final temp = Tetromino(
      _activeTetromino!.position + move,
      List.from(_activeTetromino!.localVoxels),
      _activeTetromino!.colorIndex,
    );
    if (rotate) temp.rotateX();
    if (!_checkCollision(temp)) {
      _activeTetromino = temp;
    } else if (move.y < 0) {
      _lockTetromino();
    }
  }

  bool _checkCollision(Tetromino t) {
    for (final voxelPos in t.worldVoxels) {
      final x = voxelPos.x.round();
      final y = voxelPos.y.round();
      final z = voxelPos.z.round();
      if (x.abs() > _boardWidth / 2 || y < 0) return true;
      if (_settledVoxels.containsKey("$x,$y,$z")) return true;
    }
    return false;
  }

  void _lockTetromino() {
    if (_activeTetromino == null) return;
    if (_disintegrationMode) {
      for (final voxelPos in _activeTetromino!.worldVoxels) {
        final newVoxel = PhysicsVoxel(voxelPos, _activeTetromino!.colorIndex);
        newVoxel.velocity.setValues(
          _random.nextDouble() * 4 - 2,
          2,
          _random.nextDouble() * 4 - 2,
        );
        _particleVoxels.add(newVoxel);
      }
    } else {
      for (final voxelPos in _activeTetromino!.worldVoxels) {
        final x = voxelPos.x.round();
        final y = voxelPos.y.round();
        final z = voxelPos.z.round();
        _settledVoxels["$x,$y,$z"] = PhysicsVoxel(
          vec.Vector3(x.toDouble(), y.toDouble(), z.toDouble()),
          _activeTetromino!.colorIndex,
        );
      }
      _clearPlanes();
    }
    _spawnNewTetromino();
  }

  void _clearPlanes() {}
  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _cubeVertexBuffer = null;
    _cubeIndexBuffer = null;
    _pipeline = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    if (_pipeline == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.keyA) {
            _moveActiveTetromino(vec.Vector3(-1, 0, 0));
          }
          if (key == LogicalKeyboardKey.keyD) {
            _moveActiveTetromino(vec.Vector3(1, 0, 0));
          }
          if (key == LogicalKeyboardKey.keyS) {
            _moveActiveTetromino(vec.Vector3(0, -1, 0));
          }
          if (key == LogicalKeyboardKey.keyQ) {
            _moveActiveTetromino(vec.Vector3.zero(), rotate: true);
          }
          if (key == LogicalKeyboardKey.keyP) {
            setState(() => _disintegrationMode = !_disintegrationMode);
          }
        }
      },
      child: GestureDetector(
        onPanUpdate: (details) => setState(() {
          _cameraOrbit.x += details.delta.dx * 0.01;
          _cameraOrbit.y -= details.delta.dy * 0.01;
          _cameraOrbit.y = _cameraOrbit.y.clamp(-pi / 2 + 0.1, pi / 2 - 0.1);
        }),
        child: CustomPaint(
          size: Size.infinite,
          painter: TetrisScenePainter(
            pipeline: _pipeline!,
            vertexBuffer: _cubeVertexBuffer!,
            indexBuffer: _cubeIndexBuffer!,
            cameraPosition: vec.Vector3(
              _cameraDistance * sin(_cameraOrbit.x) * cos(_cameraOrbit.y),
              _cameraDistance * sin(_cameraOrbit.y),
              _cameraDistance * cos(_cameraOrbit.x) * cos(_cameraOrbit.y),
            ),
            activeTetromino: _activeTetromino,
            settledVoxels: _settledVoxels.values.toList(),
            particleVoxels: _particleVoxels,
            colors: _colors,
          ),
        ),
      ),
    );
  }
}

class TetrisScenePainter extends CustomPainter {
  TetrisScenePainter({
    required this.pipeline,
    required this.vertexBuffer,
    required this.indexBuffer,
    required this.cameraPosition,
    required this.activeTetromino,
    required this.settledVoxels,
    required this.particleVoxels,
    required this.colors,
  });
  final gpu.RenderPipeline pipeline;
  final gpu.DeviceBuffer vertexBuffer;
  final gpu.DeviceBuffer indexBuffer;
  final vec.Vector3 cameraPosition;
  final Tetromino? activeTetromino;
  final List<PhysicsVoxel> settledVoxels;
  final List<PhysicsVoxel> particleVoxels;
  final List<vec.Vector4> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      size.width.toInt(),
      size.height.toInt(),
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(0.05, 0.06, 0.08, 1.0),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1.0,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    pass.bindPipeline(pipeline);
    final viewMatrix = vec.makeViewMatrix(
      cameraPosition,
      vec.Vector3(0, 10, 0),
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      pi / 4,
      size.width / size.height,
      0.1,
      1000.0,
    );
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    final transients = gpu.gpuContext.createHostBuffer();
    final sceneInfoSlot = pipeline.vertexShader.getUniformSlot('FrameInfo');
    final colorInfoSlot = pipeline.fragmentShader.getUniformSlot('ColorInfo');
    final lightInfoSlot = pipeline.fragmentShader.getUniformSlot('LightInfo');
    final lightInfoData = Float32List.fromList([
      0.5,
      1.0,
      0.5,
      0.0,
      0.9,
      0.85,
      0.7,
      1.0,
      0.2,
      0.2,
      0.25,
      1.0,
    ]);
    pass.bindUniform(
      lightInfoSlot,
      transients.emplace(lightInfoData.buffer.asByteData()),
    );
    pass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
      24,
    );
    pass.bindIndexBuffer(
      gpu.BufferView(
        indexBuffer,
        offsetInBytes: 0,
        lengthInBytes: indexBuffer.sizeInBytes,
      ),
      gpu.IndexType.int16,
      36,
    );
    void drawVoxel(vec.Vector3 position, int colorIndex) {
      final modelMatrix = vec.Matrix4.translation(position);
      final mvp = viewProjectionMatrix * modelMatrix;
      final sceneInfoView = transients.emplace(
        float32([...mvp.storage, ...modelMatrix.storage]),
      );
      pass.bindUniform(sceneInfoSlot, sceneInfoView);
      final colorView = transients.emplace(float32(colors[colorIndex].storage));
      pass.bindUniform(colorInfoSlot, colorView);
      pass.draw();
    }

    for (var v in settledVoxels) {
      drawVoxel(v.position, v.colorIndex);
    }
    for (var v in particleVoxels) {
      drawVoxel(v.position, v.colorIndex);
    }
    activeTetromino?.worldVoxels.forEach(
      (pos) => drawVoxel(pos, activeTetromino!.colorIndex),
    );
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant TetrisScenePainter oldDelegate) => true;
}

class Blob {
  vec.Vector3 position;
  vec.Vector3 velocity;
  final double initialRadius;
  double radius;
  final vec.Vector4 color;
  Blob({
    required this.position,
    required this.velocity,
    required this.initialRadius,
    required this.color,
  }) : radius = initialRadius;
}

class RigidSoftBodyPhysicsPage extends StatefulWidget {
  const RigidSoftBodyPhysicsPage({super.key});
  @override
  State<RigidSoftBodyPhysicsPage> createState() =>
      _RigidSoftBodyPhysicsPageState();
}

class _RigidSoftBodyPhysicsPageState extends State<RigidSoftBodyPhysicsPage> {
  final vec.Vector3 _cameraOrbit = vec.Vector3(0.0, 0.5, 0.0);
  final double _cameraDistance = 30.0;
  final FocusNode _focusNode = FocusNode();
  final List<PhysicsBody> _bodies = [];
  final List<SoftBodyConstraint> _constraints = [];
  bool _isRigidMode = true;
  double _gravity = -9.8;
  final double _damping = 0.98;
  double _springStiffness = 50.0;
  Ticker? _ticker;
  double _time = 0;
  double _lastFrameTime = 0;
  gpu.DeviceBuffer? _sphereVertexBuffer;
  gpu.DeviceBuffer? _sphereIndexBuffer;
  gpu.RenderPipeline? _pipeline;
  int _sphereIndexCount = 0;
  @override
  void initState() {
    super.initState();
    _initializePhysicsBodies();
    _createSphereGeometry();
    _pipeline = gpu.gpuContext.createRenderPipeline(
      shaderLibrary['PhysicsSandboxVertex']!,
      shaderLibrary['GameSceneFragment']!,
    );
    _ticker = Ticker(_physicsLoop)..start();
  }

  void _initializePhysicsBodies() {
    _bodies.clear();
    _constraints.clear();
    const int gridSize = 4;
    const double spacing = 2.0;
    final random = Random();
    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        for (int z = 0; z < gridSize; z++) {
          final position = vec.Vector3(
            (x - gridSize / 2) * spacing,
            y * spacing + 10,
            (z - gridSize / 2) * spacing,
          );
          final body = PhysicsBody(
            position: position,
            velocity: vec.Vector3(
              random.nextDouble() * 2 - 1,
              0,
              random.nextDouble() * 2 - 1,
            ),
            mass: 1.0,
            radius: 0.5,
            color: vec.Vector4(
              random.nextDouble(),
              random.nextDouble(),
              random.nextDouble(),
              1.0,
            ),
          );
          _bodies.add(body);
        }
      }
    }
    _updateConstraints();
  }

  void _updateConstraints() {
    _constraints.clear();
    if (!_isRigidMode) {
      for (int i = 0; i < _bodies.length; i++) {
        for (int j = i + 1; j < _bodies.length; j++) {
          final distance = (_bodies[i].position - _bodies[j].position).length;
          if (distance < 3.0) {
            _constraints.add(
              SoftBodyConstraint(
                bodyA: _bodies[i],
                bodyB: _bodies[j],
                restLength: distance,
                stiffness: _springStiffness,
              ),
            );
          }
        }
      }
    }
  }

  void _createSphereGeometry() {
    final vertices = <double>[];
    final indices = <int>[];
    const int rings = 12;
    const int sectors = 12;
    const double radius = 1.0;
    for (int r = 0; r <= rings; r++) {
      final double y = cos(pi * r / rings);
      final double ringRadius = sin(pi * r / rings);
      for (int s = 0; s <= sectors; s++) {
        final double x = ringRadius * cos(2 * pi * s / sectors);
        final double z = ringRadius * sin(2 * pi * s / sectors);
        vertices.addAll([x * radius, y * radius, z * radius]);
        vertices.addAll([x, y, z]);
        vertices.addAll([1.0, 1.0, 1.0, 1.0]);
      }
    }
    for (int r = 0; r < rings; r++) {
      for (int s = 0; s < sectors; s++) {
        final int current = r * (sectors + 1) + s;
        final int next = current + sectors + 1;
        indices.addAll([current, next, current + 1]);
        indices.addAll([current + 1, next, next + 1]);
      }
    }
    _sphereIndexCount = indices.length;
    _sphereVertexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      float32(vertices).lengthInBytes,
    );
    _sphereVertexBuffer!.overwrite(float32(vertices));
    _sphereIndexBuffer = gpu.gpuContext.createDeviceBuffer(
      gpu.StorageMode.hostVisible,
      uint16(indices).lengthInBytes,
    );
    _sphereIndexBuffer!.overwrite(uint16(indices));
  }

  void _physicsLoop(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    final deltaTime = _lastFrameTime == 0
        ? 0.016
        : (currentTime - _lastFrameTime).clamp(0.0, 0.033);
    _lastFrameTime = currentTime;
    _updatePhysics(deltaTime);
    setState(() {
      _time = currentTime;
    });
  }

  void _updatePhysics(double deltaTime) {
    for (final body in _bodies) {
      if (_isRigidMode) {
        body.velocity.y += _gravity * deltaTime;
        body.position += body.velocity * deltaTime;
        body.velocity *= _damping;
        if (body.position.y - body.radius < 0) {
          body.position.y = body.radius;
          body.velocity.y *= -0.7;
        }
        const double wallLimit = 15.0;
        if (body.position.x.abs() > wallLimit) {
          body.position.x = body.position.x.sign * wallLimit;
          body.velocity.x *= -0.7;
        }
        if (body.position.z.abs() > wallLimit) {
          body.position.z = body.position.z.sign * wallLimit;
          body.velocity.z *= -0.7;
        }
        for (int i = 0; i < _bodies.length; i++) {
          for (int j = i + 1; j < _bodies.length; j++) {
            final bodyA = _bodies[i];
            final bodyB = _bodies[j];
            final diff = bodyA.position - bodyB.position;
            final distance = diff.length;
            final minDistance = bodyA.radius + bodyB.radius;
            if (distance < minDistance && distance > 0) {
              final overlap = minDistance - distance;
              final direction = diff.normalized();
              final correction = direction * (overlap * 0.5);
              bodyA.position += correction;
              bodyB.position -= correction;
              final relativeVelocity = bodyA.velocity - bodyB.velocity;
              final velocityAlongNormal = relativeVelocity.dot(direction);
              if (velocityAlongNormal > 0) continue;
              const double restitution = 0.8;
              final impulse = -(1 + restitution) * velocityAlongNormal / 2;
              bodyA.velocity += direction * impulse;
              bodyB.velocity -= direction * impulse;
            }
          }
        }
      } else {
        body.velocity.y += _gravity * deltaTime;
        body.position += body.velocity * deltaTime;
        body.velocity *= _damping;
        if (body.position.y - body.radius < 0) {
          body.position.y = body.radius;
          body.velocity.y *= -0.3;
        }
      }
    }
    if (!_isRigidMode) {
      for (int iteration = 0; iteration < 3; iteration++) {
        for (final constraint in _constraints) {
          final diff = constraint.bodyA.position - constraint.bodyB.position;
          final distance = diff.length;
          if (distance > 0) {
            final force =
                (distance - constraint.restLength) *
                constraint.stiffness *
                deltaTime;
            final direction = diff.normalized();
            final correction = direction * (force * 0.5);
            constraint.bodyA.position -= correction;
            constraint.bodyB.position += correction;
            final relativeVelocity =
                constraint.bodyA.velocity - constraint.bodyB.velocity;
            final velocityAlongConstraint = relativeVelocity.dot(direction);
            final dampingForce = direction * (velocityAlongConstraint * 0.1);
            constraint.bodyA.velocity -= dampingForce;
            constraint.bodyB.velocity += dampingForce;
          }
        }
      }
    }
  }

  void _togglePhysicsMode() {
    setState(() {
      _isRigidMode = !_isRigidMode;
      _updateConstraints();
    });
  }

  void _resetSimulation() {
    _initializePhysicsBodies();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _sphereVertexBuffer = null;
    _sphereIndexBuffer = null;
    _pipeline = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).requestFocus(_focusNode);
    if (_pipeline == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ElevatedButton(
                onPressed: _togglePhysicsMode,
                child: Text(
                  _isRigidMode ? 'Switch to Soft Body' : 'Switch to Rigid Body',
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _resetSimulation,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 10),
              Text('Bodies: ${_bodies.length}'),
              const SizedBox(width: 10),
              Text('Constraints: ${_constraints.length}'),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('Gravity: ${_gravity.toStringAsFixed(1)}'),
                  Slider(
                    value: _gravity,
                    min: -20.0,
                    max: 0.0,
                    onChanged: (value) => setState(() => _gravity = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Spring Stiffness: ${_springStiffness.toStringAsFixed(1)}',
                  ),
                  Slider(
                    value: _springStiffness,
                    min: 10.0,
                    max: 100.0,
                    onChanged: (value) => setState(() {
                      _springStiffness = value;
                      _updateConstraints();
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  _togglePhysicsMode();
                } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
                  _resetSimulation();
                }
              }
            },
            child: GestureDetector(
              onPanUpdate: (details) => setState(() {
                _cameraOrbit.x += details.delta.dx * 0.01;
                _cameraOrbit.y -= details.delta.dy * 0.01;
                _cameraOrbit.y = _cameraOrbit.y.clamp(
                  -pi / 2 + 0.1,
                  pi / 2 - 0.1,
                );
              }),
              child: CustomPaint(
                size: Size.infinite,
                painter: RigidSoftBodyPainter(
                  pipeline: _pipeline!,
                  vertexBuffer: _sphereVertexBuffer!,
                  indexBuffer: _sphereIndexBuffer!,
                  indexCount: _sphereIndexCount,
                  cameraPosition: vec.Vector3(
                    _cameraDistance * sin(_cameraOrbit.x) * cos(_cameraOrbit.y),
                    _cameraDistance * sin(_cameraOrbit.y),
                    _cameraDistance * cos(_cameraOrbit.x) * cos(_cameraOrbit.y),
                  ),
                  bodies: _bodies,
                  constraints: _constraints,
                  isRigidMode: _isRigidMode,
                  time: _time,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PhysicsBody {
  vec.Vector3 position;
  vec.Vector3 velocity;
  double mass;
  double radius;
  vec.Vector4 color;
  PhysicsBody({
    required this.position,
    required this.velocity,
    required this.mass,
    required this.radius,
    required this.color,
  });
}

class SoftBodyConstraint {
  final PhysicsBody bodyA;
  final PhysicsBody bodyB;
  final double restLength;
  final double stiffness;
  SoftBodyConstraint({
    required this.bodyA,
    required this.bodyB,
    required this.restLength,
    required this.stiffness,
  });
}

class RigidSoftBodyPainter extends CustomPainter {
  final gpu.RenderPipeline pipeline;
  final gpu.DeviceBuffer vertexBuffer;
  final gpu.DeviceBuffer indexBuffer;
  final int indexCount;
  final vec.Vector3 cameraPosition;
  final List<PhysicsBody> bodies;
  final List<SoftBodyConstraint> constraints;
  final bool isRigidMode;
  final double time;
  RigidSoftBodyPainter({
    required this.pipeline,
    required this.vertexBuffer,
    required this.indexBuffer,
    required this.indexCount,
    required this.cameraPosition,
    required this.bodies,
    required this.constraints,
    required this.isRigidMode,
    required this.time,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final gpu.Texture depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      size.width.toInt(),
      size.height.toInt(),
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(0.1, 0.1, 0.15, 1.0),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1.0,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    pass.bindPipeline(pipeline);
    final viewMatrix = vec.makeViewMatrix(
      cameraPosition,
      vec.Vector3.zero(),
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      pi / 4,
      size.width / size.height,
      0.1,
      1000.0,
    );
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    final transients = gpu.gpuContext.createHostBuffer();
    final lightInfoSlot = pipeline.fragmentShader.getUniformSlot('LightInfo');
    final lightInfoData = Float32List.fromList([
      0.5,
      1.0,
      0.5,
      0.0,
      0.9,
      0.85,
      0.7,
      1.0,
      0.15,
      0.15,
      0.2,
      1.0,
    ]);
    final lightInfoView = transients.emplace(lightInfoData.buffer.asByteData());
    pass.bindUniform(lightInfoSlot, lightInfoView);
    pass.bindVertexBuffer(
      gpu.BufferView(
        vertexBuffer,
        offsetInBytes: 0,
        lengthInBytes: vertexBuffer.sizeInBytes,
      ),
      (vertexBuffer.sizeInBytes ~/ (10 * 4)),
    );
    pass.bindIndexBuffer(
      gpu.BufferView(
        indexBuffer,
        offsetInBytes: 0,
        lengthInBytes: indexBuffer.sizeInBytes,
      ),
      gpu.IndexType.int16,
      indexCount,
    );
    final sceneInfoSlot = pipeline.vertexShader.getUniformSlot('FrameInfo');
    for (final body in bodies) {
      final modelMatrix = vec.Matrix4.compose(
        body.position,
        vec.Quaternion.identity(),
        vec.Vector3.all(body.radius),
      );
      final mvp = viewProjectionMatrix * modelMatrix;
      final uniformData = Float32List.fromList([
        ...mvp.storage,
        ...modelMatrix.storage,
        time,
        isRigidMode ? 1.0 : 0.0,
      ]);
      final uniformView = transients.emplace(uniformData.buffer.asByteData());
      pass.bindUniform(sceneInfoSlot, uniformView);
      pass.draw();
    }
    if (!isRigidMode && constraints.isNotEmpty) {}
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant RigidSoftBodyPainter oldDelegate) => true;
}

class SDFMetaball {
  vec.Vector3 position;
  vec.Vector3 velocity;
  double radius;
  double mass;
  vec.Vector3 color;
  double temperature;
  bool isDragging = false;
  SDFMetaball({
    required this.position,
    required this.radius,
    required this.mass,
    required this.color,
    this.temperature = 0.0,
  }) : velocity = vec.Vector3.zero();
}

class CustomColorPicker extends StatefulWidget {
  final vec.Vector3 initialColor;
  final Function(vec.Vector3) onColorChanged;
  final VoidCallback onClose;
  const CustomColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    required this.onClose,
  });
  @override
  State<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends State<CustomColorPicker> {
  late vec.Vector3 currentColor;
  @override
  void initState() {
    super.initState();
    currentColor = vec.Vector3.copy(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Color Picker',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            height: 60,
            decoration: BoxDecoration(
              color: Color.fromRGBO(
                (currentColor.r * 255).toInt(),
                (currentColor.g * 255).toInt(),
                (currentColor.b * 255).toInt(),
                1.0,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildColorSlider('Red', currentColor.r, Colors.red, (
                      value,
                    ) {
                      setState(() => currentColor.r = value);
                      widget.onColorChanged(currentColor);
                    }),
                    const SizedBox(height: 16),
                    _buildColorSlider('Green', currentColor.g, Colors.green, (
                      value,
                    ) {
                      setState(() => currentColor.g = value);
                      widget.onColorChanged(currentColor);
                    }),
                    const SizedBox(height: 16),
                    _buildColorSlider('Blue', currentColor.b, Colors.blue, (
                      value,
                    ) {
                      setState(() => currentColor.b = value);
                      widget.onColorChanged(currentColor);
                    }),
                    const SizedBox(height: 24),
                    const Text(
                      'Preset Colors',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetColor(vec.Vector3(1.0, 0.2, 0.2)),
                        _buildPresetColor(vec.Vector3(0.2, 1.0, 0.2)),
                        _buildPresetColor(vec.Vector3(0.2, 0.2, 1.0)),
                        _buildPresetColor(vec.Vector3(1.0, 1.0, 0.2)),
                        _buildPresetColor(vec.Vector3(1.0, 0.2, 1.0)),
                        _buildPresetColor(vec.Vector3(0.2, 1.0, 1.0)),
                        _buildPresetColor(vec.Vector3(1.0, 0.5, 0.0)),
                        _buildPresetColor(vec.Vector3(0.5, 0.0, 1.0)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSlider(
    String label,
    double value,
    Color color,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withAlpha(51),
          ),
          child: Slider(value: value, min: 0.0, max: 1.0, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildPresetColor(vec.Vector3 color) {
    return GestureDetector(
      onTap: () {
        setState(() => currentColor = vec.Vector3.copy(color));
        widget.onColorChanged(currentColor);
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Color.fromRGBO(
            (color.r * 255).toInt(),
            (color.g * 255).toInt(),
            (color.b * 255).toInt(),
            1.0,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey),
        ),
      ),
    );
  }
}

class SDFPhysicsPage extends StatefulWidget {
  const SDFPhysicsPage({super.key});
  @override
  State<SDFPhysicsPage> createState() => _SDFPhysicsPageState();
}

class _SDFPhysicsPageState extends State<SDFPhysicsPage> {
  final List<SDFMetaball> _metaballs = [];
  vec.Vector3 _cameraPosition = vec.Vector3(0, 5, 15);
  vec.Vector3 _cameraTarget = vec.Vector3.zero();
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  bool _isRigidMode = false;
  double _smoothUnionK = 0.5;
  double _time = 0.0;
  Ticker? _ticker;
  SDFMetaball? _draggedMetaball;
  Offset? _lastPanPosition;
  bool _isShiftPressed = false;
  final bool _isRightMousePressed = false;
  OverlayEntry? _colorPickerOverlay;
  @override
  void initState() {
    super.initState();
    _initializeMetaballs();
    _ticker = Ticker(_updatePhysics);
    _ticker!.start();
  }

  void _initializeMetaballs() {
    final random = Random();
    for (int i = 0; i < 8; i++) {
      _metaballs.add(
        SDFMetaball(
          position: vec.Vector3(
            (random.nextDouble() - 0.5) * 10,
            random.nextDouble() * 5 + 2,
            (random.nextDouble() - 0.5) * 10,
          ),
          radius: 0.8 + random.nextDouble() * 0.7,
          mass: 1.0 + random.nextDouble() * 2.0,
          color: vec.Vector3(
            0.3 + random.nextDouble() * 0.7,
            0.3 + random.nextDouble() * 0.7,
            0.3 + random.nextDouble() * 0.7,
          ),
          temperature: random.nextDouble(),
        ),
      );
    }
  }

  void _updatePhysics(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    final deltaTime = currentTime - _time;
    _time = currentTime;
    _handleKeyboardInput(deltaTime);
    if (!_isRigidMode) {
      _updateSoftBodyPhysics(deltaTime);
    } else {
      _updateRigidBodyPhysics(deltaTime);
    }
    setState(() {});
  }

  void _handleKeyboardInput(double deltaTime) {
    const double moveSpeed = 10.0;
    vec.Vector3 movement = vec.Vector3.zero();
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      movement += (_cameraTarget - _cameraPosition).normalized();
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      movement -= (_cameraTarget - _cameraPosition).normalized();
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      final right = (_cameraTarget - _cameraPosition)
          .cross(vec.Vector3(0, 1, 0))
          .normalized();
      movement -= right;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      final right = (_cameraTarget - _cameraPosition)
          .cross(vec.Vector3(0, 1, 0))
          .normalized();
      movement += right;
    }
    if (movement.length > 0) {
      movement.normalize();
      _cameraPosition += movement * moveSpeed * deltaTime;
      _cameraTarget += movement * moveSpeed * deltaTime;
    }
  }

  void _updateSoftBodyPhysics(double deltaTime) {
    const double gravity = -9.81;
    const double damping = 0.98;
    const double floorY = 0.0;
    for (var metaball in _metaballs) {
      if (metaball.isDragging) continue;
      metaball.velocity.y += gravity * deltaTime;
      metaball.velocity *= damping;
      metaball.position += metaball.velocity * deltaTime;
      if (metaball.position.y - metaball.radius < floorY) {
        metaball.position.y = floorY + metaball.radius;
        metaball.velocity.y *= -0.6;
        metaball.temperature = min(1.0, metaball.temperature + 0.1);
      }
      for (var other in _metaballs) {
        if (other == metaball) continue;
        final distance = (metaball.position - other.position).length;
        final minDistance = metaball.radius + other.radius;
        if (distance < minDistance * 1.5) {
          final overlap = minDistance - distance;
          if (overlap > 0) {
            final direction = (metaball.position - other.position).normalized();
            final force = direction * overlap * 2.0;
            metaball.velocity += force * deltaTime / metaball.mass;
            other.velocity -= force * deltaTime / other.mass;
            final avgTemp = (metaball.temperature + other.temperature) * 0.5;
            metaball.temperature = avgTemp;
            other.temperature = avgTemp;
          }
        }
      }
      metaball.temperature = max(0.0, metaball.temperature - deltaTime * 0.2);
    }
  }

  void _updateRigidBodyPhysics(double deltaTime) {
    const double gravity = -9.81;
    const double damping = 0.99;
    const double floorY = 0.0;
    for (var metaball in _metaballs) {
      if (metaball.isDragging) continue;
      metaball.velocity.y += gravity * deltaTime;
      metaball.velocity *= damping;
      metaball.position += metaball.velocity * deltaTime;
      if (metaball.position.y - metaball.radius < floorY) {
        metaball.position.y = floorY + metaball.radius;
        metaball.velocity.y *= -0.8;
      }
      for (var other in _metaballs) {
        if (other == metaball) continue;
        final distance = (metaball.position - other.position).length;
        final minDistance = metaball.radius + other.radius;
        if (distance < minDistance) {
          final direction = (metaball.position - other.position).normalized();
          final overlap = minDistance - distance;
          final separation = direction * (overlap * 0.5);
          metaball.position += separation;
          other.position -= separation;
          final relativeVelocity = metaball.velocity - other.velocity;
          final velocityAlongNormal = relativeVelocity.dot(direction);
          if (velocityAlongNormal > 0) continue;
          final restitution = 0.8;
          final impulse =
              -(1 + restitution) *
              velocityAlongNormal /
              (1 / metaball.mass + 1 / other.mass);
          metaball.velocity += direction * (impulse / metaball.mass);
          other.velocity -= direction * (impulse / other.mass);
        }
      }
    }
  }

  void _handlePanStart(DragStartDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    _draggedMetaball = _getMetaballAtScreenPosition(
      localPosition,
      renderBox.size,
    );
    _lastPanPosition = localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    if (_isShiftPressed || _isRightMousePressed) {
      final delta = localPosition - (_lastPanPosition ?? localPosition);
      final sensitivity = 0.01;
      final distance = (_cameraPosition - _cameraTarget).length;
      final currentAngle = atan2(
        _cameraPosition.x - _cameraTarget.x,
        _cameraPosition.z - _cameraTarget.z,
      );
      final currentElevation = asin(
        (_cameraPosition.y - _cameraTarget.y) / distance,
      );
      final newAngle = currentAngle + delta.dx * sensitivity;
      final newElevation = (currentElevation - delta.dy * sensitivity).clamp(
        -pi / 2 + 0.1,
        pi / 2 - 0.1,
      );
      _cameraPosition.x =
          _cameraTarget.x + distance * sin(newAngle) * cos(newElevation);
      _cameraPosition.z =
          _cameraTarget.z + distance * cos(newAngle) * cos(newElevation);
      _cameraPosition.y = _cameraTarget.y + distance * sin(newElevation);
    } else if (_draggedMetaball != null) {
      final worldDelta = _screenToWorldDelta(
        localPosition - (_lastPanPosition ?? localPosition),
        renderBox.size,
      );
      _draggedMetaball!.position += worldDelta;
      _draggedMetaball!.velocity *= 0.5;
      _draggedMetaball!.isDragging = true;
    }
    _lastPanPosition = localPosition;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_draggedMetaball != null) {
      _draggedMetaball!.isDragging = false;
    }
    _draggedMetaball = null;
    _lastPanPosition = null;
  }

  void _handleTap(TapUpDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final metaball = _getMetaballAtScreenPosition(
      localPosition,
      renderBox.size,
    );
    if (metaball == null) {
      final worldPos = _screenToWorldPosition(localPosition, renderBox.size);
      final random = Random();
      _metaballs.add(
        SDFMetaball(
          position: worldPos,
          radius: 0.8 + random.nextDouble() * 0.7,
          mass: 1.0 + random.nextDouble() * 2.0,
          color: vec.Vector3(
            0.3 + random.nextDouble() * 0.7,
            0.3 + random.nextDouble() * 0.7,
            0.3 + random.nextDouble() * 0.7,
          ),
          temperature: random.nextDouble(),
        ),
      );
    }
  }

  void _handleDoubleTap(TapDownDetails details) {
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final metaball = _getMetaballAtScreenPosition(
      localPosition,
      renderBox.size,
    );
    if (metaball != null) {
      _showColorPicker(metaball, details.globalPosition);
    }
  }

  void _showColorPicker(SDFMetaball metaball, Offset globalPosition) {
    _colorPickerOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: globalPosition.dx - 150,
        top: globalPosition.dy - 200,
        child: Material(
          color: Colors.transparent,
          child: CustomColorPicker(
            initialColor: metaball.color,
            onColorChanged: (newColor) {
              setState(() {
                metaball.color = newColor;
              });
            },
            onClose: () {
              _colorPickerOverlay?.remove();
              _colorPickerOverlay = null;
            },
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_colorPickerOverlay!);
  }

  SDFMetaball? _getMetaballAtScreenPosition(Offset screenPos, Size screenSize) {
    for (var metaball in _metaballs) {
      final screenMetaballPos = _worldToScreenPosition(
        metaball.position,
        screenSize,
      );
      final distance = (screenPos - screenMetaballPos).distance;
      if (distance < 30) {
        return metaball;
      }
    }
    return null;
  }

  Offset _worldToScreenPosition(vec.Vector3 worldPos, Size screenSize) {
    final viewMatrix = _getViewMatrix();
    final projMatrix = _getProjectionMatrix(
      screenSize.width / screenSize.height,
    );
    final mvp = projMatrix * viewMatrix;
    final clipPos = mvp * vec.Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
    final ndc = clipPos.xyz / clipPos.w;
    return Offset(
      (ndc.x * 0.5 + 0.5) * screenSize.width,
      (1.0 - (ndc.y * 0.5 + 0.5)) * screenSize.height,
    );
  }

  vec.Vector3 _screenToWorldPosition(Offset screenPos, Size screenSize) {
    final viewMatrix = _getViewMatrix();
    final projMatrix = _getProjectionMatrix(
      screenSize.width / screenSize.height,
    );
    final mvp = projMatrix * viewMatrix;
    final invMVP = vec.Matrix4.inverted(mvp);
    final ndc = vec.Vector3(
      (screenPos.dx / screenSize.width) * 2.0 - 1.0,
      1.0 - (screenPos.dy / screenSize.height) * 2.0,
      0.0,
    );
    final worldPos = invMVP * vec.Vector4(ndc.x, ndc.y, ndc.z, 1.0);
    return worldPos.xyz / worldPos.w;
  }

  vec.Vector3 _screenToWorldDelta(Offset screenDelta, Size screenSize) {
    final sensitivity = 0.01;
    return vec.Vector3(
      screenDelta.dx * sensitivity,
      -screenDelta.dy * sensitivity,
      0.0,
    );
  }

  vec.Matrix4 _getViewMatrix() {
    return vec.makeViewMatrix(
      _cameraPosition,
      _cameraTarget,
      vec.Vector3(0, 1, 0),
    );
  }

  vec.Matrix4 _getProjectionMatrix(double aspectRatio) {
    return vec.makePerspectiveMatrix(pi / 4, aspectRatio, 0.1, 100.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    _colorPickerOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            _pressedKeys.add(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                event.logicalKey == LogicalKeyboardKey.shiftRight) {
              _isShiftPressed = true;
            }
          } else if (event is KeyUpEvent) {
            _pressedKeys.remove(event.logicalKey);
            if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                event.logicalKey == LogicalKeyboardKey.shiftRight) {
              _isShiftPressed = false;
            }
          }
          return KeyEventResult.handled;
        },
        child: Stack(
          children: [
            GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              onTapUp: _handleTap,
              onTapDown: _handleDoubleTap,
              child: CustomPaint(
                size: Size.infinite,
                painter: SDFRayMarchPainter(
                  metaballs: _metaballs,
                  cameraPosition: _cameraPosition,
                  cameraTarget: _cameraTarget,
                  time: _time,
                  isRigidMode: _isRigidMode,
                  smoothUnionK: _smoothUnionK,
                ),
              ),
            ),
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(178),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Controls:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'WASD: Move camera',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text(
                      'Click: Add metaball',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text(
                      'Drag: Move metaball',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text(
                      'Double-tap: Color picker',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Text(
                      'Shift+Drag: Rotate view',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'Physics: ',
                          style: TextStyle(color: Colors.white),
                        ),
                        Switch(
                          value: _isRigidMode,
                          onChanged: (value) =>
                              setState(() => _isRigidMode = value),
                          activeThumbColor: Colors.blue,
                        ),
                        Text(
                          _isRigidMode ? 'Rigid' : 'Soft',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    if (!_isRigidMode) ...[
                      const Text(
                        'Smooth Union K:',
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(
                        width: 200,
                        child: Slider(
                          value: _smoothUnionK,
                          min: 0.1,
                          max: 2.0,
                          onChanged: (value) =>
                              setState(() => _smoothUnionK = value),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SDFRayMarchPainter extends CustomPainter {
  final List<SDFMetaball> metaballs;
  final vec.Vector3 cameraPosition;
  final vec.Vector3 cameraTarget;
  final double time;
  final bool isRigidMode;
  final double smoothUnionK;
  SDFRayMarchPainter({
    required this.metaballs,
    required this.cameraPosition,
    required this.cameraTarget,
    required this.time,
    required this.isRigidMode,
    required this.smoothUnionK,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final gpu.Texture renderTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(0.02, 0.02, 0.05, 1.0),
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final vertex = shaderLibrary['SDFRayMarchVertex']!;
    final fragment = shaderLibrary['SDFRayMarchFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);
    pass.bindPipeline(pipeline);
    final transients = gpu.gpuContext.createHostBuffer();
    final vertices = transients.emplace(
      float32([
        -1.0,
        -1.0,
        0.0,
        0.0,
        1.0,
        -1.0,
        1.0,
        0.0,
        1.0,
        1.0,
        1.0,
        1.0,
        -1.0,
        -1.0,
        0.0,
        0.0,
        1.0,
        1.0,
        1.0,
        1.0,
        -1.0,
        1.0,
        0.0,
        1.0,
      ]),
    );
    pass.bindVertexBuffer(vertices, 6);
    final sceneData = <double>[
      cameraPosition.x,
      cameraPosition.y,
      cameraPosition.z,
      0.0,
      size.width,
      size.height,
      0.0,
      0.0,
      time,
      smoothUnionK,
      isRigidMode ? 1.0 : 0.0,
      metaballs.length.toDouble(),
    ];
    for (int i = 0; i < 16; i++) {
      if (i < metaballs.length) {
        final metaball = metaballs[i];
        sceneData.addAll([
          metaball.position.x,
          metaball.position.y,
          metaball.position.z,
          metaball.radius,
          metaball.color.x,
          metaball.color.y,
          metaball.color.z,
          metaball.temperature,
        ]);
      } else {
        sceneData.addAll([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
      }
    }
    final sceneInfoSlot = vertex.getUniformSlot('SceneInfo');
    final sceneInfoView = transients.emplace(float32(sceneData));
    pass.bindUniform(sceneInfoSlot, sceneInfoView);
    pass.draw();
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant SDFRayMarchPainter oldDelegate) => true;
}

class FlexWorldGamePage extends StatefulWidget {
  const FlexWorldGamePage({super.key});
  @override
  State<FlexWorldGamePage> createState() => _FlexWorldGamePageState();
}

class _FlexWorldGamePageState extends State<FlexWorldGamePage>
    with TickerProviderStateMixin {
  late Ticker _ticker;
  late FocusNode _focusNode;
  double _gameTime = 0;
  final GameWorld _world = GameWorld();
  final Player _player = Player();
  final CameraController _cameraController = CameraController();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  double _zoomDelta = 0.0;
  bool _is3DMode = true;
  PhysicsMode _physicsMode = PhysicsMode.rigid;
  double _worldRotation = 0.0;
  int _collectedItems = 0;
  final int _totalItems = 15;
  bool _gameComplete = false;
  final List<Particle> _particles = [];
  final List<DynamicLight> _lights = [];
  static const Color customGold = Color(0xFFFFD700);
  bool _hudVisible = true;
  bool _hudMinimized = false;
  Offset _hudPosition = const Offset(20, 20);
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _initializeGame();
    _ticker = createTicker((elapsed) {
      final deltaTime = elapsed.inMilliseconds / 1000.0 - _gameTime;
      _gameTime = elapsed.inMilliseconds / 1000.0;
      _updateGame(deltaTime);
      setState(() {});
    })..start();
  }

  void _initializeGame() {
    _world.platforms.addAll([
      Platform(
        vec.Vector3(-8, -2, 0),
        vec.Vector3(16, 0.5, 1),
        const Color(0xFF8B4513),
      ),
      Platform(
        vec.Vector3(-6, -1, 2),
        vec.Vector3(3, 0.3, 1),
        const Color(0xFF228B22),
      ),
      Platform(
        vec.Vector3(-2, 0, 4),
        vec.Vector3(4, 0.3, 1),
        const Color(0xFF1E90FF),
      ),
      Platform(
        vec.Vector3(2, 1, 6),
        vec.Vector3(3, 0.3, 1),
        const Color(0xFF9932CC),
      ),
      Platform(
        vec.Vector3(6, -1, 8),
        vec.Vector3(2, 0.3, 1),
        const Color(0xFFFF6347),
      ),
      Platform(
        vec.Vector3(-4, 2, 1),
        vec.Vector3(2, 0.3, 1),
        const Color(0xFFFF8C00),
      ),
      Platform(
        vec.Vector3(0, 3, 3),
        vec.Vector3(3, 0.3, 1),
        const Color(0xFFDC143C),
      ),
      Platform(
        vec.Vector3(4, 2.5, 5),
        vec.Vector3(2, 0.3, 1),
        const Color(0xFF00CED1),
      ),
      Platform(
        vec.Vector3(-2, 4, 7),
        vec.Vector3(2, 0.3, 1),
        const Color(0xFFFFD700),
      ),
      Platform(
        vec.Vector3(0, 1, -3),
        vec.Vector3(3, 0.3, 1),
        const Color(0xFF9370DB),
      ),
      Platform(
        vec.Vector3(3, 3, -5),
        vec.Vector3(2, 0.3, 1),
        const Color(0xFF20B2AA),
      ),
    ]);
    _world.collectibles.addAll([
      Collectible(
        vec.Vector3(-5, -0.5, 0),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(-3, 0.5, 2),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(1, 1.5, 4),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(3, 2, 6),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(-2, 2.5, 1),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(0, 3.5, 3),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(4, 3, 5),
        const Color(0xFFFFD700),
        CollectibleType.coin,
      ),
      Collectible(
        vec.Vector3(-1, 2, -3),
        const Color(0xFF00FF7F),
        CollectibleType.gem,
      ),
      Collectible(
        vec.Vector3(2, 1, -8),
        const Color(0xFF00FF7F),
        CollectibleType.gem,
      ),
      Collectible(
        vec.Vector3(-3, 3, -6),
        const Color(0xFF00FF7F),
        CollectibleType.gem,
      ),
      Collectible(
        vec.Vector3(1, 4, -4),
        const Color(0xFF00FF7F),
        CollectibleType.gem,
      ),
      Collectible(
        vec.Vector3(5, 2, -7),
        const Color(0xFF00FF7F),
        CollectibleType.gem,
      ),
      Collectible(
        vec.Vector3(-1, 5, 7),
        const Color(0xFFFF1493),
        CollectibleType.powerup,
      ),
      Collectible(
        vec.Vector3(2, 3, -2),
        const Color(0xFFFF1493),
        CollectibleType.powerup,
      ),
      Collectible(
        vec.Vector3(-4, 1, 9),
        const Color(0xFFFF1493),
        CollectibleType.powerup,
      ),
    ]);
    _world.physicsObjects.addAll([
      PhysicsObject(
        vec.Vector3(-2, 1, 1),
        PhysicsMode.rigid,
        const Color(0xFFFF4500),
      ),
      PhysicsObject(
        vec.Vector3(1.5, 2, 3),
        PhysicsMode.soft,
        const Color(0xFFFF69B4),
      ),
      PhysicsObject(
        vec.Vector3(3.5, 3, 5),
        PhysicsMode.rigid,
        const Color(0xFF4169E1),
      ),
      PhysicsObject(
        vec.Vector3(-1, 3, 7),
        PhysicsMode.soft,
        const Color(0xFF32CD32),
      ),
      PhysicsObject(
        vec.Vector3(0, 1, -2),
        PhysicsMode.rigid,
        const Color(0xFFFFD700),
      ),
    ]);
    _lights.clear();
    _lights.addAll([
      DynamicLight(
        vec.Vector3(0, 5, 0),
        const Color(0xFFFFFFFF),
        10.0,
        LightType.point,
      ),
      DynamicLight(
        vec.Vector3(-5, 3, 2),
        const Color(0xFFFF6B6B),
        8.0,
        LightType.point,
      ),
      DynamicLight(
        vec.Vector3(5, 3, 6),
        const Color(0xFF4ECDC4),
        8.0,
        LightType.point,
      ),
      DynamicLight(
        vec.Vector3(0, 2, -4),
        const Color(0xFF45B7D1),
        6.0,
        LightType.point,
      ),
    ]);
    _player.position = vec.Vector3(-6, 0, 0);
    _cameraController.reset();
    _worldRotation = 0.0;
    _particles.clear();
  }

  void _updateGame(double deltaTime) {
    if (_gameComplete) return;
    _handleInput(deltaTime);
    _updatePlayer(deltaTime);
    _updatePhysics(deltaTime);
    _updateCamera(deltaTime);
    _updateParticles(deltaTime);
    _updateLights(deltaTime);
    _checkCollisions();
    _updateCollectibles(deltaTime);
    if (_collectedItems >= _totalItems) {
      _gameComplete = true;
    }
  }

  void _handleInput(double deltaTime) {
    const moveSpeed = 6.0;
    const jumpForce = 12.0;
    const cameraSpeed = 3.0;
    vec.Vector3 movement = vec.Vector3.zero();
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      movement.x -= moveSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      movement.x += moveSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW) && _is3DMode) {
      final forward = _cameraController.getForwardDirection();
      movement += forward * moveSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS) && _is3DMode) {
      final forward = _cameraController.getForwardDirection();
      movement -= forward * moveSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
      _cameraController.orbit.x -= cameraSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
      _cameraController.orbit.x += cameraSpeed * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
      _cameraController.orbit.y =
          (_cameraController.orbit.y - cameraSpeed * deltaTime).clamp(
            0.1,
            pi - 0.1,
          );
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
      _cameraController.orbit.y =
          (_cameraController.orbit.y + cameraSpeed * deltaTime).clamp(
            0.1,
            pi - 0.1,
          );
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyQ)) {
      _zoomDelta += 2.0 * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyE)) {
      _zoomDelta -= 2.0 * deltaTime;
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.space) && _player.isGrounded) {
      _player.velocity.y = jumpForce;
      _player.isGrounded = false;
      _createJumpParticles();
    }
    _player.velocity.x = movement.x / deltaTime * 0.7;
    if (_is3DMode) {
      _player.velocity.z = movement.z / deltaTime * 0.7;
    }
  }

  void _updatePlayer(double deltaTime) {
    _player.velocity.y -= 20.0 * deltaTime;
    _player.position.add(_player.velocity * deltaTime);
    if (_player.position.y < -1.5) {
      _player.position.y = -1.5;
      if (_player.velocity.y < -5.0) {
        _createLandingParticles();
      }
      _player.velocity.y = 0;
      _player.isGrounded = true;
    }
    for (var platform in _world.platforms) {
      if (_checkPlayerPlatformCollision(platform)) {
        _player.position.y = platform.position.y + platform.size.y + 0.5;
        if (_player.velocity.y < -3.0) {
          _createLandingParticles();
        }
        _player.velocity.y = 0;
        _player.isGrounded = true;
        break;
      }
    }
  }

  bool _checkPlayerPlatformCollision(Platform platform) {
    final playerBottom = _player.position.y - 0.5;
    final platformTop = platform.position.y + platform.size.y;
    return playerBottom <= platformTop &&
        playerBottom >= platformTop - 0.6 &&
        _player.position.x > platform.position.x - platform.size.x &&
        _player.position.x < platform.position.x + platform.size.x &&
        _player.position.z > platform.position.z - platform.size.z &&
        _player.position.z < platform.position.z + platform.size.z;
  }

  void _updatePhysics(double deltaTime) {
    for (var obj in _world.physicsObjects) {
      obj.update(deltaTime, _physicsMode);
      if (_physicsMode == PhysicsMode.soft && obj.jiggleFactor.abs() > 0.05) {
        if (Random().nextDouble() < 0.3) {
          _createPhysicsParticles(obj.position, obj.color);
        }
      }
    }
  }

  void _updateCamera(double deltaTime) {
    if (_is3DMode) {
      _cameraController.update3D(deltaTime, _player.position);
    } else {
      _cameraController.update2D(deltaTime, _player.position, _worldRotation);
    }
    if (_zoomDelta.abs() > 0.001) {
      _cameraController.distance = (_cameraController.distance + _zoomDelta)
          .clamp(3.0, 25.0);
      _zoomDelta *= 0.85;
    } else {
      _zoomDelta = 0.0;
    }
  }

  void _updateParticles(double deltaTime) {
    _particles.removeWhere((particle) => particle.update(deltaTime));
  }

  void _updateLights(double deltaTime) {
    for (int i = 0; i < _lights.length; i++) {
      final light = _lights[i];
      light.position.y += sin(_gameTime * 2 + i) * 0.1;
      light.intensity = 8.0 + sin(_gameTime * 3 + i * 0.7) * 2.0;
    }
  }

  void _checkCollisions() {
    _world.collectibles.removeWhere((collectible) {
      final distance = (_player.position - collectible.position).length;
      if (distance < 1.2) {
        _collectedItems++;
        _createCollectionParticles(collectible.position, collectible.color);
        return true;
      }
      return false;
    });
  }

  void _updateCollectibles(double deltaTime) {
    for (var collectible in _world.collectibles) {
      collectible.rotation +=
          deltaTime * (collectible.type == CollectibleType.gem ? 3.0 : 2.0);
      collectible.bobOffset =
          sin(_gameTime * 4 + collectible.position.x * 0.5) * 0.3;
    }
  }

  void _createJumpParticles() {
    for (int i = 0; i < 8; i++) {
      _particles.add(
        Particle(
          position: _player.position + vec.Vector3(0, -0.5, 0),
          velocity: vec.Vector3(
            (Random().nextDouble() - 0.5) * 4,
            Random().nextDouble() * 2,
            (Random().nextDouble() - 0.5) * 4,
          ),
          color: const Color(0xFFE0E0E0),
          life: 1.0,
        ),
      );
    }
  }

  void _createLandingParticles() {
    for (int i = 0; i < 12; i++) {
      _particles.add(
        Particle(
          position: _player.position + vec.Vector3(0, -0.5, 0),
          velocity: vec.Vector3(
            (Random().nextDouble() - 0.5) * 6,
            Random().nextDouble() * 4,
            (Random().nextDouble() - 0.5) * 6,
          ),
          color: const Color(0xFF8B4513),
          life: 1.5,
        ),
      );
    }
  }

  void _createPhysicsParticles(vec.Vector3 position, Color color) {
    for (int i = 0; i < 3; i++) {
      _particles.add(
        Particle(
          position: position,
          velocity: vec.Vector3(
            (Random().nextDouble() - 0.5) * 2,
            Random().nextDouble() * 2,
            (Random().nextDouble() - 0.5) * 2,
          ),
          color: color,
          life: 0.8,
        ),
      );
    }
  }

  void _createCollectionParticles(vec.Vector3 position, Color color) {
    for (int i = 0; i < 15; i++) {
      _particles.add(
        Particle(
          position: position,
          velocity: vec.Vector3(
            (Random().nextDouble() - 0.5) * 8,
            Random().nextDouble() * 6 + 2,
            (Random().nextDouble() - 0.5) * 8,
          ),
          color: color,
          life: 2.0,
        ),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        setState(() => _is3DMode = !_is3DMode);
      }
      if (event.logicalKey == LogicalKeyboardKey.keyP) {
        setState(() {
          _physicsMode = _physicsMode == PhysicsMode.rigid
              ? PhysicsMode.soft
              : PhysicsMode.rigid;
          for (var obj in _world.physicsObjects) {
            _createPhysicsParticles(obj.position, obj.color);
          }
        });
      }
      if (event.logicalKey == LogicalKeyboardKey.keyH) {
        setState(() => _hudVisible = !_hudVisible);
      }
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        setState(() => _hudMinimized = !_hudMinimized);
      }
      if (event.logicalKey == LogicalKeyboardKey.keyU) {
        setState(() => _hudPosition = const Offset(20, 20));
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _resetGame();
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
  }

  void _resetGame() {
    setState(() {
      _gameComplete = false;
      _collectedItems = 0;
      _initializeGame();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _cameraController.orbit.x += details.delta.dx * 0.01;
              _cameraController.orbit.y =
                  (_cameraController.orbit.y - details.delta.dy * 0.01).clamp(
                    0.1,
                    pi - 0.1,
                  );
            });
          },
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                setState(() {
                  _zoomDelta += event.scrollDelta.dy * 0.001;
                });
              }
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: EnhancedFlexWorldPainter(
                      world: _world,
                      player: _player,
                      camera: _cameraController,
                      particles: _particles,
                      lights: _lights,
                      gameTime: _gameTime,
                      is3DMode: _is3DMode,
                      physicsMode: _physicsMode,
                      worldRotation: _worldRotation,
                    ),
                  ),
                ),
                if (_hudVisible)
                  Positioned(
                    left: _hudPosition.dx,
                    top: _hudPosition.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _hudPosition = Offset(
                            (_hudPosition.dx + details.delta.dx).clamp(
                              0.0,
                              MediaQuery.of(context).size.width - 300,
                            ),
                            (_hudPosition.dy + details.delta.dy).clamp(
                              0.0,
                              MediaQuery.of(context).size.height - 400,
                            ),
                          );
                        });
                      },
                      child: DynamicGameHUD(
                        is3DMode: _is3DMode,
                        physicsMode: _physicsMode,
                        collectedItems: _collectedItems,
                        totalItems: _totalItems,
                        gameComplete: _gameComplete,
                        worldRotation: _worldRotation,
                        isMinimized: _hudMinimized,
                        onMinimize: () =>
                            setState(() => _hudMinimized = !_hudMinimized),
                        onClose: () => setState(() => _hudVisible = false),
                      ),
                    ),
                  ),
                if (_gameComplete)
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      color: Colors.black.withAlpha(204),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              duration: const Duration(seconds: 2),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Text(
                                    'CONGRATULATIONS!',
                                    style: TextStyle(
                                      color: Color.lerp(
                                        Colors.amber,
                                        customGold,
                                        value,
                                      ),
                                      fontSize: 48 + (value * 12),
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.amber.withAlpha(
                                            (value * 255).round(),
                                          ),
                                          blurRadius: 10 + (value * 10),
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Master of FlexWorld!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Items Collected: $_collectedItems/$_totalItems',
                              style: const TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Press R to conquer again',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PhysicsMode { rigid, soft }

enum CollectibleType { coin, gem, powerup }

enum LightType { directional, point, spot }

class GameWorld {
  final List<Platform> platforms = [];
  final List<Collectible> collectibles = [];
  final List<PhysicsObject> physicsObjects = [];
}

class Player {
  vec.Vector3 position = vec.Vector3.zero();
  vec.Vector3 velocity = vec.Vector3.zero();
  bool isGrounded = false;
  Color color = const Color(0xFF4169E1);
}

class CameraController {
  vec.Vector3 position = vec.Vector3.zero();
  vec.Vector3 target = vec.Vector3.zero();
  vec.Vector3 orbit = vec.Vector3(0, pi / 4, 0);
  double distance = 10.0;
  void reset() {
    position = vec.Vector3(-4, 4, 12);
    target = vec.Vector3.zero();
    orbit = vec.Vector3(0, pi / 4, 0);
    distance = 10.0;
  }

  vec.Vector3 getForwardDirection() {
    final forward = vec.Vector3(
      -sin(orbit.x) * sin(orbit.y),
      0,
      -cos(orbit.x) * sin(orbit.y),
    );
    return forward.normalized();
  }

  void update3D(double deltaTime, vec.Vector3 playerPos) {
    target = playerPos + vec.Vector3(0, 1, 0);
    position =
        vec.Vector3(
          distance * sin(orbit.x) * sin(orbit.y),
          distance * cos(orbit.y),
          distance * cos(orbit.x) * sin(orbit.y),
        ) +
        target;
  }

  void update2D(double deltaTime, vec.Vector3 playerPos, double worldRotation) {
    final rotatedOffset = vec.Vector3(
      8.0 * cos(worldRotation),
      4.0,
      8.0 * sin(worldRotation),
    );
    final targetPos = playerPos + rotatedOffset;
    final newPos = vec.Vector3.zero();
    vec.Vector3.mix(position, targetPos, 3.0 * deltaTime, newPos);
    position = newPos;
    target = playerPos + vec.Vector3(0, 1, 0);
  }
}

class Platform {
  final vec.Vector3 position;
  final vec.Vector3 size;
  final Color color;
  Platform(this.position, this.size, this.color);
}

class Collectible {
  final vec.Vector3 position;
  final Color color;
  final CollectibleType type;
  double rotation = 0;
  double bobOffset = 0;
  Collectible(this.position, this.color, this.type);
}

class PhysicsObject {
  final vec.Vector3 position;
  PhysicsMode mode;
  final Color color;
  double jiggleFactor = 0;
  double phase = Random().nextDouble() * 2 * pi;
  PhysicsObject(this.position, this.mode, this.color);
  void update(double deltaTime, PhysicsMode globalMode) {
    if (mode == PhysicsMode.soft || globalMode == PhysicsMode.soft) {
      jiggleFactor =
          sin(deltaTime * 15 + phase) * 0.2 + cos(deltaTime * 12 + phase) * 0.1;
    } else {
      jiggleFactor = 0;
    }
  }
}

class Particle {
  vec.Vector3 position;
  vec.Vector3 velocity;
  Color color;
  double life;
  double maxLife;
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
  }) : maxLife = life;
  bool update(double deltaTime) {
    position.add(velocity * deltaTime);
    velocity.y -= 9.8 * deltaTime;
    velocity *= 0.98;
    life -= deltaTime;
    return life <= 0;
  }

  double get alpha => (life / maxLife).clamp(0.0, 1.0);
}

class DynamicLight {
  vec.Vector3 position;
  Color color;
  double intensity;
  LightType type;
  DynamicLight(this.position, this.color, this.intensity, this.type);
}

class DynamicGameHUD extends StatelessWidget {
  final bool is3DMode;
  final PhysicsMode physicsMode;
  final int collectedItems;
  final int totalItems;
  final bool gameComplete;
  final double worldRotation;
  final bool isMinimized;
  final VoidCallback onMinimize;
  final VoidCallback onClose;
  const DynamicGameHUD({
    required this.is3DMode,
    required this.physicsMode,
    required this.collectedItems,
    required this.totalItems,
    required this.gameComplete,
    required this.worldRotation,
    required this.isMinimized,
    required this.onMinimize,
    required this.onClose,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isMinimized ? 200 : 320,
      height: isMinimized ? 60 : (is3DMode ? 280 : 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withAlpha(229), Colors.black.withAlpha(178)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: is3DMode
              ? Colors.cyan.withAlpha(127)
              : Colors.orange.withAlpha(127),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    is3DMode ? 'FLEXWORLD 3D' : 'FLEXWORLD 2D',
                    style: TextStyle(
                      color: is3DMode ? Colors.cyan : Colors.orange,
                      fontSize: isMinimized ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: is3DMode ? Colors.cyan : Colors.orange,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onMinimize,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(76),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isMinimized ? Icons.expand_more : Icons.expand_less,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(76),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isMinimized) ...[
              const SizedBox(height: 12),
              _buildStatusRow(
                'Mode',
                is3DMode ? "3D Explorer" : "2D Platformer",
                is3DMode ? Colors.lightBlue : Colors.orange,
              ),
              _buildStatusRow(
                'Physics',
                physicsMode == PhysicsMode.rigid ? "Rigid" : "Soft",
                physicsMode == PhysicsMode.rigid ? Colors.red : Colors.pink,
              ),
              _buildStatusRow(
                'Items',
                '$collectedItems/$totalItems',
                Colors.yellow,
              ),
              if (!is3DMode)
                _buildStatusRow(
                  'World Rotation',
                  '${(worldRotation * 180 / pi).round()}',
                  Colors.purple,
                ),
              const SizedBox(height: 16),
              Text(
                '${is3DMode ? "3D" : "2D"} Controls:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              if (is3DMode) ...[
                _buildControlRow('WASD', 'Move & Strafe'),
                _buildControlRow('Mouse Drag', 'Free Look Camera'),
                _buildControlRow('Scroll/Q/E', 'Zoom In/Out'),
                _buildControlRow('Arrow Keys', 'Precise Camera'),
                _buildControlRow('SPACE', 'Jump'),
              ] else ...[
                _buildControlRow('A/D', 'Move Left/Right'),
                _buildControlRow('Q/E', 'Zoom In/Out'),
                _buildControlRow('SPACE', 'Jump'),
                _buildControlRow('Mouse Drag', 'Orbit Camera'),
              ],
              const Divider(color: Colors.grey, height: 16),
              _buildControlRow('TAB', 'Toggle 2D/3D'),
              _buildControlRow('P', 'Toggle Physics'),
              _buildControlRow('H', 'Toggle HUD'),
              _buildControlRow('M', 'Minimize HUD'),
              _buildControlRow('U', 'Reset HUD Position'),
              _buildControlRow('R', 'Reset Game'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[300], fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(String key, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              action,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class EnhancedFlexWorldPainter extends CustomPainter {
  final GameWorld world;
  final Player player;
  final CameraController camera;
  final List<Particle> particles;
  final List<DynamicLight> lights;
  final double gameTime;
  final bool is3DMode;
  final PhysicsMode physicsMode;
  final double worldRotation;
  EnhancedFlexWorldPainter({
    required this.world,
    required this.player,
    required this.camera,
    required this.particles,
    required this.lights,
    required this.gameTime,
    required this.is3DMode,
    required this.physicsMode,
    required this.worldRotation,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final gpuContext = gpu.gpuContext;
    final renderTexture = gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      size.width.toInt(),
      size.height.toInt(),
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final depthTexture = gpuContext.createTexture(
      gpu.StorageMode.deviceTransient,
      size.width.toInt(),
      size.height.toInt(),
      format: gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture,
    );
    final commandBuffer = gpuContext.createCommandBuffer();
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: renderTexture,
        clearValue: vec.Vector4(
          0.05 + sin(gameTime * 0.5) * 0.02,
          0.1 + sin(gameTime * 0.3) * 0.03,
          0.2 + sin(gameTime * 0.7) * 0.05,
          1.0,
        ),
      ),
      depthStencilAttachment: gpu.DepthStencilAttachment(
        texture: depthTexture,
        depthClearValue: 1.0,
      ),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);
    final vertex = shaderLibrary['GameSceneVertex']!;
    final fragment = shaderLibrary['GameSceneFragment']!;
    final pipeline = gpuContext.createRenderPipeline(vertex, fragment);
    pass.bindPipeline(pipeline);
    pass.setDepthWriteEnable(true);
    pass.setDepthCompareOperation(gpu.CompareFunction.less);
    vec.Matrix4 worldRotationMatrix = vec.Matrix4.rotationY(worldRotation);
    final viewMatrix = vec.makeViewMatrix(
      camera.position,
      camera.target,
      vec.Vector3(0, 1, 0),
    );
    final projectionMatrix = vec.makePerspectiveMatrix(
      is3DMode ? pi / 3 : pi / 4,
      size.width / size.height,
      0.1,
      100.0,
    );
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    final transients = gpuContext.createHostBuffer();
    final lightInfoSlot = fragment.getUniformSlot('LightInfo');
    final primaryLight = lights.isNotEmpty
        ? lights[0]
        : DynamicLight(
            vec.Vector3(5, 10, 5),
            Colors.white,
            10.0,
            LightType.point,
          );
    final lightInfoData = Float32List.fromList([
      primaryLight.position.x,
      primaryLight.position.y,
      primaryLight.position.z,
      0.0,
      primaryLight.color.r,
      primaryLight.color.g,
      primaryLight.color.b,
      primaryLight.intensity / 10.0,
      0.2 + sin(gameTime * 0.5) * 0.1,
      0.2 + sin(gameTime * 0.7) * 0.1,
      0.3 + sin(gameTime * 0.3) * 0.1,
      1.0,
    ]);
    final lightInfoView = transients.emplace(lightInfoData.buffer.asByteData());
    pass.bindUniform(lightInfoSlot, lightInfoView);
    final frameInfoSlot = vertex.getUniformSlot('FrameInfo');
    for (var platform in world.platforms) {
      final modelMatrix =
          worldRotationMatrix *
          vec.Matrix4.translation(platform.position) *
          vec.Matrix4.diagonal3(platform.size);
      final mvp = viewProjectionMatrix * modelMatrix;
      final vertices = _createEnhancedCubeVertices(platform.color);
      final indices = _createCubeIndices();
      final vertexBuffer = transients.emplace(vertices);
      final indexBuffer = transients.emplace(indices);
      final uniformData = <double>[...mvp.storage, gameTime, 0.0];
      final frameInfoView = transients.emplace(float32(uniformData));
      pass.bindVertexBuffer(vertexBuffer, 24);
      pass.bindIndexBuffer(indexBuffer, gpu.IndexType.int16, 36);
      pass.bindUniform(frameInfoSlot, frameInfoView);
      pass.draw();
    }
    final playerScale =
        1.0 + (player.isGrounded ? 0.0 : sin(gameTime * 8) * 0.1);
    final playerModelMatrix =
        worldRotationMatrix *
        vec.Matrix4.translation(player.position) *
        vec.Matrix4.diagonal3(
          vec.Vector3(0.5 * playerScale, 1.0 * playerScale, 0.5 * playerScale),
        );
    final playerMvp = viewProjectionMatrix * playerModelMatrix;
    final playerVertices = _createEnhancedCubeVertices(player.color);
    final playerVertexBuffer = transients.emplace(playerVertices);
    final playerIndexBuffer = transients.emplace(_createCubeIndices());
    final playerUniformData = <double>[
      ...playerMvp.storage,
      gameTime,
      player.isGrounded ? 0.0 : 1.0,
    ];
    final playerFrameInfoView = transients.emplace(float32(playerUniformData));
    pass.bindVertexBuffer(playerVertexBuffer, 24);
    pass.bindIndexBuffer(playerIndexBuffer, gpu.IndexType.int16, 36);
    pass.bindUniform(frameInfoSlot, playerFrameInfoView);
    pass.draw();
    for (var collectible in world.collectibles) {
      if (!is3DMode &&
          collectible.position.z.abs() > 3.0 &&
          collectible.type != CollectibleType.gem) {
        continue;
      }
      final bobPos =
          collectible.position + vec.Vector3(0, collectible.bobOffset, 0);
      double scale = 0.4;
      double animState = 0.0;
      switch (collectible.type) {
        case CollectibleType.coin:
          scale = 0.3 + sin(gameTime * 6 + collectible.position.x) * 0.05;
          break;
        case CollectibleType.gem:
          scale = 0.4 + sin(gameTime * 4 + collectible.position.y) * 0.08;
          animState = 1.0;
          break;
        case CollectibleType.powerup:
          scale = 0.5 + sin(gameTime * 8 + collectible.position.z) * 0.1;
          animState = 2.0;
          break;
      }
      final collectibleModelMatrix =
          worldRotationMatrix *
          vec.Matrix4.translation(bobPos) *
          vec.Matrix4.rotationY(collectible.rotation) *
          vec.Matrix4.diagonal3(vec.Vector3(scale, scale, scale));
      final collectibleMvp = viewProjectionMatrix * collectibleModelMatrix;
      final collectibleVertices = _createEnhancedCubeVertices(
        collectible.color,
      );
      final collectibleVertexBuffer = transients.emplace(collectibleVertices);
      final collectibleIndexBuffer = transients.emplace(_createCubeIndices());
      final collectibleUniformData = <double>[
        ...collectibleMvp.storage,
        gameTime,
        animState,
      ];
      final collectibleFrameInfoView = transients.emplace(
        float32(collectibleUniformData),
      );
      pass.bindVertexBuffer(collectibleVertexBuffer, 24);
      pass.bindIndexBuffer(collectibleIndexBuffer, gpu.IndexType.int16, 36);
      pass.bindUniform(frameInfoSlot, collectibleFrameInfoView);
      pass.draw();
    }
    for (var obj in world.physicsObjects) {
      final jiggleScale =
          1.0 + (physicsMode == PhysicsMode.soft ? obj.jiggleFactor : 0.0);
      final objModelMatrix =
          worldRotationMatrix *
          vec.Matrix4.translation(obj.position) *
          vec.Matrix4.diagonal3(
            vec.Vector3(jiggleScale, jiggleScale, jiggleScale),
          );
      final objMvp = viewProjectionMatrix * objModelMatrix;
      final objVertices = _createEnhancedCubeVertices(obj.color);
      final objVertexBuffer = transients.emplace(objVertices);
      final objIndexBuffer = transients.emplace(_createCubeIndices());
      final objAnimState = physicsMode == PhysicsMode.soft
          ? 3.0 + obj.jiggleFactor
          : 0.0;
      final objUniformData = <double>[
        ...objMvp.storage,
        gameTime,
        objAnimState,
      ];
      final objFrameInfoView = transients.emplace(float32(objUniformData));
      pass.bindVertexBuffer(objVertexBuffer, 24);
      pass.bindIndexBuffer(objIndexBuffer, gpu.IndexType.int16, 36);
      pass.bindUniform(frameInfoSlot, objFrameInfoView);
      pass.draw();
    }
    for (var particle in particles) {
      final int ai = (particle.alpha.clamp(0.0, 1.0) * 255).round();
      final int ri = (particle.color.r.clamp(0.0, 1.0) * 255).round();
      final int gi = (particle.color.g.clamp(0.0, 1.0) * 255).round();
      final int bi = (particle.color.b.clamp(0.0, 1.0) * 255).round();
      final particleColor = Color.fromARGB(ai, ri, gi, bi);
      final particleModelMatrix =
          worldRotationMatrix *
          vec.Matrix4.translation(particle.position) *
          vec.Matrix4.diagonal3(vec.Vector3(0.1, 0.1, 0.1));
      final particleMvp = viewProjectionMatrix * particleModelMatrix;
      final particleVertices = _createEnhancedCubeVertices(particleColor);
      final particleVertexBuffer = transients.emplace(particleVertices);
      final particleIndexBuffer = transients.emplace(_createCubeIndices());
      final particleUniformData = <double>[
        ...particleMvp.storage,
        gameTime,
        4.0,
      ];
      final particleFrameInfoView = transients.emplace(
        float32(particleUniformData),
      );
      pass.bindVertexBuffer(particleVertexBuffer, 24);
      pass.bindIndexBuffer(particleIndexBuffer, gpu.IndexType.int16, 36);
      pass.bindUniform(frameInfoSlot, particleFrameInfoView);
      pass.draw();
    }
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  ByteData _createEnhancedCubeVertices(Color color) {
    final r = color.r;
    final g = color.g;
    final b = color.b;
    final a = color.a;
    return float32([
      -1,
      -1,
      1,
      0,
      0,
      1,
      r,
      g,
      b,
      a,
      1,
      -1,
      1,
      0,
      0,
      1,
      r,
      g,
      b,
      a,
      1,
      1,
      1,
      0,
      0,
      1,
      r,
      g,
      b,
      a,
      -1,
      1,
      1,
      0,
      0,
      1,
      r,
      g,
      b,
      a,
      -1,
      -1,
      -1,
      0,
      0,
      -1,
      r * 0.8,
      g * 0.8,
      b * 0.8,
      a,
      -1,
      1,
      -1,
      0,
      0,
      -1,
      r * 0.8,
      g * 0.8,
      b * 0.8,
      a,
      1,
      1,
      -1,
      0,
      0,
      -1,
      r * 0.8,
      g * 0.8,
      b * 0.8,
      a,
      1,
      -1,
      -1,
      0,
      0,
      -1,
      r * 0.8,
      g * 0.8,
      b * 0.8,
      a,
      -1,
      1,
      -1,
      0,
      1,
      0,
      r * 1.2,
      g * 1.2,
      b * 1.2,
      a,
      -1,
      1,
      1,
      0,
      1,
      0,
      r * 1.2,
      g * 1.2,
      b * 1.2,
      a,
      1,
      1,
      1,
      0,
      1,
      0,
      r * 1.2,
      g * 1.2,
      b * 1.2,
      a,
      1,
      1,
      -1,
      0,
      1,
      0,
      r * 1.2,
      g * 1.2,
      b * 1.2,
      a,
      -1,
      -1,
      -1,
      0,
      -1,
      0,
      r * 0.5,
      g * 0.5,
      b * 0.5,
      a,
      1,
      -1,
      -1,
      0,
      -1,
      0,
      r * 0.5,
      g * 0.5,
      b * 0.5,
      a,
      1,
      -1,
      1,
      0,
      -1,
      0,
      r * 0.5,
      g * 0.5,
      b * 0.5,
      a,
      -1,
      -1,
      1,
      0,
      -1,
      0,
      r * 0.5,
      g * 0.5,
      b * 0.5,
      a,
      1,
      -1,
      -1,
      1,
      0,
      0,
      r * 1.1,
      g * 1.1,
      b * 1.1,
      a,
      1,
      1,
      -1,
      1,
      0,
      0,
      r * 1.1,
      g * 1.1,
      b * 1.1,
      a,
      1,
      1,
      1,
      1,
      0,
      0,
      r * 1.1,
      g * 1.1,
      b * 1.1,
      a,
      1,
      -1,
      1,
      1,
      0,
      0,
      r * 1.1,
      g * 1.1,
      b * 1.1,
      a,
      -1,
      -1,
      -1,
      -1,
      0,
      0,
      r * 0.9,
      g * 0.9,
      b * 0.9,
      a,
      -1,
      -1,
      1,
      -1,
      0,
      0,
      r * 0.9,
      g * 0.9,
      b * 0.9,
      a,
      -1,
      1,
      1,
      -1,
      0,
      0,
      r * 0.9,
      g * 0.9,
      b * 0.9,
      a,
      -1,
      1,
      -1,
      -1,
      0,
      0,
      r * 0.9,
      g * 0.9,
      b * 0.9,
      a,
    ]);
  }

  ByteData _createCubeIndices() {
    return uint16([
      0,
      1,
      2,
      2,
      3,
      0,
      4,
      5,
      6,
      6,
      7,
      4,
      8,
      9,
      10,
      10,
      11,
      8,
      12,
      13,
      14,
      14,
      15,
      12,
      16,
      17,
      18,
      18,
      19,
      16,
      20,
      21,
      22,
      22,
      23,
      20,
    ]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
