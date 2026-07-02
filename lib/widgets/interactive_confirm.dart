import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';

// ── Swipe-to-confirm ──────────────────────────────────────────────────────────

class SwipeToConfirm extends StatefulWidget {
  final String label;
  final Color color;
  final bool loading;
  final bool enabled;
  final double height;
  final VoidCallback? onConfirmed;

  const SwipeToConfirm({
    super.key,
    required this.label,
    required this.color,
    this.loading = false,
    this.enabled = true,
    this.height = 52,
    this.onConfirmed,
  });

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm>
    with SingleTickerProviderStateMixin {
  static const double _thumbSize = 46;
  static const double _threshold = 0.85;

  double _dragProgress = 0;
  bool _isDragging = false;
  bool _confirmed = false;
  double _trackWidth = 0;

  late final AnimationController _snapCtrl;
  double _snapFrom = 0;
  double _snapTo = 0;

  double get _maxDragPx =>
      (_trackWidth - _thumbSize - 8).clamp(1.0, double.infinity);

  double get _vp {
    if (_isDragging) return _dragProgress;
    final t = Curves.easeOutCubic.transform(_snapCtrl.value.clamp(0, 1));
    return (_snapFrom + (_snapTo - _snapFrom) * t).clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _snapCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _snapCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && _confirmed) {
        widget.onConfirmed?.call();
        // Auto-reset if loading was never set (sync validation errors don't trigger didUpdateWidget)
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _confirmed && !widget.loading) _resetState();
        });
      }
    });
  }

  @override
  void didUpdateWidget(SwipeToConfirm old) {
    super.didUpdateWidget(old);
    // Reset when loading finishes (success or error)
    if (old.loading && !widget.loading && _confirmed) {
      _resetState();
    }
    // Also reset if action never set loading=true (e.g. sync validation error)
    if (_confirmed && !widget.loading && !old.loading) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _confirmed && !widget.loading) _resetState();
      });
    }
  }

  void _resetState() {
    setState(() {
      _confirmed = false;
      _dragProgress = 0;
      _snapFrom = 0;
      _snapTo = 0;
    });
    _snapCtrl.value = 0;
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    if (!widget.enabled || widget.loading || _confirmed) return;
    _snapCtrl.stop();
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.enabled || widget.loading || _confirmed) return;
    setState(() {
      _dragProgress =
          (_dragProgress + d.delta.dx / _maxDragPx).clamp(0, 1);
    });
    if (_dragProgress >= _threshold) _doConfirm();
  }

  void _onDragEnd(DragEndDetails _) {
    if (_confirmed) return;
    _snapFrom = _dragProgress;
    _snapTo = 0;
    setState(() {
      _isDragging = false;
      _dragProgress = 0;
    });
    _snapCtrl.forward(from: 0);
  }

  void _doConfirm() {
    if (_confirmed) return;
    HapticFeedback.mediumImpact();
    _snapFrom = _dragProgress;
    _snapTo = 1.0;
    setState(() {
      _confirmed = true;
      _isDragging = false;
    });
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    final col = active ? widget.color : AppColors.textMuted.withOpacity(0.5);
    final vp = _vp;
    final thumbLeft = 4 + vp * _maxDragPx;

    return LayoutBuilder(builder: (context, constraints) {
      _trackWidth = constraints.maxWidth;
      return GestureDetector(
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: SizedBox(
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track — solid pre-blended bg so it renders correctly on any parent color
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.white, col, 0.28)!,
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    border: Border.all(
                        color: col.withOpacity(0.55), width: 1.5),
                  ),
                ),
              ),

              // Fill
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: vp,
                    child: Container(color: col),
                  ),
                ),
              ),

              // Arrow trail hints + label
              if (!_confirmed)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 50),
                        ...List.generate(3, (i) => Opacity(
                          opacity: (0.4 + i * 0.15) * (1 - vp * 1.5).clamp(0, 1),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white,
                              size: 15),
                        )),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              shadows: [
                                Shadow(color: Color(0x70000000), blurRadius: 4, offset: Offset(0, 1)),
                                Shadow(color: Color(0x50000000), blurRadius: 4, offset: Offset(0, -1)),
                                Shadow(color: Color(0x50000000), blurRadius: 4, offset: Offset(1, 0)),
                                Shadow(color: Color(0x50000000), blurRadius: 4, offset: Offset(-1, 0)),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),

              // "Confirmed" text fades in
              if (_confirmed && vp > 0.5)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: ((vp - 0.5) * 2).clamp(0, 1),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text('Confirmed!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Thumb
              Positioned(
                left: thumbLeft,
                top: (widget.height - _thumbSize) / 2,
                child: AnimatedScale(
                  scale: _isDragging ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: col.withOpacity(0.3),
                          blurRadius: _isDragging ? 14 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: widget.loading
                        ? Padding(
                            padding: const EdgeInsets.all(13),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: col,
                            ),
                          )
                        : _confirmed
                        ? const Icon(Icons.check_rounded,
                            color: Colors.transparent, size: 20)
                        : Icon(Icons.arrow_forward_rounded,
                            color: col, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Hold-to-confirm button ────────────────────────────────────────────────────

class HoldToConfirm extends StatefulWidget {
  final String label;
  final Color color;
  final Duration holdDuration;
  final bool loading;
  final bool enabled;
  final double height;
  final VoidCallback? onConfirmed;

  const HoldToConfirm({
    super.key,
    required this.label,
    required this.color,
    this.holdDuration = const Duration(milliseconds: 1100),
    this.loading = false,
    this.enabled = true,
    this.height = 52,
    this.onConfirmed,
  });

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _pressing = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.holdDuration);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_completed) _onComplete();
    });
  }

  @override
  void didUpdateWidget(HoldToConfirm old) {
    super.didUpdateWidget(old);
    if (old.loading && !widget.loading && _completed) {
      _resetState();
    }
    if (_completed && !widget.loading && !old.loading) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _completed && !widget.loading) _resetState();
      });
    }
  }

  void _resetState() {
    setState(() => _completed = false);
    _ctrl.value = 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startHold() {
    if (!widget.enabled || widget.loading || _completed) return;
    setState(() => _pressing = true);
    _ctrl.forward();
  }

  void _endHold() {
    if (_completed) return;
    setState(() => _pressing = false);
    _ctrl.reverse();
  }

  void _onComplete() {
    HapticFeedback.heavyImpact();
    setState(() {
      _completed = true;
      _pressing = false;
    });
    widget.onConfirmed?.call();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _completed && !widget.loading) _resetState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.loading;
    final baseCol = active ? widget.color : AppColors.textMuted.withOpacity(0.5);

    return GestureDetector(
      onTapDown: active ? (_) => _startHold() : null,
      onTapUp: (_) => _endHold(),
      onTapCancel: () => _endHold(),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final p = _ctrl.value;
            return SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  // Base
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: baseCol,
                        borderRadius:
                            BorderRadius.circular(widget.height / 2),
                      ),
                    ),
                  ),

                  // White fill expanding left→right while holding
                  if (!_completed && p > 0)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(widget.height / 2),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: p,
                          child: Container(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                      ),
                    ),

                  // Content
                  Positioned.fill(
                    child: Center(
                      child: widget.loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            )
                          : _completed
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text('Confirmed!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    )),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.touch_app_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      widget.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                SizedBox(
                                  width: 80,
                                  height: 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: p,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.25),
                                      valueColor:
                                          const AlwaysStoppedAnimation(
                                              Colors.white),
                                      minHeight: 3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
