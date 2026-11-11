/// Where "now" comes from. The app reads the wall clock; tests and rendered
/// previews pin it, so nothing in Mari has to call `DateTime.now()` itself.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
