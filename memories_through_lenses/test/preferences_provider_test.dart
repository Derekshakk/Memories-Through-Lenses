import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memories_through_lenses/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults keep the current design and Popular feed', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesProvider.load();
    expect(prefs.textScale, 1.0);
    expect(prefs.feedSort, FeedSort.popular);
  });

  test('feed sort and text size survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await PreferencesProvider.load();
    await first.setFeedSort(FeedSort.recent);
    await first.setTextScale(1.3);

    final restarted = await PreferencesProvider.load();
    expect(restarted.feedSort, FeedSort.recent);
    expect(restarted.textScale, 1.3);
  });

  test('corrupt stored values fall back safely', () async {
    SharedPreferences.setMockInitialValues(
        {PreferencesProvider.feedSortKey: 'bogus', PreferencesProvider.textScaleKey: 9.0});
    final prefs = await PreferencesProvider.load();
    expect(prefs.feedSort, FeedSort.popular);
    expect(prefs.textScale, 1.3); // clamped
  });

  testWidgets('text size is applied on top of the system scale',
      (tester) async {
    final prefs = PreferencesProvider(textScale: 1.3);
    late double scaled;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
      child: Builder(
        builder: (context) => prefs.applyTextScale(
          context,
          Builder(builder: (inner) {
            scaled = MediaQuery.textScalerOf(inner).scale(10);
            return const SizedBox();
          }),
        ),
      ),
    ));
    expect(scaled, closeTo(10 * 1.5 * 1.3, 0.001));
  });
}
