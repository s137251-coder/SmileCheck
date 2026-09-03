import 'dart:ui' show AppLifecycleState;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why the preview is not showing. Every failure has its own state so the UI
/// can explain the situation and offer the right recovery, instead of leaving
/// the user in front of a blank rectangle.
enum CameraStatus {
  idle,
  initialising,
  ready,
  permissionDenied,

  /// Denied with "don't ask again": only the system settings screen can undo
  /// this, so an in-app prompt would do nothing.
  permissionBlocked,
  noCameraFound,
  failed,
}

/// The specific fault behind [CameraStatus.failed], or a non-fatal notice.
///
/// A code rather than a sentence, so the UI can render it in the active
/// language; [CameraService.issueDetail] carries the untranslated technical
/// text alongside it.
enum CameraIssue { none, listFailed, startFailed, captureFailed, noFlash }

/// Owns the camera lifecycle and publishes its state.
///
/// Held for the lifetime of the app by a provider. Screens must never dispose
/// it: doing so tears the controller out from under the screen that replaces
/// them.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  CameraStatus _status = CameraStatus.idle;
  CameraIssue _issue = CameraIssue.none;
  String? _issueDetail;
  bool _torchOn = false;
  bool _disposed = false;

  CameraController? get controller => _controller;
  CameraStatus get status => _status;
  CameraIssue get issue => _issue;

  /// Untranslated technical detail for [issue], such as an exception message.
  String? get issueDetail => _issueDetail;

  bool get isReady =>
      _status == CameraStatus.ready &&
      _controller != null &&
      _controller!.value.isInitialized;

  bool get isBusy => _status == CameraStatus.initialising;

  bool get canSwitchCamera => _cameras.length > 1;

  bool get isFrontFacing =>
      _controller?.description.lensDirection == CameraLensDirection.front;

  /// Front modules almost never carry a flash, so the control is hidden rather
  /// than shown in a permanently broken state.
  bool get supportsTorch => isReady && !isFrontFacing;

  bool get isTorchOn => _torchOn;

  /// Requests permission and opens the preferred camera.
  ///
  /// Never throws: the outcome is published through [status] and [issue] so a
  /// caller cannot accidentally show "ready" over a failed camera.
  Future<void> initialize() async {
    if (_status == CameraStatus.initialising) return;

    // Returning from a result must not tear down a working preview, so an
    // already-open camera is left exactly as it is.
    if (isReady) return;

    _set(CameraStatus.initialising);

    final permission = await Permission.camera.request();
    if (permission.isPermanentlyDenied || permission.isRestricted) {
      _set(CameraStatus.permissionBlocked);
      return;
    }
    if (!permission.isGranted) {
      _set(CameraStatus.permissionDenied);
      return;
    }

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
    } on Object catch (error) {
      _set(CameraStatus.failed,
          issue: CameraIssue.listFailed, detail: '$error');
      return;
    }

    if (_cameras.isEmpty) {
      _set(CameraStatus.noCameraFound);
      return;
    }

    // A selfie check should open on the front module (spec 6.2); fall back to
    // whatever exists on devices without one.
    final preferred = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraIndex = preferred >= 0 ? preferred : 0;

    await _open(_cameras[_cameraIndex]);
  }

  Future<void> _open(CameraDescription description) async {
    try {
      await _controller?.dispose();
      _controller = null;

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      _controller = controller;
      _torchOn = false;
      _set(CameraStatus.ready);
    } on CameraException catch (error) {
      _controller = null;
      _set(CameraStatus.failed,
          issue: CameraIssue.startFailed,
          detail: error.description ?? error.code);
    } on Object catch (error) {
      _controller = null;
      _set(CameraStatus.failed,
          issue: CameraIssue.startFailed, detail: '$error');
    }
  }

  /// Moves to the next available lens.
  Future<void> switchCamera() async {
    if (!canSwitchCamera || isBusy) return;

    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _set(CameraStatus.initialising);
    await _open(_cameras[_cameraIndex]);
  }

  /// Toggles the torch, reporting failure instead of leaving a stale icon.
  Future<void> toggleTorch() async {
    if (!supportsTorch) return;

    final next = !_torchOn;
    try {
      await _controller!.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      _torchOn = next;
      _notify();
    } on Object {
      _torchOn = false;
      _set(CameraStatus.ready, issue: CameraIssue.noFlash);
    }
  }

  /// Captures a frame, or returns null with [issue] set when it could not.
  Future<String?> captureImage() async {
    if (!isReady || _controller!.value.isTakingPicture) return null;

    try {
      final file = await _controller!.takePicture();
      return file.path;
    } on Object catch (error) {
      _set(CameraStatus.ready,
          issue: CameraIssue.captureFailed, detail: '$error');
      return null;
    }
  }

  /// Releases the camera while the app is backgrounded and reopens it after,
  /// which is what Android requires to keep the preview alive across resumes.
  Future<void> handleLifecycle(AppLifecycleState state) async {
    // Resume is handled first and unconditionally: pausing leaves the
    // controller null, so a null check ahead of this would strand the app on
    // an empty preview for the rest of the session.
    if (state == AppLifecycleState.resumed) {
      await initialize();
      return;
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      await controller.dispose();
      _controller = null;
      _set(CameraStatus.idle);
    }
  }

  /// Opens the system settings page for the app.
  Future<void> openSettings() => openAppSettings();

  void _set(
    CameraStatus status, {
    CameraIssue issue = CameraIssue.none,
    String? detail,
  }) {
    _status = status;
    _issue = issue;
    _issueDetail = detail;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
