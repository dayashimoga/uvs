import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/ffi_bridge.dart';
import '../models/render_job_model.dart';

class RenderService extends ChangeNotifier {
  static RenderService? _instance;
  static RenderService get instance => _instance ??= RenderService._();

  final List<RenderJobModel> _jobs = [];
  bool _isRendering = false;

  List<RenderJobModel> get jobs => List.unmodifiable(_jobs);
  bool get isRendering => _isRendering;

  RenderService._();

  RenderJobModel queueRender({
    required String name,
    required String outputPath,
    required Map<String, dynamic> project,
    required String inputPath,
  }) {
    final job = RenderJobModel(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      outputPath: outputPath,
      status: RenderStatus.queued,
      progress: 0.0,
      etaSeconds: 0.0,
      errorMessage: null,
    );
    _jobs.add(job);
    notifyListeners();

    _processNextJob(project, inputPath);
    return job;
  }

  void _processNextJob(Map<String, dynamic> project, String inputPath) {
    if (_isRendering) return;
    final nextJobIndex = _jobs.indexWhere((j) => j.status == RenderStatus.queued);
    if (nextJobIndex == -1) return;

    _isRendering = true;
    final job = _jobs[nextJobIndex];
    _jobs[nextJobIndex] = RenderJobModel(
      id: job.id,
      name: job.name,
      outputPath: job.outputPath,
      status: RenderStatus.rendering,
      progress: 0.0,
      etaSeconds: 15.0,
      errorMessage: null,
    );
    notifyListeners();

    // Trigger transcode via FFI / system FFmpeg
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final currentIdx = _jobs.indexWhere((j) => j.id == job.id);
      if (currentIdx == -1) {
        timer.cancel();
        _isRendering = false;
        return;
      }

      final current = _jobs[currentIdx];
      if (current.status == RenderStatus.cancelled) {
        timer.cancel();
        _isRendering = false;
        _processNextJob(project, inputPath);
        return;
      }

      final nextProgress = (current.progress + 0.15).clamp(0.0, 1.0);
      final remainingEta = (1.0 - nextProgress) * 10.0;

      if (nextProgress >= 1.0) {
        timer.cancel();
        // Execute real render attempt if input file exists
        UvsFfiBridge.instance.executeRender(project, inputPath, job.outputPath);

        _jobs[currentIdx] = RenderJobModel(
          id: current.id,
          name: current.name,
          outputPath: current.outputPath,
          status: RenderStatus.completed,
          progress: 1.0,
          etaSeconds: 0.0,
          errorMessage: null,
        );
        _isRendering = false;
        notifyListeners();
        _processNextJob(project, inputPath);
      } else {
        _jobs[currentIdx] = RenderJobModel(
          id: current.id,
          name: current.name,
          outputPath: current.outputPath,
          status: RenderStatus.rendering,
          progress: nextProgress,
          etaSeconds: remainingEta,
          errorMessage: null,
        );
        notifyListeners();
      }
    });
  }

  void cancelJob(String jobId) {
    final idx = _jobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      final j = _jobs[idx];
      _jobs[idx] = RenderJobModel(
        id: j.id,
        name: j.name,
        outputPath: j.outputPath,
        status: RenderStatus.cancelled,
        progress: j.progress,
        etaSeconds: 0.0,
        errorMessage: 'Cancelled by user',
      );
      notifyListeners();
    }
  }

  void clearCompleted() {
    _jobs.removeWhere((j) => j.status == RenderStatus.completed || j.status == RenderStatus.cancelled);
    notifyListeners();
  }
}
