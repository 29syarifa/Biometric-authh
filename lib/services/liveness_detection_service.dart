class LivenessDetectionService {
  bool detectBlink(List<double> eyeOpennessValues) {
    if (eyeOpennessValues.length < 2) return false;

    for (int i = 1; i < eyeOpennessValues.length; i++) {
      if (eyeOpennessValues[i - 1] > 0.8 &&
          eyeOpennessValues[i] < 0.3) {
        return true;
      }
    }

    return false;
  }
}