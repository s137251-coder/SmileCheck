import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  CameraController? get controller => _controller;
  bool get isReady => _controller != null && _controller!.value.isInitialized;

  Future<String?> captureImage() async {
    if (!isReady || _controller!.value.isTakingPicture) return null;

    final image = await _controller!.takePicture();
    return image.path;
  }

  Future<void> initialize() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        throw Exception('Camera permission is required to use SmileCheck.');
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
    } on Exception catch (_) {
      _controller = null;
      _cameras = const [];
      return;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
