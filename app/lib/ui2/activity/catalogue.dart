// The activity vocabulary — ~70 things a person actually does, in eight
// groups, each carrying a published MET value except the one row that names
// no activity at all.
//
// Why MET and not a made-up "intensity": a calorie figure has to come from
// somewhere, and "somewhere" is Ainsworth et al., Compendium of Physical
// Activities (2011 update, Med Sci Sports Exerc 43(8):1575-81). The arithmetic
// is one line — kcal = MET × 3.5 × kg / 200 × minutes — and it needs body
// weight, which the app may not have. So [Activity.kcal] returns null rather
// than a number, and the screens say so. A fabricated calorie count is worse
// than no calorie count, because it looks the same as a measured one.
//
// The app's stored workout vocabulary is the free-form `sessions.type` TEXT
// column, so this table needs no schema of its own: [byName] maps a stored
// type back to its entry, and an unknown type simply falls through to null.

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

part 'wger_exercises.g.dart';

/// How a session is tracked — which decides which live screen it opens, and
/// therefore which parameters the user is asked for.
enum Track {
  /// Strength — reps, load, rest. Entered, never measured.
  sets,

  /// Running, cycling, swimming, rowing — distance and pace.
  distance,

  /// Sports and classes — anything simply timed.
  duration,

  /// HIIT, circuits, tabata — work/rest rounds.
  interval,

  /// Yoga, stretching, breathwork — time, breath, stillness.
  stillness,
}

class Activity {
  final String name;
  final IconData icon;
  final Color color;
  final Track track;

  /// Metabolic equivalent of task — the honest basis for a calorie estimate.
  /// Compendium of Physical Activities, Ainsworth et al.
  ///
  /// NULL for a row the compendium cannot price. 'General workout' means the
  /// user did not say what they did, and the compendium prices named
  /// activities; 'Padel' is named but has no compendium row at all. Every number that could go here
  /// would be a stand-in — which is the 'Custom activity' mistake below,
  /// whose MET of 4.0 was invented. So [kcal] returns null, the picker and
  /// the setup screen show no estimate, and the session still gets a REAL
  /// calorie figure afterwards: the post-session estimator in
  /// `compute/manual_session.dart` works from heart rate and never reads a
  /// MET. The guess is what is missing, not the calories.
  final double? met;

  /// Whether a route is worth recording. GPS activities get the map.
  final bool gps;

  /// Defaults the session's privacy toggle on. Not a different kind of
  /// activity — a different default, which the user can flip either way.
  final bool private;

  /// Locomotion on foot, so the strap's 100 Hz pedometer may count its steps.
  ///
  /// NOT the same question as [gps] — cycling records a route and takes no
  /// steps; a treadmill takes steps and records nothing. Default false: an
  /// activity is only gait when someone has said so, because the failure is
  /// silent and expensive. Wrist step error is UNBOUNDED ABOVE on rhythmic arm
  /// work (OxWalk: +199.5% worst case at the wrist against +5.3% at the hip),
  /// so rowing or boxing admitted here would bank hundreds of steps nobody
  /// took. `kGaitStepTypeKeys` is derived from this flag and pinned to it in
  /// both directions by test/gait_step_types_test.dart.
  final bool gait;

  const Activity(this.name, this.icon, this.color, this.track, this.met,
      {this.gps = false, this.private = false, this.gait = false});

  /// kcal = MET × 3.5 × kg / 200 × minutes.
  ///
  /// Null when body weight is unknown, and null when the activity carries no
  /// MET. There is no default for either: both numbers would be
  /// indistinguishable from a real one on screen.
  int? kcal(double? kg, int minutes) => kg == null || kg <= 0 || met == null
      ? null
      : (met! * 3.5 * kg / 200 * minutes).round();

  /// The stored `sessions.type` for this activity.
  String get typeKey => name.toLowerCase().replaceAll(' ', '_');

  /// Localized display only; stored names and keys remain unchanged.
  String displayName(BuildContext c) => localizedName(AppLocalizations.of(c));

  String localizedName(AppLocalizations? l) => catalogueName(l, name);
}

class ActGroup {
  final String name;
  final IconData icon;
  final List<Activity> items;
  const ActGroup(this.name, this.icon, this.items);

  String displayName(BuildContext c) => localizedName(AppLocalizations.of(c));

  String localizedName(AppLocalizations? l) => catalogueName(l, name);
}

String catalogueName(AppLocalizations? l, String name) =>
    l?.activityCatalogueName(
      'k${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}',
      name,
    ) ??
    name;

