import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// The single toast used across the app. Every screen calls
/// [AppToast.show]; its look, motion and timing live only in this file.
enum AppToastType { success, info, warning, error }

/// Why a toast closed. Only [action] means the user tapped the action
/// (e.g. Undo); every other reason lets the pending change go through.
enum AppToastClosedReason { timeout, dismissed, action, replaced }

class AppToast {
  AppToast._();

  static const Duration defaultDuration = Duration(seconds: 3);

  /// Toasts with an action stay a little longer so there is time to tap it.
  static const Duration actionDuration = Duration(seconds: 4);

  static const double _tabletMaxWidth = 420;

  static _ToastHandle? _current;

  /// Shows a toast that slides in from the left, counts down, and slides
  /// out to the right. A new toast replaces the one on screen.
  static Future<AppToastClosedReason> show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.success,
    String? actionLabel,
    Duration? duration,
  }) {
    return showOn(
      AppToastHost._key.currentState ?? Overlay.of(context, rootOverlay: true),
      message: message,
      type: type,
      actionLabel: actionLabel,
      duration: duration,
    );
  }

  /// Same as [show] for callers that captured the overlay before an `await`.
  static Future<AppToastClosedReason> showOn(
    OverlayState overlay, {
    required String message,
    AppToastType type = AppToastType.success,
    String? actionLabel,
    Duration? duration,
  }) {
    _current?.close(AppToastClosedReason.replaced);
    final handle = _ToastHandle();
    handle.entry = OverlayEntry(
      builder: (_) => _AppToastView(
        key: handle.key,
        message: message,
        type: type,
        actionLabel: actionLabel,
        duration:
            duration ??
            (actionLabel != null ? actionDuration : defaultDuration),
        onClosed: handle.finish,
        onDisposed: handle.complete,
      ),
    );
    _current = handle;
    overlay.insert(handle.entry);
    return handle.completer.future.whenComplete(() {
      if (identical(_current, handle)) _current = null;
    });
  }

  /// Closes the toast on screen, if any.
  static void hide() => _current?.close(AppToastClosedReason.dismissed);

  static Color background(AppToastType type) => switch (type) {
    AppToastType.success => AppTheme.toastSuccess,
    AppToastType.info => AppTheme.toastInfo,
    AppToastType.warning => AppTheme.toastWarning,
    AppToastType.error => AppTheme.toastError,
  };

  static Color foreground(AppToastType type) => switch (type) {
    AppToastType.success => AppTheme.toastOnSuccess,
    AppToastType.info => AppTheme.toastOnInfo,
    AppToastType.warning => AppTheme.toastOnWarning,
    AppToastType.error => AppTheme.toastOnError,
  };

  static IconData icon(AppToastType type) => switch (type) {
    AppToastType.success => Icons.check_circle_rounded,
    AppToastType.info => Icons.info_rounded,
    AppToastType.warning => Icons.warning_rounded,
    AppToastType.error => Icons.error_rounded,
  };
}

/// Wraps the whole app (via `MaterialApp.builder`) in a layer above the
/// navigator, so toasts float over every page, dialog and bottom sheet.
class AppToastHost extends StatefulWidget {
  const AppToastHost({super.key, required this.child});

  final Widget child;

  static final GlobalKey<OverlayState> _key = GlobalKey<OverlayState>();

  @override
  State<AppToastHost> createState() => _AppToastHostState();
}

class _AppToastHostState extends State<AppToastHost> {
  late final OverlayEntry _app = OverlayEntry(
    opaque: true,
    maintainState: true,
    builder: (_) => widget.child,
  );

  @override
  void didUpdateWidget(AppToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _app.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) =>
      Overlay(key: AppToastHost._key, initialEntries: [_app]);
}

/// Marks a bar pinned to the bottom of the screen (e.g. the phone nav bar)
/// so toasts float above it while it is on screen.
class AppToastBottomBar extends StatefulWidget {
  const AppToastBottomBar({super.key, required this.child});

  final Widget child;

  @override
  State<AppToastBottomBar> createState() => _AppToastBottomBarState();

