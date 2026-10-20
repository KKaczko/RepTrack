/// Pojęcia ze słowniczka: ekran „Słowniczek” i ikonki ⓘ przy pojęciach
/// na ekranach. Teksty są w plikach ARB (`glossary*`).
enum GlossaryGroup { basics, effort, metrics, progress }

enum GlossaryTerm {
  rep(GlossaryGroup.basics),
  set(GlossaryGroup.basics),
  warmupSet(GlossaryGroup.basics),
  workingSet(GlossaryGroup.basics),
  muscleRoles(GlossaryGroup.basics),
  loadMode(GlossaryGroup.basics),
  rir(GlossaryGroup.effort),
  rpe(GlossaryGroup.effort),
  oneRepMax(GlossaryGroup.metrics),
  estimatedOneRepMax(GlossaryGroup.metrics),
  volume(GlossaryGroup.metrics),
  record(GlossaryGroup.metrics),
  bestSet(GlossaryGroup.metrics),
  setsPerMuscle(GlossaryGroup.progress),
  periodChange(GlossaryGroup.progress),
  progressiveOverload(GlossaryGroup.progress);

  const GlossaryTerm(this.group);

  final GlossaryGroup group;
}