const activityLibrary = <ActGroup>[
  ActGroup('Cardio', LucideIcons.heartPulse, [
    Activity('Running', LucideIcons.footprints, C.green, Track.distance, 9.8,
        gps: true, gait: true),
    Activity(
        'Trail running', LucideIcons.mountain, C.green, Track.distance, 10.5,
        gps: true, gait: true),
    Activity('Walking', LucideIcons.footprints, C.teal, Track.distance, 3.5,
        gps: true, gait: true),
    Activity('Hiking', LucideIcons.mountainSnow, C.green, Track.distance, 6.0,
        gps: true, gait: true),
    Activity('Cycling', LucideIcons.bike, C.blue, Track.distance, 8.0,
        gps: true),
    Activity('Indoor bike', LucideIcons.bike, C.blue, Track.duration, 7.0),
    Activity('Rowing', LucideIcons.sailboat, C.teal, Track.distance, 7.0),
    Activity('Swimming', LucideIcons.waves, C.blue, Track.distance, 8.3),
    Activity('Elliptical', LucideIcons.activity, C.purple, Track.duration, 5.0),
    Activity(
        'Stair climber', LucideIcons.trendingUp, C.orange, Track.duration, 9.0),
    // Tracked by duration, not distance: a treadmill belt reports nothing to
    // this app and a wrist cannot measure indoor distance, so the session is
    // its heart rate and its clock.
    Activity('Treadmill', LucideIcons.footprints, C.green, Track.duration, 8.3, gait: true),
    Activity('Jump rope', LucideIcons.circleDashed, C.red, Track.interval, 12.3),
  ]),
  ActGroup('Strength', LucideIcons.dumbbell, [
    Activity('Weight training', LucideIcons.dumbbell, C.purple, Track.sets, 6.0),
    Activity('Powerlifting', LucideIcons.dumbbell, C.purple, Track.sets, 6.0),
    Activity(
        'Bodyweight', LucideIcons.personStanding, C.purple, Track.sets, 4.5),
    Activity(
        'Calisthenics', LucideIcons.personStanding, C.purple, Track.sets, 5.0),
    Activity('Kettlebell', LucideIcons.dumbbell, C.orange, Track.interval, 8.0),
    Activity('CrossFit', LucideIcons.flame, C.red, Track.interval, 9.0),
    Activity('HIIT', LucideIcons.zap, C.red, Track.interval, 10.0),
    Activity(
        'Circuit training', LucideIcons.repeat2, C.orange, Track.interval, 7.5),
    Activity('Functional', LucideIcons.boxes, C.purple, Track.sets, 5.5),
  ]),
  ActGroup('Sports', LucideIcons.trophy, [
    Activity('Football', LucideIcons.volleyball, C.green, Track.duration, 8.0),
    Activity('Basketball', LucideIcons.volleyball, C.orange, Track.duration, 8.0),
    Activity('Cricket', LucideIcons.target, C.green, Track.duration, 5.0),
    Activity('Tennis', LucideIcons.volleyball, C.yellow, Track.duration, 7.3),
    Activity('Badminton', LucideIcons.volleyball, C.teal, Track.duration, 5.5),
    Activity(
        'Table tennis', LucideIcons.volleyball, C.blue, Track.duration, 4.0),
    Activity('Squash', LucideIcons.volleyball, C.red, Track.duration, 12.0),
    // No MET: the compendium has no padel row. Tennis doubles and paddleball
    // are different games, and borrowing either would be a stand-in. The
    // post-session estimate still works from heart rate.
    Activity('Padel', LucideIcons.volleyball, C.yellow, Track.duration, null),
    Activity('Volleyball', LucideIcons.volleyball, C.orange, Track.duration, 6.0),
    Activity('Hockey', LucideIcons.target, C.blue, Track.duration, 8.0),
    Activity('Baseball', LucideIcons.target, C.red, Track.duration, 5.0),
    Activity('Rugby', LucideIcons.volleyball, C.green, Track.duration, 8.3),
    Activity('Golf', LucideIcons.flag, C.green, Track.duration, 4.8, gps: true),
    // Compendium 15092, "bowling, indoor, bowling alley". This row IS the
    // alley — that assumption is the choice being made here, not a fact about
    // what users do — because the alternative is two near-identical rows. The
    // bare 15090 "bowling" is 3.0, and neither number is the measured one.
    Activity('Bowling', LucideIcons.circleDot, C.indigo, Track.duration, 3.8),
    Activity('Boxing', LucideIcons.hand, C.red, Track.interval, 12.8),
    Activity('Martial arts', LucideIcons.hand, C.red, Track.duration, 10.3),
    Activity('Wrestling', LucideIcons.users, C.orange, Track.duration, 6.0),
    Activity('Climbing', LucideIcons.mountain, C.orange, Track.duration, 8.0),
  ]),
  ActGroup('Athletics', LucideIcons.medal, [
    Activity('Sprinting', LucideIcons.zap, C.red, Track.interval, 23.0),
    Activity('Track intervals', LucideIcons.timer, C.red, Track.interval, 11.8),
    Activity(
        'Cross country', LucideIcons.mountain, C.green, Track.distance, 9.0,
        gps: true, gait: true),
    Activity('Hurdles', LucideIcons.zap, C.orange, Track.interval, 10.0),
    Activity('Long jump', LucideIcons.moveUpRight, C.orange, Track.duration, 6.0),
    Activity('Shot put', LucideIcons.circle, C.purple, Track.duration, 4.0),
    Activity('Javelin', LucideIcons.moveUpRight, C.purple, Track.duration, 4.0),
    Activity('Pole vault', LucideIcons.moveUp, C.orange, Track.duration, 6.0),
  ]),
  ActGroup('Outdoor', LucideIcons.trees, [
    Activity('Mountain biking', LucideIcons.bike, C.green, Track.distance, 8.5,
        gps: true),
    Activity('Kayaking', LucideIcons.sailboat, C.blue, Track.distance, 5.0,
        gps: true),
    Activity('Surfing', LucideIcons.waves, C.blue, Track.duration, 5.0),
    Activity('Paddleboard', LucideIcons.sailboat, C.teal, Track.distance, 6.0,
        gps: true),
    Activity('Skiing', LucideIcons.snowflake, C.blue, Track.distance, 7.0,
        gps: true),
    Activity(
        'Snowboarding', LucideIcons.snowflake, C.indigo, Track.distance, 5.3,
        gps: true),
    Activity('Skating', LucideIcons.circleDashed, C.purple, Track.distance, 7.0,
        gps: true),
    // Compendium 15580, "skateboarding, general, moderate effort". Timed, not
    // a route: a park session goes nowhere, and cruising is the longboard rows.
    Activity(
        'Skateboarding', LucideIcons.circleDashed, C.orange, Track.duration, 5.0),
    Activity('Horse riding', LucideIcons.rabbit, C.orange, Track.duration, 5.5),
  ]),
  ActGroup('Mind & body', LucideIcons.leaf, [
    Activity('Yoga', LucideIcons.personStanding, C.teal, Track.stillness, 3.0),
    Activity('Pilates', LucideIcons.personStanding, C.teal, Track.stillness, 3.8),
    Activity(
        'Stretching', LucideIcons.personStanding, C.green, Track.stillness, 2.3),
    Activity(
        'Mobility', LucideIcons.personStanding, C.green, Track.stillness, 3.0),
    Activity('Tai chi', LucideIcons.wind, C.teal, Track.stillness, 3.0),
    Activity('Breathwork', LucideIcons.wind, C.teal, Track.stillness, 1.5),
    Activity('Meditation', LucideIcons.brain, C.purple, Track.stillness, 1.3),
  ]),
  ActGroup('Everyday', LucideIcons.house, [
    Activity('Housework', LucideIcons.house, C.n500, Track.duration, 3.3),
    Activity('Gardening', LucideIcons.sprout, C.green, Track.duration, 3.8),
    Activity('Dog walking', LucideIcons.dog, C.teal, Track.distance, 3.0,
        gps: true, gait: true),
    Activity('Childcare', LucideIcons.baby, C.pink, Track.duration, 3.0),
    Activity('DIY', LucideIcons.hammer, C.orange, Track.duration, 4.5),
    Activity('Shopping', LucideIcons.shoppingBag, C.n500, Track.duration, 2.3),
    Activity('Stairs', LucideIcons.trendingUp, C.orange, Track.duration, 8.0),
  ]),
  ActGroup('Other', LucideIcons.ellipsis, [
    // The catch-all: nothing in the catalogue matched, or hunting for the
    // match was not worth it. NO MET, and that is the whole design of the row
    // — see [Activity.met]. 02060 "health club exercise, general" was the
    // near miss, and it prices a gym session, which is not what this row
    // means. Tracked by duration because the clock and the heart-rate trace
    // are everything the app knows about a workout nobody named.
    Activity('General workout', LucideIcons.activity, C.purple,
        Track.duration, null),
    Activity('Dancing', LucideIcons.music, C.pink, Track.duration, 7.8),
    // A normal entry with a real MET and a privacy default, exactly as Apple
    // Health carries it. Coyness here would be its own kind of judgement.
    Activity('Intimacy', LucideIcons.heart, C.pink, Track.duration, 5.8,
        private: true),
    Activity(
        'Physiotherapy', LucideIcons.stethoscope, C.blue, Track.duration, 3.0),
    Activity('Sauna', LucideIcons.thermometer, C.orange, Track.stillness, 1.5),
    Activity('Cold plunge', LucideIcons.snowflake, C.blue, Track.stillness, 2.0),
    // There is no 'Custom activity' row. It carried a MET of 4.0, which is not
    // in the compendium and could not be — the whole point of a custom entry
    // is that the app does not know what it is — and every session made with
    // it banked a specific-looking calorie figure derived from nothing about
    // what the user did, under one shared type key, with no name field
    // anywhere to say what it had been.
  ]),
];

