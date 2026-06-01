import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/skill_progress.dart';
import '../../auth/data/auth_repository.dart';

/// A user's saved progress on one skill (independent of the preset tree).
typedef SavedSkill = ({int currentStepIndex, List<SkillLog> logs});

/// Overlays saved per-skill progress (current step + logs) onto the preset
/// trees. Saved entries with no matching preset are intentionally dropped (a
/// removed/renamed preset shouldn't surface stale progress). Pure.
List<SkillProgress> mergeSkills(
  List<SkillProgress> presets,
  Map<String, SavedSkill> saved,
) =>
    presets.map((p) {
      final s = saved[p.id];
      return s == null
          ? p
          : p.copyWith(currentStepIndex: s.currentStepIndex, logs: s.logs);
    }).toList();

/// Preset skill trees (assets) merged with the user's saved progress
/// (`users/{uid}/skills/{skillId}` = `{currentStepIndex, logs}`).
abstract interface class SkillRepository {
  Future<List<SkillProgress>> presets();

  /// The user's skills (preset trees + their saved step/logs), live.
  Stream<List<SkillProgress>> watch(String uid);

  Future<void> logAttempt(String uid, String skillId, SkillLog log);

  Future<void> setStep(String uid, String skillId, int currentStepIndex);
}

class FirestoreSkillRepository implements SkillRepository {
  FirestoreSkillRepository(
    this._db, {
    AssetBundle? bundle,
    String assetPath = _asset,
  })  : _bundle = bundle,
        _assetPath = assetPath;

  static const _asset = 'assets/data/skills.json';

  final FirebaseFirestore _db;
  final AssetBundle? _bundle;
  final String _assetPath;

  List<SkillProgress>? _cache;

  AssetBundle get _assets => _bundle ?? rootBundle;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('skills');

  @override
  Future<List<SkillProgress>> presets() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _assets.loadString(_assetPath);
    final decoded = json.decode(raw) as List<dynamic>;
    return _cache = decoded
        .map((s) => SkillProgress.fromJson(s as Map<String, dynamic>))
        .toList(growable: false);
  }

  SavedSkill _savedFrom(Map<String, dynamic> data) => (
        currentStepIndex: (data['currentStepIndex'] as num?)?.toInt() ?? 0,
        logs: (data['logs'] as List<dynamic>? ?? [])
            .map((e) => SkillLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  @override
  Stream<List<SkillProgress>> watch(String uid) async* {
    final presetList = await presets();
    yield presetList; // before any saved progress arrives
    yield* _col(uid).snapshots().map((snap) {
      final saved = {
        for (final d in snap.docs) d.id: _savedFrom(d.data()),
      };
      return mergeSkills(presetList, saved);
    });
  }

  @override
  Future<void> logAttempt(String uid, String skillId, SkillLog log) {
    // A transaction (read-append-write), NOT arrayUnion — arrayUnion has set
    // semantics and would silently drop a repeated identical attempt.
    final doc = _col(uid).doc(skillId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(doc);
      final logs = [
        ...?(snap.data()?['logs'] as List<dynamic>?),
        log.toJson(),
      ];
      tx.set(doc, {'logs': logs}, SetOptions(merge: true));
    });
  }

  @override
  Future<void> setStep(String uid, String skillId, int currentStepIndex) =>
      _col(uid).doc(skillId).set(
        {'currentStepIndex': currentStepIndex},
        SetOptions(merge: true),
      );
}

final skillRepositoryProvider = Provider<SkillRepository>(
  (ref) => FirestoreSkillRepository(ref.watch(firestoreProvider)),
);

/// The user's skills (preset trees + saved progress), live. Empty when signed
/// out.
final userSkillsProvider = StreamProvider<List<SkillProgress>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(skillRepositoryProvider).watch(uid);
});
