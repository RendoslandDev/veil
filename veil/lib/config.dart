class Config {
  /// Version of the bundled Privacy Policy and Terms (assets/legal/*.md).
  /// Recorded in every consent so we know which terms a person agreed to.
  static const policyVersion = '2026-10-29';

  /// Consent durations offered at enrollment. Consent always expires;
  /// staying findable is a choice you renew, never a default.
  static const consentDays = [30, 90, 365];

  /// Searches allowed per person per rolling 24 hours.
  static const dailySearchLimit = 10;
}