/// What the app has to say about a calorie figure, in one place because it was
/// said in four and drifted: one site kept quoting a "±15%" error bar that no
/// estimator computes, long after the others dropped it.
const kCalorieWhy = 'MET value × your weight, refined by heart rate — or '
    'heart rate alone, for an activity that carries no MET.';

/// TS-03 — what every zone chart in the app has to admit about its own edges.
///
/// The five bands are percentages of a ceiling nobody measured on this user:
/// `estimatedMaxHr(age, family)`, Tanaka's age line for the strap that recorded
/// it. At 30 that is 187 and a real ceiling can sit 20 bpm either side of it,
/// so every boundary drawn off it moves with it. Saying that on the chart is a
/// materially different claim from printing five confident bpm ranges, and it
/// is the claim we can actually support.
///
/// One string because two screens draw a full zone chart (the session summary
/// and the day-strain detail) and it has to say the same thing on both. The
/// compact bar on a history row does not carry it — that row taps straight
/// through to the summary, which does.
///
/// Never "fat burning zone", never "aerobic threshold": these are convention
/// edges on a guessed ceiling, not measurements of anything metabolic.
/// NOT "your age and your strap": [estimatedMaxHr] takes `deviceFamily` and
/// DELIBERATELY IGNORES IT (hr_max.dart) — Tanaka is a population regression on
/// age alone, and swapping the strap does not move it by one bpm. The sentence
/// named an input that provably has no effect on the number it describes.
const kZonesWhy = 'Zone edges are percentages of a maximum heart rate '
    'estimated from your age — not one measured on you.';

/// English, non-localized fallback/test seam — see [zonesWhyFootnote] and
/// [zonesWhy] for the localized callers actually used by the UI.
String zonesWhyFootnote([AppLocalizations? l]) => l?.catalogueZonesWhy ?? kZonesWhy;

