import 'package:flutter_test/flutter_test.dart';
import 'package:epub_reader/widgets/magnetic_page_physics.dart';

void main() {
  const threshold = 0.2;
  const fling = 400.0;

  int target({
    required double progress,
    double velocity = 0,
    int pageCount = 10,
  }) {
    return MagneticPagePhysics.magneticTarget(
      progress: progress,
      velocity: velocity,
      pageCount: pageCount,
      snapThreshold: threshold,
      flingVelocity: fling,
    );
  }

  group('MagneticPagePhysics.magneticTarget', () {
    test('slow drag under 20% springs back to current page', () {
      expect(target(progress: 3.0), 3);
      expect(target(progress: 3.05), 3);
      expect(target(progress: 3.19), 3);
    });

    test('slow drag past 20% magnetically commits to next page', () {
      expect(target(progress: 3.21), 4);
      expect(target(progress: 3.5), 4);
      expect(target(progress: 3.99), 4);
    });

    test('dragging back most of the way returns to previous page', () {
      // Sitting at page 4, pulled back to 80% of the way to page 3.
      expect(target(progress: 3.8), 4);
      // Pulled past the magnetic point -> commits backward.
      expect(target(progress: 3.75), 4); // exactly at boundary region
      expect(target(progress: 3.15), 3);
    });

    test('quick flicks turn regardless of distance', () {
      // Tiny forward nudge with a fast flick.
      expect(target(progress: 3.01, velocity: fling), 4);
      // Tiny backward nudge with a fast flick.
      expect(target(progress: 3.99, velocity: -fling), 3);
      // Slow-ish releases do NOT count as flicks.
      expect(target(progress: 3.01, velocity: fling / 2), 3);
      expect(target(progress: 3.99, velocity: -fling / 2), 4);
    });

    test('clamps to first and last pages', () {
      final last = MagneticPagePhysics.magneticTarget(
        progress: 9.9,
        velocity: fling,
        pageCount: 10,
        snapThreshold: threshold,
        flingVelocity: fling,
      );
      expect(last, 9);

      final firstBack = MagneticPagePhysics.magneticTarget(
        progress: 0.0,
        velocity: -fling,
        pageCount: 10,
        snapThreshold: threshold,
        flingVelocity: fling,
      );
      expect(firstBack, 0);

      final beyondEnd = MagneticPagePhysics.magneticTarget(
        progress: 12.0,
        velocity: 0,
        pageCount: 10,
        snapThreshold: threshold,
        flingVelocity: fling,
      );
      expect(beyondEnd, 9);
    });

    test('handles degenerate page counts', () {
      expect(target(progress: 0, pageCount: 0), 0);
      expect(target(progress: 0.5, pageCount: 1), 0);
      expect(
        MagneticPagePhysics.magneticTarget(
          progress: 0.9,
          velocity: fling,
          pageCount: 1,
          snapThreshold: threshold,
          flingVelocity: fling,
        ),
        0,
      );
    });

    test('higher threshold (45%) requires a longer drag to commit', () {
      int targetAt(double progress) {
        return MagneticPagePhysics.magneticTarget(
          progress: progress,
          velocity: 0,
          pageCount: 10,
          snapThreshold: 0.45,
          flingVelocity: fling,
        );
      }

      // Under 45% springs back.
      expect(targetAt(3.30), 3);
      expect(targetAt(3.44), 3);
      // Past 45% commits forward.
      expect(targetAt(3.46), 4);
      expect(targetAt(3.75), 4);
      // Returning backward must pull under 55% of the way from page 4.
      expect(targetAt(3.60), 4);
      expect(targetAt(3.54), 4);
    });
  });
}
