import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_gpu/gpu.dart' as gpu;

import 'shaders.dart';

ByteData float32(List<double> values) {
  return Float32List.fromList(values).buffer.asByteData();
}

ByteData float32Mat(Matrix4 matrix) {
  return Float32List.fromList(matrix.storage).buffer.asByteData();
}


class ColorsPainter extends CustomPainter {
  ColorsPainter(this.red, this.green, this.blue);

  double red;
  double green;
  double blue;

  @override
  void paint(Canvas canvas, Size size) {
    /// Allocate a new renderable texture.
    final gpu.Texture? texture =
        gpu.gpuContext.createTexture(gpu.StorageMode.devicePrivate, 300, 300);

    final vertex = shaderLibrary['ColorsVertex']!;
    final fragment = shaderLibrary['ColorsFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);

    final gpu.DeviceBuffer? vertexBuffer = gpu.gpuContext
        .createDeviceBuffer(gpu.StorageMode.hostVisible, 4 * 6 * 3);
    vertexBuffer!.overwrite(Float32List.fromList(<double>[
      -0.5, -0.5,  1.0*red, 0.0, 0.0, 1.0, //
       0,    0.5,  0.0, 1.0*green, 0.0, 1.0, //
       0.5, -0.5,  0.0, 0.0, 1.0*blue, 1.0, //
    ]).buffer.asByteData());

    final commandBuffer = gpu.gpuContext.createCommandBuffer();

    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: texture!),
    );
    final pass = commandBuffer.createRenderPass(renderTarget);

    pass.bindPipeline(pipeline);
    pass.bindVertexBuffer(
        gpu.BufferView(vertexBuffer,
            offsetInBytes: 0, lengthInBytes: vertexBuffer.sizeInBytes), 3);
    pass.draw();

    commandBuffer.submit();

    /// Wrap the Flutter GPU texture as a ui.Image and draw it like normal!
    final image = texture.asImage();

    canvas.drawImage(image, Offset(-texture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ColorsPage extends StatefulWidget {
  const ColorsPage({super.key});

  @override
  State<ColorsPage> createState() => _ColorsPageState();
}

class _ColorsPageState extends State<ColorsPage> {
  Ticker? tick;
  double time = 0;
  double deltaSeconds = 0;
  double red = 1.0;
  double green = 1.0;
  double blue = 1.0;

  @override
  void initState() {
    tick = Ticker(
      (elapsed) {
        setState(() {
          double previousTime = time;
          time = elapsed.inMilliseconds / 1000.0;
          deltaSeconds = previousTime > 0 ? time - previousTime : 0;
        });
      },
    );
    tick!.start();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Slider(
            value: red,
            max: 1,
            min: 0,
            onChanged: (value) => {setState(() => red = value)}),
        Slider(
            value: green,
            max: 1,
            min: 0,
            onChanged: (value) => {setState(() => green = value)}),
        Slider(
            value: blue,
            max: 1,
            min: 0,
            onChanged: (value) => {setState(() => blue = value)}),
        CustomPaint(
          painter: ColorsPainter(red, green, blue),
        ),
      ],
    );
  }
}