/// THE sentence a zone chart carries, for the anchors THAT chart was banded on.
///
/// [source] is the set's own stamp (`karvonen` · `observed` · `tanaka`) and
/// [maxHr] the ceiling it is 100 % of. One function because the day-strain
/// detail and a session's summary card draw the same bands off the same
/// `trainingZones` set, and only one of them was reading the stamp: the summary
/// hard-coded [kZonesWhy] and so told a user whose zones were banded on a
/// MEASURED ceiling that they came from their age. A card that reports 13
/// minutes above a boundary its own footnote misattributes is unanswerable —
/// there is no number on screen to check it against.
///
/// [kZonesWhy] (via [zonesWhyFootnote]) is the fallback rather than a fourth
/// branch: an unknown stamp and a measured stamp with no ceiling to name are
/// both "we cannot say this was measured on you", which is what the estimate
/// sentence already says. [l] is optional so the non-UI test seam
/// (`hr_ceiling_zones_test.dart`) can call this with the plain English copy.
String zonesWhy(String? source, num? maxHr, [AppLocalizations? l]) => maxHr == null
    ? zonesWhyFootnote(l)
    : switch (source) {
        'karvonen' =>
          l?.dayStrainZoneFootnoteKarvonen(maxHr.round()) ??
              'Zone edges span the gap between your measured resting heart rate '
                  'and the highest we have seen (${maxHr.round()} bpm). Both '
                  'measured on you.',
        'observed' =>
          l?.dayStrainZoneFootnoteObserved(maxHr.round()) ??
              'Zone edges are percentages of the highest heart rate we have seen '
                  '(${maxHr.round()} bpm) — measured, not estimated.',
        _ => zonesWhyFootnote(l),
      };

/// The row that means most people never open the catalogue.
const quickStart = <Activity>[
  Activity('Running', LucideIcons.footprints, C.green, Track.distance, 9.8,
      gps: true, gait: true),
  Activity('Weight training', LucideIcons.dumbbell, C.purple, Track.sets, 6.0),
  Activity('Cycling', LucideIcons.bike, C.blue, Track.distance, 8.0, gps: true),
  Activity('Walking', LucideIcons.footprints, C.teal, Track.distance, 3.5,
      gps: true, gait: true),
  Activity('Football', LucideIcons.volleyball, C.green, Track.duration, 8.0),
  Activity('Yoga', LucideIcons.personStanding, C.teal, Track.stillness, 3.0),
];

final List<Activity> allActivities = [
  for (final g in activityLibrary) ...g.items,
];

final Map<String, Activity> _byKey = {
  for (final a in allActivities) a.typeKey: a,
};

/// Resolve a stored `sessions.type` (or a display name) back to its entry.
/// Null for a type this build does not know — the caller renders the row with
/// what it has rather than guessing an icon and a MET.
Activity? activityByName(String? type) =>
    type == null ? null : _byKey[type.toLowerCase().replaceAll(' ', '_')];

// ── EXERCISES ──────────────────────────────────────────────────────────────
// The strength catalogue. The hand-written list keeps the strength_set keys
// already in use; the generated tail is a wger snapshot (see
// tool/update_wger_exercises.dart).

class ExerciseCredit {
  final String licenseName;
  final String licenseUrl;
  final String author;

  const ExerciseCredit(this.licenseName, this.licenseUrl, this.author);
}

class ExerciseDef {
  final String key;
  final String label;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String category;
  final List<String> equipment;
  final List<String> aliases;

  /// Upstream translations for wger rows, hand-written for the core lifts;
  /// missing falls back to [label].
  final Map<String, String> localizedLabels;

  /// The plate/dumbbell increment this lift is normally loaded in, kg. A
  /// barbell moves in 2.5, a dumbbell in 2 — a single global step is what
  /// makes every strength app feel like a spreadsheet.
  final double step;

  /// wger rows only. Base data and each translation carry their own credit.
  final String? sourceId;
  final String? sourceUpdatedAt;
  final List<ExerciseCredit> sourceCredits;

  /// Done with the body as the load. With no history to seed from, the set
  /// starts as bodyweight instead of inheriting the last lift's kilos.
  final bool bodyweight;

  const ExerciseDef(
    this.key,
    this.label,
    this.primaryMuscles, {
    this.secondaryMuscles = const [],
    this.category = '',
    this.equipment = const [],
    this.aliases = const [],
    this.localizedLabels = const {},
    this.step = 2.5,
    this.sourceId,
    this.sourceUpdatedAt,
    this.sourceCredits = const [],
    this.bodyweight = false,
  });

  bool get fromWger => sourceId != null;

  /// The upstream record with its authors and licenses.
  String? get sourceUrl => sourceId == null
      ? null
      : 'https://wger.de/api/v2/exerciseinfo/?uuid=$sourceId';

  String labelFor(String languageCode) => languageCode == 'ru'
      ? _russianExerciseLocalizations.exerciseCatalogueName(
          'k${key.replaceAll(RegExp('[^A-Za-z0-9_]'), '')}',
          label,
        )
      : localizedLabels[languageCode] ?? label;

  bool matches(String query, String languageCode) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return <String>{
      labelFor(languageCode),
      label,
      ...localizedLabels.values,
      ...aliases,
      ...primaryMuscles,
      ...secondaryMuscles,
      ...equipment,
      category,
    }.any((v) => v.toLowerCase().contains(q));
  }
}

final _russianExerciseLocalizations = lookupAppLocalizations(
  const Locale('ru'),
);

