import '../l10n/app_localizations.dart';
import '../models/analysis_result.dart';
import '../models/image_stats.dart';
import '../services/camera_service.dart';

/// Turns the domain layer's reason codes into sentences in the active language.
///
/// Everything below is presentation: the services and models deliberately carry
/// codes and parameters only, so the same result can be rendered in any
/// language without re-running the analysis.
extension AnalysisText on L {
  /// The explanation shown under a result.
  String reasonText(AnalysisResult result) {
    final value = result.reasonValue ?? 0;
    final detail = result.reasonDetail ?? '';

    switch (result.reason) {
      case ResultReason.modelClean:
        return notesClean;
      case ResultReason.modelNeedsCheck:
        return notesNeedsCheck;
      case ResultReason.noFrame:
        return reasonNoFrame;
      case ResultReason.modelMissing:
        return reasonModelMissing;
      case ResultReason.modelWrongRank:
        return reasonModelWrongRank(value);
      case ResultReason.modelWrongChannels:
        return reasonModelWrongChannels(value);
      case ResultReason.modelWrongInputType:
        return reasonModelWrongInputType(detail);
      case ResultReason.modelWrongOutputs:
        return reasonModelWrongOutputs(value);
      case ResultReason.modelOpenFailed:
        return reasonModelOpenFailed(detail);
      case ResultReason.modelRunFailed:
        return reasonModelRunFailed(detail);
      case ResultReason.decodeFailed:
        return reasonDecodeFailed(detail);
      case ResultReason.timedOut:
        return reasonTimedOut;
    }
  }

  String headlineFor(Verdict verdict) {
    switch (verdict) {
      case Verdict.clean:
        return headlineLooksClean;
      case Verdict.needsCheck:
        return headlineCheckNeeded;
      case Verdict.inconclusive:
        return headlineNoVerdict;
      case Verdict.failed:
        return headlineFailed;
    }
  }

  String labelFor(Verdict verdict) {
    switch (verdict) {
      case Verdict.clean:
        return labelNoParticles;
      case Verdict.needsCheck:
        return labelParticlesFound;
      case Verdict.inconclusive:
        return labelCaptureOnly;
      case Verdict.failed:
        return labelNothingMeasured;
    }
  }

  String captureHintText(CaptureHint hint) {
    switch (hint) {
      case CaptureHint.tooDark:
        return hintTooDark;
      case CaptureHint.tooBright:
        return hintTooBright;
      case CaptureHint.tooSoft:
        return hintTooSoft;
      case CaptureHint.tooFlat:
        return hintTooFlat;
    }
  }

  /// The message for a camera that is not showing a preview, or null when the
  /// current state needs no explanation.
  String? cameraMessage(CameraService camera) {
    final detail = camera.issueDetail ?? '';

    switch (camera.issue) {
      case CameraIssue.listFailed:
        return cameraListFailed(detail);
      case CameraIssue.startFailed:
        return cameraStartFailed(detail);
      case CameraIssue.captureFailed:
        return cameraCaptureFailed(detail);
      case CameraIssue.noFlash:
        return cameraNoFlash;
      case CameraIssue.none:
        break;
    }

    switch (camera.status) {
      case CameraStatus.permissionBlocked:
        return cameraBlocked;
      case CameraStatus.permissionDenied:
        return cameraDenied;
      case CameraStatus.noCameraFound:
        return cameraNoneFound;
      case CameraStatus.idle:
      case CameraStatus.initialising:
      case CameraStatus.ready:
      case CameraStatus.failed:
        return null;
    }
  }
}
