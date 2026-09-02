class AnalysisResult {
  const AnalysisResult({
    required this.score,
    required this.label,
    required this.notes,
  });

  final double score;
  final String label;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'label': label,
      'notes': notes,
    };
  }
}
