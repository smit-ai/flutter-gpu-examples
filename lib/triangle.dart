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

class TrianglePainter extends CustomPainter {
  TrianglePainter(this.time, this.seedX, this.seedY);

  double time;
  double seedX;
  double seedY;

  @override
  void paint(Canvas canvas, Size size) {
    /// Allocate a new renderable texture.
    final gpu.Texture? renderTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate, 300, 300,
        enableRenderTargetUsage: true,
        enableShaderReadUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
    if (renderTexture == null) {
      return;
    }

    final gpu.Texture? depthTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.deviceTransient, 300, 300,
        format: gpu.gpuContext.defaultDepthStencilFormat,
        enableRenderTargetUsage: true,
        coordinateSystem: gpu.TextureCoordinateSystem.renderToTexture);
    if (depthTexture == null) {
      return;
    }

    /// Create the command buffer. This will be used to submit all encoded
    /// commands at the end.
    final commandBuffer = gpu.gpuContext.createCommandBuffer();

    /// Define a render target. This is just a collection of attachments that a
    /// RenderPass will write to.
    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(texture: renderTexture),
      depthStencilAttachment: gpu.DepthStencilAttachment(texture: depthTexture),
    );

    /// Add a render pass encoder to the command buffer so that we can start
    /// encoding commands.
    final pass = commandBuffer.createRenderPass(renderTarget);

    /// Create a RenderPipeline using shaders from the asset.
    final vertex = shaderLibrary['UnlitVertex']!;
    final fragment = shaderLibrary['UnlitFragment']!;
    final pipeline = gpu.gpuContext.createRenderPipeline(vertex, fragment);

    pass.bindPipeline(pipeline);

    /// (Optional) Configure blending for the first color attachment.
    pass.setColorBlendEnable(true);
    pass.setColorBlendEquation(gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.one,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha));

    /// Append quick geometry and uniforms to a host buffer that will be
    /// automatically uploaded to the GPU later on.
    final transients = gpu.gpuContext.createHostBuffer();
    final vertices = transients.emplace(float32(<double>[
      -0.5, -0.5, //
      0, 0.5, //
      0.5, -0.5, //
    ]));
    

    /// Bind the vertex data. In this case, we won't bother binding an index
    /// buffer.
    pass.bindVertexBuffer(vertices, 3);

    /* PreVulkanSupport - no longer possible because Vulkan has poor Uniform support
    and we can only do a single blob...
    final color = transients.emplace(float32(<double>[0, 1, 0, 1])); // rgba
    final mvp = transients.emplace(float32Mat(Matrix4(
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0.5, 1, //
        ) *
        Matrix4.rotationX(time) *
        Matrix4.rotationY(time * seedX) *
        Matrix4.rotationZ(time * seedY)));

    /// Bind the host buffer data we just created to the vertex shader's uniform
    /// slots. Although the locations are specified in the shader and are
    /// predictable, we can optionally fetch the uniform slots by name for
    /// convenience.
    final mvpSlot = pipeline.vertexShader.getUniformSlot('mvp')!;
    final colorSlot = pipeline.vertexShader.getUniformSlot('color')!;
    pass.bindUniform(mvpSlot, mvp);
    pass.bindUniform(colorSlot, color);
    PreVulkanSupport */

    final mvp = Matrix4(
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0.5, 1, //
        ) *
        Matrix4.rotationX(time) *
        Matrix4.rotationY(time * seedX) *
        Matrix4.rotationZ(time * seedY);
    final color = <double>[0, 1, 0, 1]; // rgba
    // We must manually map the members of the 'FrameInfo' uniform struct with the
    // corresponding float data
    final frameInfoSlot = vertex.getUniformSlot('FrameInfo');
    final frameInfoFloats = Float32List.fromList([
      mvp.storage[0],
      mvp.storage[1],
      mvp.storage[2],
      mvp.storage[3],
      mvp.storage[4],
      mvp.storage[5],
      mvp.storage[6],
      mvp.storage[7],
      mvp.storage[8],
      mvp.storage[9],
      mvp.storage[10],
      mvp.storage[11],
      mvp.storage[12],
      mvp.storage[13],
      mvp.storage[14],
      mvp.storage[15],
      color[0], // r 
      color[1], // g
      color[2], // b
      color[3], // a
    ]);
    final frameInfoView =
        transients.emplace(frameInfoFloats.buffer.asByteData());
    pass.bindUniform(frameInfoSlot, frameInfoView);

    /// And finally, we append a draw call.
    pass.draw();

    /// Submit all of the previously encoded passes. Passes are encoded in the
    /// same order they were created in.
    commandBuffer.submit();

    /// Wrap the Flutter GPU texture as a ui.Image and draw it like normal!
    final image = renderTexture.asImage();

    canvas.drawImage(image, Offset(-renderTexture.width / 2, 0), Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class TrianglePage extends StatefulWidget {
  const TrianglePage({super.key});

  @override
  State<TrianglePage> createState() => _TrianglePageState();
}

class _TrianglePageState extends State<TrianglePage> {
  Ticker? tick;
  double time = 0;
  double deltaSeconds = 0;
  double seedX = -0.512511498387847167;
  double seedY = 0.521295573094847167;

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
            value: seedX,
            max: 1,
            min: -1,
            onChanged: (value) => {setState(() => seedX = value)}),
        Slider(
            value: seedY,
            max: 1,
            min: -1,
            onChanged: (value) => {setState(() => seedY = value)}),
        CustomPaint(
          painter: TrianglePainter(time, seedX, seedY),
        ),
      ],
    );
  }
}
