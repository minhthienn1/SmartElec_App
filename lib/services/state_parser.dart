import 'dart:convert';
import '../models/diagnosis_state.dart';

class StateParser {
  /// Tách display text và state update ra khỏi raw response
  static ParsedResponse parse(String rawResponse) {
    const openTag = '<state_update>';
    const closeTag = '</state_update>';
    final startIdx = rawResponse.indexOf(openTag);
    final endIdx = rawResponse.indexOf(closeTag);

    // Không tìm thấy tag → trả nguyên response, không crash
    if (startIdx == -1 || endIdx == -1) {
      return ParsedResponse(displayText: rawResponse, stateUpdate: null);
    }

    final displayText = rawResponse.substring(0, startIdx).trim();
    final jsonStr = rawResponse
        .substring(startIdx + openTag.length, endIdx)
        .trim();

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ParsedResponse(
        displayText: displayText,
        stateUpdate: StateUpdate.fromJson(json),
      );
    } catch (_) {
      // JSON lỗi → vẫn hiện text, bỏ qua state update
      return ParsedResponse(displayText: displayText, stateUpdate: null);
    }
  }
}

class ParsedResponse {
  final String displayText;
  final StateUpdate? stateUpdate;
  const ParsedResponse({required this.displayText, this.stateUpdate});
}

class StateUpdate {
  final String? device;
  final String? symptom;
  final String? ctx;
  final DiagnosisPhase phase;
  final RiskLevel risk;
  final List<String> asked;
  final List<String> flags;

  const StateUpdate({
    this.device,
    this.symptom,
    this.ctx,
    required this.phase,
    required this.risk,
    required this.asked,
    required this.flags,
  });

  factory StateUpdate.fromJson(Map<String, dynamic> json) {
    return StateUpdate(
      device: json['device'],
      symptom: json['symptom'],
      ctx: json['ctx'],
      phase: json['phase'] == 'DIAGNOSING'
          ? DiagnosisPhase.diagnosing
          : DiagnosisPhase.collecting,
      risk: _parseRisk(json['risk']),
      asked: List<String>.from(json['asked'] ?? []),
      flags: List<String>.from(json['flags'] ?? []),
    );
  }

  static RiskLevel _parseRisk(String? value) {
    switch (value) {
      case 'RED':
        return RiskLevel.red;
      case 'YELLOW':
        return RiskLevel.yellow;
      case 'GREEN':
        return RiskLevel.green;
      default:
        return RiskLevel.unknown;
    }
  }
}