// Muscles use the wger vocabulary of the generated tail ("Chest", "Lats",
// "Quads"…), one spelling per muscle: the recovery list and the sets card key
// on the name, so "biceps" here and "Biceps" there became two rows. Every name
// must be a key of kMuscleRegions (muscle_recovery.dart); a test holds that.
const _edgeExerciseLibrary = <ExerciseDef>[
  ExerciseDef(
    'bench_press',
    'Bench press',
    ['Chest'],
    secondaryMuscles: ['Triceps', 'Shoulders'],
    category: 'Chest',
    equipment: ['Barbell', 'Bench'],
    localizedLabels: {
      'de': 'Bankdrücken',
      'es': 'Press de banca',
      'fr': 'Développé couché',
    },
  ),
  ExerciseDef(
    'incline_db_press',
    'Incline DB press',
    ['Chest', 'Shoulders'],
    secondaryMuscles: ['Triceps'],
    category: 'Chest',
    equipment: ['Dumbbell', 'Incline bench'],
    aliases: ['incline dumbbell press'],
    step: 2,
    localizedLabels: {
      'de': 'Schrägbankdrücken mit Kurzhanteln',
      'es': 'Press inclinado con mancuernas',
      'fr': 'Développé incliné haltères',
    },
  ),
  ExerciseDef(
    'cable_fly',
    'Cable fly',
    ['Chest'],
    secondaryMuscles: ['Shoulders'],
    category: 'Chest',
    equipment: ['Cable machine'],
    localizedLabels: {
      'de': 'Fliegende am Kabelzug',
      'es': 'Aperturas en polea',
      'fr': 'Écarté à la poulie',
    },
  ),
  ExerciseDef(
    'push_up',
    'Push-up',
    ['Chest'],
    secondaryMuscles: ['Triceps', 'Shoulders'],
    category: 'Chest',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['push up', 'push-ups', 'press-up'],
    localizedLabels: {'de': 'Liegestütz', 'es': 'Flexión', 'fr': 'Pompe'},
    bodyweight: true,
  ),
  ExerciseDef(
    'overhead_press',
    'Overhead press',
    ['Shoulders'],
    secondaryMuscles: ['Triceps', 'Abs'],
    category: 'Shoulders',
    equipment: ['Barbell'],
    aliases: ['OHP'],
    localizedLabels: {
      'de': 'Schulterdrücken',
      'es': 'Press militar',
      'fr': 'Développé militaire',
    },
  ),
  ExerciseDef(
    'triceps_pushdown',
    'Triceps pushdown',
    ['Triceps'],
    category: 'Arms',
    equipment: ['Cable machine'],
    localizedLabels: {
      'de': 'Trizepsdrücken am Kabel',
      'es': 'Extensión de tríceps en polea',
      'fr': 'Extension des triceps à la poulie',
    },
  ),
  ExerciseDef(
    'overhead_extension',
    'Overhead extension',
    ['Triceps'],
    category: 'Arms',
    aliases: ['overhead triceps extension'],
    localizedLabels: {
      'de': 'Trizepsstrecken über Kopf',
      'es': 'Extensión de tríceps sobre la cabeza',
      'fr': 'Extension des triceps au-dessus de la tête',
    },
  ),
  ExerciseDef(
    'barbell_row',
    'Barbell row',
    ['Lats'],
    secondaryMuscles: ['Biceps', 'Trapezius'],
    category: 'Back',
    equipment: ['Barbell'],
    localizedLabels: {
      'de': 'Langhantelrudern',
      'es': 'Remo con barra',
      'fr': 'Rowing barre',
    },
  ),
  ExerciseDef(
    'lat_pulldown',
    'Lat pulldown',
    ['Lats'],
    secondaryMuscles: ['Biceps'],
    category: 'Back',
    equipment: ['Cable machine'],
    localizedLabels: {
      'de': 'Latziehen',
      'es': 'Jalón al pecho',
      'fr': 'Tirage vertical',
    },
  ),
  ExerciseDef(
    'pull_up',
    'Pull-up',
    ['Lats'],
    secondaryMuscles: ['Biceps', 'Abs'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['pull up', 'pull-ups'],
    localizedLabels: {'de': 'Klimmzug', 'es': 'Dominada', 'fr': 'Traction'},
    bodyweight: true,
  ),
  ExerciseDef(
    'barbell_curl',
    'Barbell curl',
    ['Biceps'],
    secondaryMuscles: ['Brachialis'],
    category: 'Arms',
    equipment: ['Barbell'],
    localizedLabels: {
      'de': 'Langhantelcurl',
      'es': 'Curl con barra',
      'fr': 'Curl barre',
    },
  ),
  ExerciseDef(
    'back_squat',
    'Back squat',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings', 'Lower back'],
    category: 'Legs',
    equipment: ['Barbell'],
    localizedLabels: {
      'de': 'Kniebeuge',
      'es': 'Sentadilla trasera',
      'fr': 'Squat arrière',
    },
  ),
  ExerciseDef(
    'front_squat',
    'Front squat',
    ['Quads'],
    secondaryMuscles: ['Glutes', 'Abs'],
    category: 'Legs',
    equipment: ['Barbell'],
    localizedLabels: {
      'de': 'Frontkniebeuge',
      'es': 'Sentadilla frontal',
      'fr': 'Squat avant',
    },
  ),
  ExerciseDef(
    'deadlift',
    'Deadlift',
    ['Hamstrings', 'Glutes', 'Lower back'],
    secondaryMuscles: ['Quads', 'Trapezius'],
    category: 'Back',
    equipment: ['Barbell'],
    localizedLabels: {
      'de': 'Kreuzheben',
      'es': 'Peso muerto',
      'fr': 'Soulevé de terre',
    },
  ),
  ExerciseDef(
    'romanian_deadlift',
    'Romanian deadlift',
    ['Hamstrings', 'Glutes'],
    secondaryMuscles: ['Lower back'],
    category: 'Legs',
    equipment: ['Barbell'],
    aliases: ['RDL'],
    localizedLabels: {
      'de': 'Rumänisches Kreuzheben',
      'es': 'Peso muerto rumano',
      'fr': 'Soulevé de terre roumain',
    },
  ),
  ExerciseDef(
    'hip_thrust',
    'Hip thrust',
    ['Glutes'],
    secondaryMuscles: ['Hamstrings'],
    category: 'Legs',
    localizedLabels: {
      'de': 'Hip Thrust',
      'es': 'Empuje de cadera',
      'fr': 'Hip thrust',
    },
  ),
  ExerciseDef(
    'leg_press',
    'Leg press',
    ['Quads'],
    secondaryMuscles: ['Glutes'],
    category: 'Legs',
    localizedLabels: {
      'de': 'Beinpresse',
      'es': 'Prensa de piernas',
      'fr': 'Presse à cuisses',
    },
  ),
  ExerciseDef(
    'plank',
    'Plank',
    ['Abs'],
    category: 'Abs',
    equipment: ['none (bodyweight exercise)'],
    step: 0,
    localizedLabels: {'de': 'Unterarmstütz', 'es': 'Plancha', 'fr': 'Gainage'},
    bodyweight: true,
  ),
  ExerciseDef(
    'hanging_leg_raise',
    'Hanging leg raise',
    ['Abs'],
    category: 'Abs',
    equipment: ['Pull-up bar'],
    step: 0,
    localizedLabels: {
      'de': 'Hängendes Beinheben',
      'es': 'Elevación de piernas colgado',
      'fr': 'Relevé de jambes suspendu',
    },
    bodyweight: true,
  ),
];

// Everyday moves the lifting-only wger selection leaves out — chin-ups,
// dips, bodyweight squats, core work — and a few barbell basics. Not in the
// picker's short list (that stays the core lifts); found by search and in
// the full list. Same muscle vocabulary as above.
const _extraExerciseLibrary = <ExerciseDef>[
  ExerciseDef(
    'chin_up',
    'Chin-up',
    ['Lats', 'Biceps'],
    secondaryMuscles: ['Abs'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['chin up', 'chin-ups', 'chinup', 'underhand pull-up'],
    localizedLabels: {'de': 'Klimmzug im Untergriff', 'es': 'Dominada supina', 'fr': 'Traction en supination', 'id': 'Chin-up'},
    bodyweight: true,
  ),
  ExerciseDef(
    'neutral_grip_pull_up',
    'Neutral-grip pull-up',
    ['Lats', 'Biceps'],
    secondaryMuscles: ['Brachialis'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['hammer pull-up'],
    localizedLabels: {'de': 'Klimmzug mit neutralem Griff', 'es': 'Dominada con agarre neutro', 'fr': 'Traction prise neutre', 'id': 'Pull-up pegangan netral'},
    bodyweight: true,
  ),
  ExerciseDef(
    'wide_grip_pull_up',
    'Wide-grip pull-up',
    ['Lats'],
    secondaryMuscles: ['Shoulders', 'Biceps'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['wide pull up'],
    localizedLabels: {'de': 'Klimmzug mit weitem Griff', 'es': 'Dominada con agarre ancho', 'fr': 'Traction prise large', 'id': 'Pull-up pegangan lebar'},
    bodyweight: true,
  ),
  ExerciseDef(
    'muscle_up',
    'Muscle-up',
    ['Lats', 'Triceps'],
    secondaryMuscles: ['Chest', 'Shoulders', 'Abs'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['muscle up'],
    localizedLabels: {'de': 'Muscle-up', 'es': 'Muscle-up', 'fr': 'Muscle-up', 'id': 'Muscle-up'},
    bodyweight: true,
  ),
  ExerciseDef(
    'inverted_row',
    'Inverted row',
    ['Lats'],
    secondaryMuscles: ['Biceps', 'Trapezius'],
    category: 'Back',
    equipment: ['Pull-up bar'],
    aliases: ['australian pull-up', 'body row'],
    localizedLabels: {'de': 'Umgekehrtes Rudern', 'es': 'Remo invertido', 'fr': 'Rowing inversé', 'id': 'Inverted row'},
    bodyweight: true,
  ),
  ExerciseDef(
    'dip',
    'Dip',
    ['Chest', 'Triceps'],
    secondaryMuscles: ['Shoulders'],
    category: 'Chest',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['dips', 'parallel bar dip'],
    localizedLabels: {'de': 'Dips am Barren', 'es': 'Fondos en paralelas', 'fr': 'Dips aux barres parallèles', 'id': 'Dip'},
    bodyweight: true,
  ),
  ExerciseDef(
    'bench_dip',
    'Bench dip',
    ['Triceps'],
    secondaryMuscles: ['Chest', 'Shoulders'],
    category: 'Arms',
    equipment: ['Bench'],
    aliases: ['bench dips', 'tricep dip'],
    localizedLabels: {'de': 'Dips an der Bank', 'es': 'Fondos en banco', 'fr': 'Dips sur banc', 'id': 'Dip di bangku'},
    bodyweight: true,
  ),
  ExerciseDef(
    'diamond_push_up',
    'Diamond push-up',
    ['Triceps', 'Chest'],
    secondaryMuscles: ['Shoulders'],
    category: 'Arms',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['diamond push up', 'close push-up'],
    localizedLabels: {'de': 'Diamant-Liegestütz', 'es': 'Flexión diamante', 'fr': 'Pompe diamant', 'id': 'Push-up diamond'},
    bodyweight: true,
  ),
  ExerciseDef(
    'incline_push_up',
    'Incline push-up',
    ['Chest'],
    secondaryMuscles: ['Triceps', 'Shoulders'],
    category: 'Chest',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['incline push up'],
    localizedLabels: {'de': 'Liegestütz mit erhöhten Händen', 'es': 'Flexión inclinada', 'fr': 'Pompe inclinée', 'id': 'Push-up incline'},
    bodyweight: true,
  ),
  ExerciseDef(
    'decline_push_up',
    'Decline push-up',
    ['Chest', 'Shoulders'],
    secondaryMuscles: ['Triceps'],
    category: 'Chest',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['decline push up', 'feet-elevated push-up'],
    localizedLabels: {'de': 'Liegestütz mit erhöhten Füßen', 'es': 'Flexión declinada', 'fr': 'Pompe déclinée', 'id': 'Push-up decline'},
    bodyweight: true,
  ),
  ExerciseDef(
    'pike_push_up',
    'Pike push-up',
    ['Shoulders'],
    secondaryMuscles: ['Triceps'],
    category: 'Shoulders',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['pike push up'],
    localizedLabels: {'de': 'Pike-Liegestütz', 'es': 'Flexión en pica', 'fr': 'Pompe en pike', 'id': 'Pike push-up'},
    bodyweight: true,
  ),
  ExerciseDef(
    'handstand_push_up',
    'Handstand push-up',
    ['Shoulders', 'Triceps'],
    secondaryMuscles: ['Trapezius'],
    category: 'Shoulders',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['hspu', 'handstand push up'],
    localizedLabels: {'de': 'Handstand-Liegestütz', 'es': 'Flexión en parada de manos', 'fr': 'Pompe en équilibre', 'id': 'Handstand push-up'},
    bodyweight: true,
  ),
  ExerciseDef(
    'bodyweight_squat',
    'Bodyweight squat',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['air squat', 'squat'],
    localizedLabels: {'de': 'Kniebeuge ohne Gewicht', 'es': 'Sentadilla sin peso', 'fr': 'Squat au poids du corps', 'id': 'Squat tanpa beban'},
    bodyweight: true,
  ),
  ExerciseDef(
    'jump_squat',
    'Jump squat',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Calves'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['squat jump'],
    localizedLabels: {'de': 'Sprungkniebeuge', 'es': 'Sentadilla con salto', 'fr': 'Squat sauté', 'id': 'Squat lompat'},
    bodyweight: true,
  ),
  ExerciseDef(
    'pistol_squat',
    'Pistol squat',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings', 'Abs'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['one-leg squat', 'single-leg squat'],
    localizedLabels: {'de': 'Pistol Squat', 'es': 'Sentadilla pistol', 'fr': 'Squat pistol', 'id': 'Pistol squat'},
    bodyweight: true,
  ),
  ExerciseDef(
    'lunge',
    'Lunge',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['lunges', 'forward lunge'],
    localizedLabels: {'de': 'Ausfallschritt', 'es': 'Zancada', 'fr': 'Fente', 'id': 'Lunge'},
    bodyweight: true,
  ),
  ExerciseDef(
    'glute_bridge',
    'Glute bridge',
    ['Glutes'],
    secondaryMuscles: ['Hamstrings'],
    category: 'Legs',
    equipment: ['Gym mat'],
    aliases: ['hip bridge'],
    localizedLabels: {'de': 'Glute Bridge', 'es': 'Puente de glúteos', 'fr': 'Pont fessier', 'id': 'Glute bridge'},
    bodyweight: true,
  ),
  ExerciseDef(
    'calf_raise',
    'Standing calf raise',
    ['Calves'],
    secondaryMuscles: ['Soleus'],
    category: 'Calves',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['calf raises', 'heel raise'],
    localizedLabels: {'de': 'Wadenheben stehend', 'es': 'Elevación de talones de pie', 'fr': 'Extension des mollets debout', 'id': 'Calf raise berdiri'},
    bodyweight: true,
  ),
  ExerciseDef(
    'wall_sit',
    'Wall sit',
    ['Quads'],
    secondaryMuscles: ['Glutes'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['wall squat'],
    step: 0,
    localizedLabels: {'de': 'Wandsitzen', 'es': 'Sentadilla isométrica en pared', 'fr': 'Chaise contre le mur', 'id': 'Wall sit'},
    bodyweight: true,
  ),
  ExerciseDef(
    'burpee',
    'Burpee',
    ['Quads', 'Chest'],
    secondaryMuscles: ['Shoulders', 'Abs', 'Glutes'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['burpees'],
    localizedLabels: {'de': 'Burpee', 'es': 'Burpee', 'fr': 'Burpee', 'id': 'Burpee'},
    bodyweight: true,
  ),
  ExerciseDef(
    'box_jump',
    'Box jump',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Calves'],
    category: 'Legs',
    aliases: ['box jumps'],
    localizedLabels: {'de': 'Box Jump', 'es': 'Salto al cajón', 'fr': 'Saut sur box', 'id': 'Box jump'},
    bodyweight: true,
  ),
  ExerciseDef(
    'jumping_jack',
    'Jumping jack',
    ['Calves', 'Shoulders'],
    secondaryMuscles: ['Quads'],
    category: 'Legs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['jumping jacks', 'star jump'],
    localizedLabels: {'de': 'Hampelmann', 'es': 'Saltos de tijera', 'fr': 'Jumping jack', 'id': 'Jumping jack'},
    bodyweight: true,
  ),
  ExerciseDef(
    'crunch',
    'Crunch',
    ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['crunches', 'sit up'],
    localizedLabels: {'de': 'Crunch', 'es': 'Encogimiento abdominal', 'fr': 'Crunch', 'id': 'Crunch'},
    bodyweight: true,
  ),
  ExerciseDef(
    'sit_up',
    'Sit-up',
    ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['sit up', 'sit-ups'],
    localizedLabels: {'de': 'Sit-up', 'es': 'Abdominal completo', 'fr': 'Redressement assis', 'id': 'Sit-up'},
    bodyweight: true,
  ),
  ExerciseDef(
    'bicycle_crunch',
    'Bicycle crunch',
    ['Abs', 'Obliquus externus abdominis'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['bicycle crunches'],
    localizedLabels: {'de': 'Fahrrad-Crunch', 'es': 'Abdominal bicicleta', 'fr': 'Crunch vélo', 'id': 'Bicycle crunch'},
    bodyweight: true,
  ),
  ExerciseDef(
    'russian_twist',
    'Russian twist',
    ['Obliquus externus abdominis'],
    secondaryMuscles: ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['russian twists'],
    localizedLabels: {'de': 'Russian Twist', 'es': 'Giro ruso', 'fr': 'Rotation russe', 'id': 'Russian twist'},
    bodyweight: true,
  ),
  ExerciseDef(
    'lying_leg_raise',
    'Lying leg raise',
    ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['leg raise', 'leg raises'],
    localizedLabels: {'de': 'Beinheben liegend', 'es': 'Elevación de piernas tumbado', 'fr': 'Relevé de jambes allongé', 'id': 'Angkat kaki berbaring'},
    bodyweight: true,
  ),
  ExerciseDef(
    'side_plank',
    'Side plank',
    ['Obliquus externus abdominis'],
    secondaryMuscles: ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['side bridge'],
    step: 0,
    localizedLabels: {'de': 'Seitstütz', 'es': 'Plancha lateral', 'fr': 'Gainage latéral', 'id': 'Plank samping'},
    bodyweight: true,
  ),
  ExerciseDef(
    'mountain_climber',
    'Mountain climber',
    ['Abs'],
    secondaryMuscles: ['Shoulders', 'Quads'],
    category: 'Abs',
    equipment: ['none (bodyweight exercise)'],
    aliases: ['mountain climbers'],
    localizedLabels: {'de': 'Bergsteiger', 'es': 'Escalador', 'fr': 'Grimpeur', 'id': 'Mountain climber'},
    bodyweight: true,
  ),
  ExerciseDef(
    'ab_wheel_rollout',
    'Ab wheel rollout',
    ['Abs'],
    secondaryMuscles: ['Lats', 'Shoulders'],
    category: 'Abs',
    aliases: ['ab roller', 'ab wheel'],
    localizedLabels: {'de': 'Bauchroller', 'es': 'Rueda abdominal', 'fr': 'Roue abdominale', 'id': 'Ab roller'},
    bodyweight: true,
  ),
  ExerciseDef(
    'dead_bug',
    'Dead bug',
    ['Abs'],
    category: 'Abs',
    equipment: ['Gym mat'],
    aliases: ['deadbug'],
    step: 0,
    localizedLabels: {'de': 'Dead Bug', 'es': 'Bicho muerto', 'fr': 'Dead bug', 'id': 'Dead bug'},
    bodyweight: true,
  ),
  ExerciseDef(
    'superman',
    'Superman',
    ['Lower back'],
    secondaryMuscles: ['Glutes'],
    category: 'Back',
    equipment: ['Gym mat'],
    aliases: ['back extension on floor'],
    step: 0,
    localizedLabels: {'de': 'Superman', 'es': 'Superman', 'fr': 'Superman', 'id': 'Superman'},
    bodyweight: true,
  ),
  ExerciseDef(
    'sumo_deadlift',
    'Sumo deadlift',
    ['Glutes', 'Quads'],
    secondaryMuscles: ['Hamstrings', 'Lower back'],
    category: 'Legs',
    equipment: ['Barbell'],
    aliases: ['sumo dl'],
    localizedLabels: {'de': 'Sumo-Kreuzheben', 'es': 'Peso muerto sumo', 'fr': 'Soulevé de terre sumo', 'id': 'Sumo deadlift'},
  ),
  ExerciseDef(
    'trap_bar_deadlift',
    'Trap bar deadlift',
    ['Quads', 'Glutes'],
    secondaryMuscles: ['Hamstrings', 'Lower back', 'Trapezius'],
    category: 'Legs',
    equipment: ['Barbell'],
    aliases: ['hex bar deadlift'],
    localizedLabels: {'de': 'Trap-Bar-Kreuzheben', 'es': 'Peso muerto con barra hexagonal', 'fr': 'Soulevé de terre barre hexagonale', 'id': 'Trap bar deadlift'},
  ),
  ExerciseDef(
    'good_morning',
    'Good morning',
    ['Hamstrings', 'Lower back'],
    secondaryMuscles: ['Glutes'],
    category: 'Legs',
    equipment: ['Barbell'],
    aliases: ['good mornings'],
    localizedLabels: {'de': 'Good Morning', 'es': 'Buenos días', 'fr': 'Good morning', 'id': 'Good morning'},
  ),
  ExerciseDef(
    'farmers_walk',
    'Farmer\'s walk',
    ['Trapezius'],
    secondaryMuscles: ['Abs', 'Shoulders'],
    category: 'Back',
    equipment: ['Dumbbell'],
    aliases: ['farmer carry', 'farmers carry'],
    step: 2,
    localizedLabels: {'de': 'Farmer\'s Walk', 'es': 'Paseo del granjero', 'fr': 'Marche du fermier', 'id': 'Farmer\'s walk'},
  ),
];

const exerciseLibrary = <ExerciseDef>[
  ..._edgeExerciseLibrary,
  ..._extraExerciseLibrary,
  ..._wgerExerciseLibrary,
];

final coreExerciseCount = _edgeExerciseLibrary.length;
final extraExerciseCount = _extraExerciseLibrary.length;
final wgerExerciseCount = _wgerExerciseLibrary.length;

final Map<String, ExerciseDef> _exercisesByKey = {
  for (final e in exerciseLibrary) e.key: e,
};

ExerciseDef? exerciseByKey(String key) => _exercisesByKey[key];
