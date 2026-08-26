import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';

/// Physics constants for [MagneticPagePhysics].
class MagneticPagePhysics extends PageScrollPhysics {
  /// Fraction of the page width a slow drag must travel past the current
  /// page's edge to magnetically commit to turning (0.45 ~= 45%).
  final double snapThreshold;

  /// Release velocity (logical px/s) above which a drag counts as a flick
  /// and turns the page regardless of distance.
  final double flingVelocity;

  const MagneticPagePhysics({
    this.snapThreshold = 0.45,
    this.flingVelocity = 400,
    super.parent,
  });

  @override
  MagneticPagePhysics applyTo(ScrollPhysics? ancestor) {
    return MagneticPagePhysics(
      snapThreshold: snapThreshold,
      flingVelocity: flingVelocity,
      parent: buildParent(ancestor),
    );
  }

  /// Decide which page to settle on when the drag releases.
  ///
  /// [progress] is the scroll offset expressed in pages (3.4 = 40% of the
  /// way from page 3 to page 4); valid range [0, pageCount - 1].
  ///
  /// Rules:
  /// - Flicks (|velocity| >= flingVelocity): turn in the flick direction,
  ///   regardless of distance travelled.
  /// - Slow drags: commit to the next page once pulled more than
  ///   [snapThreshold] past its previous edge; otherwise spring back.
  static int magneticTarget({
    required double progress,
    required double velocity,
    required int pageCount,
    double snapThreshold = 0.45,
    double flingVelocity = 400,
  }) {
    if (pageCount <= 0) return 0;
    final p = progress.clamp(0.0, (pageCount - 1).toDouble());

    final base = p.floorToDouble();
    final frac = p - base;
    final currentPage = base.toInt();

    int target;
    if (velocity.abs() >= flingVelocity) {
      // Flick: turn in the flick's direction.
      target = velocity > 0 ? currentPage + 1 : currentPage;
    } else {
      // Magnetic: crossed snapThreshold of the way to the neighbor?
      target = currentPage + (frac > snapThreshold ? 1 : 0);
    }
    return target.clamp(0, pageCount - 1);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final dimension = position.viewportDimension;
    final scrollable =
        position.maxScrollExtent > position.minScrollExtent && dimension > 0;
    if (!scrollable) {
      return super.createBallisticSimulation(position, velocity);
    }

    final progress = position.pixels / dimension;
    final pageCount = (position.maxScrollExtent / dimension).floor() + 1;

    final target = magneticTarget(
      progress: progress,
      velocity: velocity,
      pageCount: pageCount,
      snapThreshold: snapThreshold,
      flingVelocity: flingVelocity,
    );

    final targetPixels = target * dimension;
    if ((targetPixels - position.pixels).abs() < precisionErrorTolerance) {
      return null; // Already settled on the chosen page.
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
    );
  }
}


