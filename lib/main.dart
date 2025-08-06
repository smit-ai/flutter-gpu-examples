import 'dart:async' show Timer;
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
    final List<double> cubeVertexData = [
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
    final List<int> cubeIndexData = [
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
    final List<double> cubeVertexData = [
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
    final List<int> cubeIndexData = [
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
    final List<double> cubeVertexData = [
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
    final List<int> cubeIndexData = [
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
  vec.Vector4 color;
  bool isRigid;
  double temperature;
  SDFMetaball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.mass,
    required this.color,
    this.isRigid = true,
    this.temperature = 0.0,
  });
}

class SDFPhysicsPage extends StatefulWidget {
  const SDFPhysicsPage({super.key});
  @override
  State<SDFPhysicsPage> createState() => _SDFPhysicsPageState();
}

class _SDFPhysicsPageState extends State<SDFPhysicsPage> {
  final vec.Vector3 _cameraOrbit = vec.Vector3(0.0, 0.5, 0.0);
  final double _cameraDistance = 15.0;
  final FocusNode _focusNode = FocusNode();
  final List<SDFMetaball> _metaballs = [];
  bool _isRigidMode = true;
  double _smoothUnionK = 0.5;
  double _gravityStrength = 9.8;
  final double _dampingFactor = 0.98;
  final double _bounceRestitution = 0.7;
  final double _fluidViscosity = 0.1;
  Ticker? _ticker;
  double _time = 0;
  double _lastFrameTime = 0;
  gpu.RenderPipeline? _pipeline;
  final Random _random = Random();
  @override
  void initState() {
    super.initState();
    _initializeMetaballs();
    _pipeline = gpu.gpuContext.createRenderPipeline(
      shaderLibrary['SDFRayMarchVertex']!,
      shaderLibrary['SDFRayMarchFragment']!,
    );
    _ticker = Ticker(_physicsLoop)..start();
  }

  void _initializeMetaballs() {
    _metaballs.clear();
    for (int i = 0; i < 8; i++) {
      final position = vec.Vector3(
        (_random.nextDouble() - 0.5) * 10,
        _random.nextDouble() * 8 + 2,
        (_random.nextDouble() - 0.5) * 10,
      );
      final velocity = vec.Vector3(
        (_random.nextDouble() - 0.5) * 2,
        0,
        (_random.nextDouble() - 0.5) * 2,
      );
      final color = vec.Vector4(
        _random.nextDouble() * 0.8 + 0.2,
        _random.nextDouble() * 0.8 + 0.2,
        _random.nextDouble() * 0.8 + 0.2,
        1.0,
      );
      _metaballs.add(
        SDFMetaball(
          position: position,
          velocity: velocity,
          radius: _random.nextDouble() * 0.8 + 0.5,
          mass: _random.nextDouble() * 2 + 1,
          color: color,
          isRigid: _isRigidMode,
        ),
      );
    }
  }

  void _physicsLoop(Duration elapsed) {
    if (!mounted) return;
    final currentTime = elapsed.inMilliseconds / 1000.0;
    final deltaTime = (_lastFrameTime == 0)
        ? 0.016
        : (currentTime - _lastFrameTime).clamp(0.0, 0.033);
    _lastFrameTime = currentTime;
    _updatePhysics(deltaTime);
    setState(() {
      _time = currentTime;
    });
  }

  void _updatePhysics(double deltaTime) {
    const double boundarySize = 8.0;
    const double floorY = -2.0;
    for (int i = 0; i < _metaballs.length; i++) {
      final ball = _metaballs[i];
      ball.velocity.y -= _gravityStrength * deltaTime;
      if (!ball.isRigid) {
        _applyFluidForces(ball, deltaTime);
      }
      for (int j = i + 1; j < _metaballs.length; j++) {
        final other = _metaballs[j];
        _applyInterBallForces(ball, other, deltaTime);
      }
      ball.position += ball.velocity * deltaTime;
      _handleBoundaryCollisions(ball, boundarySize, floorY);
      ball.velocity *= _dampingFactor;
      if (!ball.isRigid) {
        ball.temperature = (ball.velocity.length / 10.0).clamp(0.0, 1.0);
      }
    }
  }

  void _applyFluidForces(SDFMetaball ball, double deltaTime) {
    vec.Vector3 fluidForce = vec.Vector3.zero();
    for (final other in _metaballs) {
      if (other == ball) continue;
      final distance = (ball.position - other.position).length;
      final influence = (ball.radius + other.radius) * 2.0;
      if (distance < influence && distance > 0.001) {
        final direction = (ball.position - other.position).normalized();
        final strength = (1.0 - distance / influence) * _fluidViscosity;
        fluidForce += direction * strength * 50.0;
        final velocityDiff = other.velocity - ball.velocity;
        fluidForce += velocityDiff * strength * 10.0;
      }
    }
    ball.velocity += fluidForce * deltaTime;
  }

  void _applyInterBallForces(
    SDFMetaball ball1,
    SDFMetaball ball2,
    double deltaTime,
  ) {
    final distance = (ball1.position - ball2.position).length;
    final minDistance = ball1.radius + ball2.radius;
    if (distance < minDistance && distance > 0.001) {
      final direction = (ball1.position - ball2.position).normalized();
      final overlap = minDistance - distance;
      if (ball1.isRigid && ball2.isRigid) {
        final totalMass = ball1.mass + ball2.mass;
        final force = direction * overlap * 100.0;
        ball1.velocity += force * (ball2.mass / totalMass) * deltaTime;
        ball2.velocity -= force * (ball1.mass / totalMass) * deltaTime;
        final separation = direction * (overlap * 0.5);
        ball1.position += separation;
        ball2.position -= separation;
      } else {
        final force = direction * overlap * 20.0;
        ball1.velocity += force * deltaTime / ball1.mass;
        ball2.velocity -= force * deltaTime / ball2.mass;
      }
    }
  }

  void _handleBoundaryCollisions(
    SDFMetaball ball,
    double boundarySize,
    double floorY,
  ) {
    if (ball.position.y - ball.radius < floorY) {
      ball.position.y = floorY + ball.radius;
      ball.velocity.y = ball.velocity.y.abs() * _bounceRestitution;
    }
    if (ball.position.x.abs() + ball.radius > boundarySize) {
      ball.position.x = ball.position.x.sign * (boundarySize - ball.radius);
      ball.velocity.x *= -_bounceRestitution;
    }
    if (ball.position.z.abs() + ball.radius > boundarySize) {
      ball.position.z = ball.position.z.sign * (boundarySize - ball.radius);
      ball.velocity.z *= -_bounceRestitution;
    }
  }

  void _togglePhysicsMode() {
    setState(() {
      _isRigidMode = !_isRigidMode;
      for (final ball in _metaballs) {
        ball.isRigid = _isRigidMode;
        if (!_isRigidMode) {
          ball.velocity += vec.Vector3(
            (_random.nextDouble() - 0.5) * 2,
            _random.nextDouble() * 2,
            (_random.nextDouble() - 0.5) * 2,
          );
        }
      }
    });
  }

  void _addMetaball(Offset localPosition, Size size) {
    final normalizedX = (localPosition.dx / size.width) * 2 - 1;
    final normalizedY = 1 - (localPosition.dy / size.height) * 2;
    final position = vec.Vector3(normalizedX * 8, normalizedY * 6 + 2, 0);
    final color = vec.Vector4(
      _random.nextDouble() * 0.8 + 0.2,
      _random.nextDouble() * 0.8 + 0.2,
      _random.nextDouble() * 0.8 + 0.2,
      1.0,
    );
    setState(() {
      _metaballs.add(
        SDFMetaball(
          position: position,
          velocity: vec.Vector3(
            (_random.nextDouble() - 0.5) * 4,
            _random.nextDouble() * 2,
            (_random.nextDouble() - 0.5) * 4,
          ),
          radius: _random.nextDouble() * 0.6 + 0.4,
          mass: _random.nextDouble() * 1.5 + 0.5,
          color: color,
          isRigid: _isRigidMode,
        ),
      );
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
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
        Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _togglePhysicsMode,
                    child: Text(
                      _isRigidMode
                          ? 'Switch to Soft Body'
                          : 'Switch to Rigid Body',
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _initializeMetaballs,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Smooth Union: '),
                  Expanded(
                    child: Slider(
                      value: _smoothUnionK,
                      min: 0.1,
                      max: 2.0,
                      onChanged: (value) =>
                          setState(() => _smoothUnionK = value),
                    ),
                  ),
                  const Text('Gravity: '),
                  Expanded(
                    child: Slider(
                      value: _gravityStrength,
                      min: 0.0,
                      max: 20.0,
                      onChanged: (value) =>
                          setState(() => _gravityStrength = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                  _initializeMetaballs();
                }
              }
            },
            child: GestureDetector(
              onTapDown: (details) =>
                  _addMetaball(details.localPosition, context.size!),
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
                painter: SDFRayMarchPainter(
                  pipeline: _pipeline!,
                  metaballs: _metaballs,
                  cameraOrbit: _cameraOrbit,
                  cameraDistance: _cameraDistance,
                  time: _time,
                  smoothUnionK: _smoothUnionK,
                  isRigidMode: _isRigidMode,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SDFRayMarchPainter extends CustomPainter {
  SDFRayMarchPainter({
    required this.pipeline,
    required this.metaballs,
    required this.cameraOrbit,
    required this.cameraDistance,
    required this.time,
    required this.smoothUnionK,
    required this.isRigidMode,
  });
  final gpu.RenderPipeline pipeline;
  final List<SDFMetaball> metaballs;
  final vec.Vector3 cameraOrbit;
  final double cameraDistance;
  final double time;
  final double smoothUnionK;
  final bool isRigidMode;
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
    pass.bindPipeline(pipeline);
    final transients = gpu.gpuContext.createHostBuffer();
    final vertices = transients.emplace(
      float32(<double>[-1, -1, 0, 0, 1, -1, 1, 0, 1, 1, 1, 1, -1, 1, 0, 1]),
    );
    final indices = transients.emplace(uint16(<int>[0, 1, 2, 0, 2, 3]));
    final cameraPosition = vec.Vector3(
      cameraDistance * sin(cameraOrbit.x) * cos(cameraOrbit.y),
      cameraDistance * sin(cameraOrbit.y),
      cameraDistance * cos(cameraOrbit.x) * cos(cameraOrbit.y),
    );
    final metaballData = <double>[];
    for (int i = 0; i < 16; i++) {
      if (i < metaballs.length) {
        final ball = metaballs[i];
        metaballData.addAll([
          ball.position.x,
          ball.position.y,
          ball.position.z,
          ball.radius,
          ball.color.x,
          ball.color.y,
          ball.color.z,
          ball.temperature,
        ]);
      } else {
        metaballData.addAll([0, 0, 0, 0, 0, 0, 0, 0]);
      }
    }
    final sceneUniforms = Float32List.fromList([
      cameraPosition.x,
      cameraPosition.y,
      cameraPosition.z,
      0,
      size.width,
      size.height,
      0,
      0,
      time,
      smoothUnionK,
      isRigidMode ? 1.0 : 0.0,
      metaballs.length.toDouble(),
      ...metaballData,
    ]);
    final sceneUniformsView = transients.emplace(
      sceneUniforms.buffer.asByteData(),
    );
    pass.bindVertexBuffer(vertices, 4);
    pass.bindIndexBuffer(indices, gpu.IndexType.int16, 6);
    final sceneInfoSlot = pipeline.fragmentShader.getUniformSlot('SceneInfo');
    pass.bindUniform(sceneInfoSlot, sceneUniformsView);
    pass.draw();
    commandBuffer.submit();
    final image = renderTexture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant SDFRayMarchPainter oldDelegate) => true;
}
