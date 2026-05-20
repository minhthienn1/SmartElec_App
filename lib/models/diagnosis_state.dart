enum DiagnosisPhase { collecting, diagnosing }

enum RiskLevel { unknown, green, yellow, red }

class DiagnosisContext {
  final String? deviceType;
  final String? symptom;
  final String? situationContext;
  final List<String> askedQuestions;
  final List<String> dangerFlags;
  final DiagnosisPhase phase;
  final RiskLevel riskLevel;

  const DiagnosisContext({
    this.deviceType,
    this.symptom,
    this.situationContext,
    this.askedQuestions = const [],
    this.dangerFlags = const [],
    this.phase = DiagnosisPhase.collecting,
    this.riskLevel = RiskLevel.unknown,
  });

  // Kiểm tra đã đủ điều kiện chuyển phase chưa
  bool get isReadyToDiagnose =>
      deviceType != null && symptom != null && situationContext != null;

  DiagnosisContext copyWith({
    String? deviceType,
    String? symptom,
    String? situationContext,
    List<String>? askedQuestions,
    List<String>? dangerFlags,
    DiagnosisPhase? phase,
    RiskLevel? riskLevel,
  }) {
    return DiagnosisContext(
      deviceType: deviceType ?? this.deviceType,
      symptom: symptom ?? this.symptom,
      situationContext: situationContext ?? this.situationContext,
      askedQuestions: askedQuestions ?? this.askedQuestions,
      dangerFlags: dangerFlags ?? this.dangerFlags,
      phase: phase ?? this.phase,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }

  // Inject vào system prompt mỗi turn
  String toContextString() {
    return """
[CTX]
device=${deviceType ?? 'unknown'}
symptom=${symptom ?? 'unknown'}
context=${situationContext ?? 'unknown'}
flags=${dangerFlags.isEmpty ? 'none' : dangerFlags.join(', ')}
asked=${askedQuestions.isEmpty ? 'none' : askedQuestions.join(' | ')}
phase=${phase.name.toUpperCase()}
""";
  }
}