  /// Height of the visible bottom bar, or 0 when none is showing.
  static double visibleHeight() {
    for (final bar in _AppToastBottomBarState._bars) {
      if (!bar.mounted) continue;
      // Off when a full page covers it; still on under dialogs and sheets.
      if (!bar._visible) continue;
      final box = bar.context.findRenderObject();
      if (box is RenderBox && box.hasSize) return box.size.height;
    }
    return 0;
  }
}

class _AppToastBottomBarState extends State<AppToastBottomBar> {
  static final Set<_AppToastBottomBarState> _bars = {};

  @override
  void initState() {
    super.initState();
    _bars.add(this);
  }

  @override
  void dispose() {
    _bars.remove(this);
    super.dispose();
  }

  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    return widget.child;
  }
}

class _ToastHandle {
  final key = GlobalKey<_AppToastViewState>();
  final completer = Completer<AppToastClosedReason>();
  late final OverlayEntry entry;

  void close(AppToastClosedReason reason) {
    final state = key.currentState;
    if (state != null && state.mounted) {
      state.dismiss(reason);
    } else {
      finish(reason);
    }
  }

  void finish(AppToastClosedReason reason) {
    if (entry.mounted) entry.remove();
    complete(reason);
  }

  void complete(AppToastClosedReason reason) {
    if (!completer.isCompleted) completer.complete(reason);
  }
}

class _AppToastView extends StatefulWidget {
  const _AppToastView({
    super.key,
    required this.message,
    required this.type,
    required this.actionLabel,
    required this.duration,
    required this.onClosed,
    required this.onDisposed,
  });

  final String message;
  final AppToastType type;
  final String? actionLabel;
  final Duration duration;
  final ValueChanged<AppToastClosedReason> onClosed;
  final ValueChanged<AppToastClosedReason> onDisposed;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _countdown = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  AppToastClosedReason? _closing;

  @override
  void initState() {
    super.initState();
    _enter.forward();
    _countdown
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          dismiss(AppToastClosedReason.timeout);
        }
      })
      ..forward();
  }

  void dismiss(AppToastClosedReason reason) {
    if (_closing != null) return;
    _closing = reason;
    _countdown.stop();
    _exit.forward().then((_) {
      if (mounted) widget.onClosed(reason);
    });
  }

  @override
  void dispose() {
    // Torn down with the app (e.g. tests): still report a close so callers
    // waiting on the result are not left hanging.
    widget.onDisposed(_closing ?? AppToastClosedReason.dismissed);
    _enter.dispose();
    _exit.dispose();
    _countdown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= 600;
    final fg = AppToast.foreground(widget.type);

    final card = Material(
      color: AppToast.background(widget.type),
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
            child: Row(
              children: [
                Icon(AppToast.icon(widget.type), size: 22, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: GoogleFonts.plusJakartaSans(
                      color: fg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (widget.actionLabel != null)
                  TextButton(
                    onPressed: () => dismiss(AppToastClosedReason.action),
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      minimumSize: const Size(48, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(widget.actionLabel!),
                  )
                else
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => dismiss(AppToastClosedReason.dismissed),
                    icon: Icon(Icons.close_rounded, size: 18, color: fg),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _countdown,
              builder: (context, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 1 - _countdown.value,
                  child: Container(
                    height: 3,
                    color: fg.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: card,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _exit]),
      builder: (context, child) {
        final enterT = Curves.easeOutCubic.transform(_enter.value);
        final exitT = Curves.easeInCubic.transform(_exit.value);
        final dx = -media.size.width * (1 - enterT) + media.size.width * exitT;
        final bottom =
            [
              AppToastBottomBar.visibleHeight(),
              media.viewPadding.bottom,
              media.viewInsets.bottom,
            ].reduce((a, b) => a > b ? a : b) +
            12;
        return Positioned(
          left: 12,
          right: 12,
          bottom: bottom,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Opacity(opacity: (1 - exitT).clamp(0, 1), child: child),
          ),
        );
      },
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? AppToast._tabletMaxWidth : double.infinity,
            ),
            child: shadowed,
          ),
        ),
      ),
    );
  }
}
