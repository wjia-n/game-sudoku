import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/services/settings_service.dart';

/// Regression test for the 2026-10-09 player-name persistence audit:
/// player names must be persisted in an order-preserving way. On Android,
/// SharedPreferences.setStringList is backed by an UNORDERED StringSet, so
/// any ordered name data stored through it comes back scrambled after a
/// restart (the bug fixed in ludo).
///
/// Sudoku stores its single profile name with plain setString
/// ('sudoku_profile_name') — inherently order-safe — and must keep doing so.
/// This test fails if names ever move to setStringList, and verifies the
/// rename path (including focus-loss commit in the UI, which funnels through
/// setProfileName) survives a simulated app restart.
void main() {
  test('profile name persists verbatim across a restart (order-safe)', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SudoSettings();
    await s.load();
    expect(s.profileName, 'Player');

    // Rename: this is the exact funnel the rename dialog commits through,
    // including the focus-loss commit path.
    await s.setProfileName('Wajiha');
    expect(s.profileName, 'Wajiha');

    // Simulate an app restart: fresh settings instance, same prefs store.
    final restarted = SudoSettings();
    await restarted.load();
    expect(restarted.profileName, 'Wajiha');

    // The persisted value must be a plain string key, not a StringList:
    // a StringList is unordered on Android and would scramble ordered data.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sudoku_profile_name'), 'Wajiha');
    // The key must NOT hold a StringList: reading a String-typed key as a
    // list throws in the mock (and on Android a StringList is unordered).
    expect(() => prefs.getStringList('sudoku_profile_name'), throwsA(anything));

    // Blank renames fall back to the default rather than persisting empty.
    await restarted.setProfileName('   ');
    expect(restarted.profileName, 'Player');
    final restarted2 = SudoSettings();
    await restarted2.load();
    expect(restarted2.profileName, 'Player');
  });
}
