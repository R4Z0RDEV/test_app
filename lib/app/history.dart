import 'package:flutter/foundation.dart';

enum JobType { video, image, upscale }

class GenerationJob {
  final String id;
  final JobType type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final String previewUrl;
  final Map<String, dynamic> parameters;
  bool hasWatermark;
  bool watermarkRemoved;

  GenerationJob({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.previewUrl,
    required this.parameters,
    this.hasWatermark = true,
    this.watermarkRemoved = false,
  });

  GenerationJob copyWith({
    bool? hasWatermark,
    bool? watermarkRemoved,
  }) {
    return GenerationJob(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      createdAt: createdAt,
      previewUrl: previewUrl,
      parameters: parameters,
      hasWatermark: hasWatermark ?? this.hasWatermark,
      watermarkRemoved: watermarkRemoved ?? this.watermarkRemoved,
    );
  }
}

class GenerationHistory extends ChangeNotifier {
  GenerationHistory._();
  static final instance = GenerationHistory._();

  final List<GenerationJob> _jobs = [];

  List<GenerationJob> get jobs =>
      List.unmodifiable(_jobs..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  void addJob(GenerationJob job) {
    _jobs.removeWhere((j) => j.id == job.id);
    _jobs.add(job);
    notifyListeners();
  }

  void updateJob(GenerationJob job) {
    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _jobs[index] = job;
      notifyListeners();
    }
  }

  GenerationJob? findById(String id) {
    try {
      return _jobs.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }
}

class JobSelection extends ChangeNotifier {
  JobSelection._();
  static final instance = JobSelection._();

  GenerationJob? _selected;
  GenerationJob? get selected => _selected;

  void select(GenerationJob job) {
    _selected = job;
    notifyListeners();
  }

  void clear() {
    _selected = null;
    notifyListeners();
  }
}

