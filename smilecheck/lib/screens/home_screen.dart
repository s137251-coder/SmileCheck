import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/l10n_text.dart';
import '../l10n/app_localizations.dart';
import '../services/camera_service.dart';
import '../widgets/language_button.dart';
import '../widgets/smile_guide.dart';
import '../widgets/ui_bits.dart';
import 'processing_screen.dart';

/// The camera screen: live preview, aiming frame, and the shutter.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final CameraService _camera = context.read<CameraService>();
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deferred by one frame: the service publishes its first state change
    // synchronously, and notifying provider listeners mid-build is illegal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _camera.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The service is owned by the provider and outlives this screen, so it is
    // deliberately not disposed here: the next screen needs the same camera.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _camera.handleLifecycle(state);
  }

  Future<void> _capture() async {
    if (_capturing || !_camera.isReady) return;

    setState(() => _capturing = true);
    final path = await _camera.captureImage();
    if (!mounted) return;
    setState(() => _capturing = false);

    if (path == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProcessingScreen(imagePath: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = context.watch<CameraService>();
    final l = L.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backdrop),
          ),
          if (camera.isReady) ...[
            _PreviewCover(controller: camera.controller!),
            SmileGuide(active: !_capturing),
          ] else
            _CameraFallback(camera: camera),
          SafeArea(
            child: Column(
              children: [
                _TopBar(camera: camera),
                const Spacer(),
                _Shutter(
                  enabled: camera.isReady && !_capturing,
                  busy: _capturing,
                  hint: _hintFor(camera, l),
                  onPressed: _capture,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _hintFor(CameraService camera, L l) {
    if (_capturing) return l.hintHoldStill;
    if (camera.isReady) return l.hintFrameUp;
    // Idle counts as pending, matching the spinner the fallback shows, so the
    // hint can never contradict the state above it.
    if (camera.isBusy || camera.status == CameraStatus.idle) {
      return l.hintCameraPending;
    }
    return l.hintCameraUnavailable;
  }
}

/// Fills the screen with the preview without distorting it.
///
/// The controller reports its preview in sensor orientation, so the sizes are
/// swapped before the [BoxFit.cover] pass.
class _PreviewCover extends StatelessWidget {
  const _PreviewCover({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return const SizedBox.shrink();

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: preview.height,
            height: preview.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// Everything shown in place of a preview: progress, or an explained failure
/// with the recovery that actually applies to it.
class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.camera});

  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    if (camera.isBusy || camera.status == CameraStatus.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(
              l.preparingCamera,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final blocked = camera.status == CameraStatus.permissionBlocked;
    final denied = camera.status == CameraStatus.permissionDenied;
    final needsAccess = blocked || denied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.gutter),
        child: GlassPanel(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.caution.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  needsAccess
                      ? Icons.no_photography_outlined
                      : Icons.videocam_off_outlined,
                  color: AppColors.caution,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                needsAccess ? l.cameraAccessNeeded : l.cameraUnavailable,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l.cameraMessage(camera) ?? l.cameraUnavailable,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              if (blocked)
                FilledButton.icon(
                  onPressed: camera.openSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  label: Text(l.openSettings),
                )
              else
                FilledButton.icon(
                  onPressed: camera.initialize,
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: Text(denied ? l.allowCamera : l.tryAgain),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.camera});

  final CameraService camera;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          const BrandMark(size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmileCheck',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  l.onDeviceOnly,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const LanguageButton(),
          if (camera.supportsTorch) ...[
            const SizedBox(width: 10),
            CircleIconButton(
              icon: camera.isTorchOn
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              tooltip: l.flashTooltip,
              active: camera.isTorchOn,
              onPressed: camera.toggleTorch,
            ),
          ],
          if (camera.canSwitchCamera) ...[
            const SizedBox(width: 10),
            CircleIconButton(
              icon: Icons.cameraswitch_rounded,
              tooltip: l.switchCameraTooltip,
              onPressed: camera.isBusy ? null : camera.switchCamera,
            ),
          ],
        ],
      ),
    );
  }
}

/// The capture control: hint line, privacy pill, and a large shutter that is
/// comfortably inside the recommended touch target.
class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.enabled,
    required this.busy,
    required this.hint,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final String hint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background.withValues(alpha: 0.86),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: l.startCheck,
            child: GestureDetector(
              onTap: enabled ? onPressed : null,
              child: AnimatedScale(
                scale: busy ? 0.92 : 1,
                duration: const Duration(milliseconds: 180),
                child: AnimatedOpacity(
                  opacity: enabled || busy ? 1 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 3,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.accentSweep,
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF04231A),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              size: 34,
                              color: Color(0xFF04231A),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          InfoPill(
            icon: Icons.shield_outlined,
            label: l.privacyNoUploads,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
