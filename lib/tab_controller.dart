import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Specifies which side the tabs will be on.
enum TabEdge { left, top, right, bottom }

@Deprecated('Use native TabController instead.')
class TabContainerController extends ValueNotifier<int> {
  TabContainerController(super.value);
}

extension on double {
  bool isBetween(double num1, double num2) {
    return num1 <= this && this <= num2;
  }
}

class _TabMetrics {
  _TabMetrics({
    required this.count,
    required this.range,
    required this.minLength,
    required this.maxLength,
  });

  final int count;
  final double range;
  final double minLength;
  final double maxLength;

  double get length => (range / count).clamp(minLength, maxLength);

  double get totalLength => count * length;
}

class _TabViewport {
  _TabViewport({
    required this.parentSize,
    required this.tabEdge,
    required this.tabExtent,
    required this.tabsStart,
    required this.tabsEnd,
  });

  final Size parentSize;
  final TabEdge tabEdge;
  final double tabExtent;
  final double tabsStart;
  final double tabsEnd;

  double get side => (tabEdge == TabEdge.top || tabEdge == TabEdge.bottom)
      ? parentSize.width
      : parentSize.height;

  double get start => side * tabsStart;

  double get end => side * tabsEnd;

  double get range => end - start;

  Size get size => (tabEdge == TabEdge.top || tabEdge == TabEdge.bottom)
      ? Size(range, tabExtent)
      : Size(tabExtent, range);

  bool contains(double x, double y, double totalLength) {
    final double minEnd = min(end, start + totalLength);
    switch (tabEdge) {
      case TabEdge.left:
        if (x <= tabExtent && y.isBetween(start, minEnd)) {
          return true;
        }
        break;
      case TabEdge.top:
        if (y <= tabExtent && x.isBetween(start, minEnd)) {
          return true;
        }
        break;
      case TabEdge.right:
        if (x >= parentSize.width - tabExtent && y.isBetween(start, minEnd)) {
          return true;
        }
        break;
      case TabEdge.bottom:
        if (y >= parentSize.height - tabExtent && x.isBetween(start, minEnd)) {
          return true;
        }
        break;
    }

    return false;
  }
}

/// Displays [children] in accordance with the tab selection.
///
/// Handles styling and animation and exposes control over tab selection through [TabController].
class TabContainer extends StatefulWidget {
  const TabContainer({
    super.key,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.controller,
    this.children,
    this.child,
    required this.tabs,
    this.childPadding = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.tabBorderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.tabExtent = 50.0,
    this.tabEdge = TabEdge.top,
    this.tabsStart = 0.0,
    this.tabsEnd = 1.0,
    this.tabMinLength = 0,
    this.tabMaxLength = double.infinity,
    this.color,
    this.colors,
    this.transitionBuilder,
    this.overrideTextProperties = false,
    this.selectedTextStyle,
    this.unselectedTextStyle,
    this.textDirection,
    this.enabled = true,
    this.enableFeedback = true,
    this.childDuration,
    this.childCurve,
    @Deprecated('Replaced with borderRadius and tabBorderRadius.') radius,
    @Deprecated('String tabs should be replaced with Text widgets.')
    isStringTabs,
    @Deprecated('Use duration instead') tabDuration,
    @Deprecated('Use curve instead') tabCurve,
    @Deprecated('Use tabsStart instead') tabStart,
    @Deprecated('Use tabsEnd instead') tabEnd,
  })  : assert((children == null) != (child == null)),
        assert((children != null) ? children.length == tabs.length : true),
        assert(controller == null ? true : controller.length == tabs.length),
        assert(!(color != null && colors != null)),
        assert((colors ?? tabs).length == tabs.length),
        assert(tabExtent >= 0),
        assert(0.0 <= tabsStart && tabsStart < tabsEnd && tabsEnd <= 1.0),
        assert(tabMinLength >= 0),
        assert(tabMaxLength >= tabMinLength),
        assert((selectedTextStyle == null) == (unselectedTextStyle == null));

  /// Changes tab selection from elsewhere in your app.
  ///
  /// If you provide one, you must dispose of it.
  final TabController? controller;

  /// The list of children you want to tab through, in order.
  ///
  /// Must be equal in length to [tabs] and [colors] (if provided).
  /// Must be null if [child] is supplied.
  final List<Widget>? children;

  /// Supply this if you want to control the child view yourself using [TabController].
  ///
  /// Must be equal in length to [tabs] and [colors] (if provided).
  /// Must be null if [children] is supplied;
  final Widget? child;

  /// What will be displayed in each tab, in order.
  ///
  /// Must be equal in length to [children] and [colors] (if provided).
  final List<Widget> tabs;

  /// Sets the border radius surrounding the children
  ///
  /// Defaults to [BorderRadius.all(Radius.circular(12.0))]
  final BorderRadius borderRadius;

  /// Sets the border radius surrounding each tab
  ///
  /// Defaults to [BorderRadius.all(Radius.circular(12.0))]
  final BorderRadius tabBorderRadius;

  /// Sets the padding to be applied around all [children].
  ///
  /// Defaults to [EdgeInsets.zero].
  final EdgeInsets childPadding;

  /// Height of the tabs perpendicular to the [TabEdge].
  ///
  /// If the [tabs] are on the left/right then this will be the their visual width, otherwise it will be their visual height.
  /// Defaults to 50.0.
  final double tabExtent;

  /// Determines which side the [tabs] will be on.
  ///
  /// Defaults to [TabEdge.top].
  final TabEdge tabEdge;

  /// Fraction of the way down the [TabEdge] that the first tab should begin.
  ///
  /// Defaults to 0.0.
  final double tabsStart;

  /// Fraction of the way down the [TabEdge] that the last tab should end.
  ///
  /// Defaults to 1.0.
  final double tabsEnd;

  /// Minimum width of each tab parallel to the [TabEdge].
  ///
  /// Defaults to 0.0
  final double tabMinLength;

  /// Maximum width of each tab parallel to the [TabEdge].
  ///
  /// Defaults to [double.infinity].
  final double tabMaxLength;

  /// The background color of this widget.
  ///
  /// Must not be set if [colors] is provided.
  final Color? color;

  /// The list of colors used for each tab, in order.
  ///
  /// The first color in the list will be the background color when tab 1 is selected and so on.
  /// Must not be set if [color] is provided.
  final List<Color>? colors;

  /// Duration used by [controller] to animate tab changes.
  ///
  /// Defaults to Duration(milliseconds: 300).
  final Duration duration;

  /// Curve used by [controller] to animate tab changes.
  ///
  /// Defaults to Curves.easeInOut.
  final Curve curve;

  /// Duration of the child transition animation when the tab selection changes.
  ///
  /// Defaults to [duration].
  /// Not used if [child] is supplied.
  final Duration? childDuration;

  /// The curve of the child transition animation when the tab selection changes.
  ///
  /// Defaults to [curve].
  /// Not used if [child] is supplied.
  final Curve? childCurve;

  /// Sets the child transition animation when the tab selection changes.
  ///
  /// Defaults to [AnimatedSwitcher.defaultTransitionBuilder].
  /// Not used if [child] is supplied.
  final Widget Function(Widget, Animation<double>)? transitionBuilder;

  /// Set to true if each [Text] tabs given properties should be used instead of the implicitly animated ones.
  ///
  /// Defaults to false.
  final bool overrideTextProperties;

  /// The [TextStyle] applied to the text of the currently selected tab.
  ///
  /// Must specify values for the same properties as [unselectedTextStyle].
  /// Defaults to Theme.of(context).textTheme.bodyMedium.
  final TextStyle? selectedTextStyle;

  /// The [TextStyle] applied to the text of currently unselected tabs.
  ///
  /// Must specify values for the same properties as [selectedTextStyle].
  /// Defaults to Theme.of(context).textTheme.bodyMedium.
  final TextStyle? unselectedTextStyle;

  /// The [TextDirection] for tabs and semantics.
  ///
  /// Defaults to Directionality.of(context).
  final TextDirection? textDirection;

  /// Whether tab selection changes on tap.
  ///
  /// Defaults to true.
  final bool enabled;

  /// Whether detected gestures on tabs should provide acoustic and/or haptic feedback.
  ///
  /// Defaults to true.
  final bool enableFeedback;

  @override
  _TabContainerState createState() => _TabContainerState();
}

class _TabContainerState extends State<TabContainer>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  late ScrollController _scrollController;
  late Widget _child;
  List<Semantics> _tabs = <Semantics>[];

  late TextStyle _selectedTextStyle;
  late TextStyle _unselectedTextStyle;
  late TextDirection _textDirection;

  double _progress = 0;
  Color? _color;
  ColorTween? _spectrum;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TabController(
          vsync: this,
          animationDuration: widget.duration,
          length: widget.tabs.length,
        );
    _controller.addListener(_tabListener);
    _controller.animation!.addListener(_animationListener);

    _progress = _controller.animation!.value;

    _scrollController = ScrollController();

    if (widget.colors != null) {
      _color = widget.colors![_controller.index];
    }

    _buildChild();
  }

  @override
  void didChangeDependencies() {
    _selectedTextStyle = widget.selectedTextStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    _unselectedTextStyle = widget.unselectedTextStyle ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();
    _textDirection = widget.textDirection ?? Directionality.of(context);
    super.didChangeDependencies();
    _buildChild();
    _buildTabs();
  }

  @override
  void didUpdateWidget(covariant TabContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildChild();
    _buildTabs();
  }

  @override
  void dispose() {
    _scrollController.dispose();

    _controller.animation?.removeListener(_animationListener);
    _controller.removeListener(_tabListener);
    _controller.dispose();

    super.dispose();
  }

  double _animationFraction(double current, int previous, int next) {
    if (next - previous == 0) {
      return 1;
    }
    return (current - previous) / (next - previous);
  }

  void _animationListener() {
    _progress = _controller.animation!.value;
    if (widget.colors != null) {
      _color = _spectrum?.lerp(_animationFraction(
          _progress, _controller.previousIndex, _controller.index));
    }
    _updateTabs(_controller.previousIndex, _controller.index);
  }

  void _tabListener() {
    if (widget.colors != null) {
      _spectrum = ColorTween(
        begin: widget.colors?[_controller.previousIndex],
        end: widget.colors?[_controller.index],
      );
    }
    _buildChild();
  }

  TextStyle _calculateTextStyle(int index) {
    final TextStyleTween styleTween = TextStyleTween(
      begin: _unselectedTextStyle,
      end: _selectedTextStyle,
    );

    final double animationFraction = _animationFraction(
        _progress, _controller.previousIndex, _controller.index);

    if (index == _controller.index) {
      return styleTween
          .lerp(animationFraction)
          .copyWith(fontSize: _unselectedTextStyle.fontSize);
    } else if (index == _controller.previousIndex) {
      return styleTween
          .lerp(1 - animationFraction)
          .copyWith(fontSize: _unselectedTextStyle.fontSize);
    } else {
      return _unselectedTextStyle;
    }
  }

  double _calculateTextScale(int index) {
    final double animationFraction = _animationFraction(
        _progress, _controller.previousIndex, _controller.index);
    final double textRatio =
        _selectedTextStyle.fontSize! / _unselectedTextStyle.fontSize!;

    if (index == _controller.index) {
      return lerpDouble(1, textRatio, animationFraction)!;
    } else if (index == _controller.previousIndex) {
      return lerpDouble(textRatio, 1, animationFraction)!;
    } else {
      return 1;
    }
  }

  Semantics _getTab(int index) {
    final Widget tab = widget.tabs[index];
    final bool selected = index == _controller.index;

    final SemanticsProperties properties = SemanticsProperties(
      label: 'Tab ${index + 1} out of ${widget.tabs.length}',
      hint: 'Select tab ${index + 1}',
      value: tab is Text
          ? tab.semanticsLabel
          : tab is Icon
              ? tab.semanticLabel
              : null,
      selected: selected,
      enabled: widget.enabled,
      button: true,
      inMutuallyExclusiveGroup: true,
      onTap: widget.enabled
          ? () => _controller.animateTo(index, curve: widget.curve)
          : null,
    );

    Widget child = tab;

    if (tab is Text && !widget.overrideTextProperties) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(_calculateTextScale(index)),
        child: Container(
          child: DefaultTextStyle.merge(
            child: tab,
            textAlign: TextAlign.center,
            overflow: TextOverflow.fade,
            style: _calculateTextStyle(index),
          ),
        ),
      );
    }

    return Semantics.fromProperties(
      properties: properties,
      child: child,
    );
  }

  void _updateTabs(int previous, int next) {
    setState(() {
      _tabs[previous] = _getTab(previous);
      _tabs[next] = _getTab(next);
    });
  }

  void _buildTabs() {
    List<Semantics> tabs = <Semantics>[];

    for (int index = 0; index < widget.tabs.length; index++) {
      tabs.add(_getTab(index));
    }

    setState(() {
      _tabs = tabs;
    });
  }

  void _buildChild() {
    Widget child = widget.child ??
        Padding(
          padding: widget.childPadding,
          child: AnimatedSwitcher(
            duration: widget.childDuration ?? widget.duration,
            switchInCurve: widget.childCurve ?? widget.curve,
            transitionBuilder: widget.transitionBuilder ??
                AnimatedSwitcher.defaultTransitionBuilder,
            child: IndexedStack(
              key: ValueKey<int>(_controller.index),
              index: _controller.index,
              children: widget.children!,
            ),
          ),
        );

    setState(() {
      _child = child;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TabFrame(
      controller: _controller,
      scrollController: _scrollController,
      progress: _progress,
      curve: widget.curve,
      tabs: _tabs,
      borderRadius: widget.borderRadius,
      tabBorderRadius: widget.tabBorderRadius,
      tabExtent: widget.tabExtent,
      tabEdge: widget.tabEdge,
      tabAxis:
          (widget.tabEdge == TabEdge.left || widget.tabEdge == TabEdge.right)
              ? Axis.vertical
              : Axis.horizontal,
      tabsStart: widget.tabsStart,
      tabsEnd: widget.tabsEnd,
      tabMinLength: widget.tabMinLength,
      tabMaxLength: widget.tabMaxLength,
      color: _color ?? widget.color ?? Colors.transparent,
      enabled: widget.enabled,
      enableFeedback: widget.enableFeedback,
      textDirection: _textDirection,
      child: _child,
    );
  }
}

class TabFrame extends MultiChildRenderObjectWidget {
  final TabController controller;
  final ScrollController scrollController;
  final double progress;
  final Curve curve;
  final Widget child;
  final List<Semantics> tabs;
  final BorderRadius borderRadius;
  final BorderRadius tabBorderRadius;
  final double tabExtent;
  final TabEdge tabEdge;
  final Axis tabAxis;
  final double tabsStart;
  final double tabsEnd;
  final double tabMinLength;
  final double tabMaxLength;
  final Color color;
  final bool enabled;
  final bool enableFeedback;
  final TextDirection textDirection;

  TabFrame({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.progress,
    required this.curve,
    required this.child,
    required this.tabs,
    required this.borderRadius,
    required this.tabBorderRadius,
    required this.tabExtent,
    required this.tabEdge,
    required this.tabAxis,
    required this.tabsStart,
    required this.tabsEnd,
    required this.tabMinLength,
    required this.tabMaxLength,
    required this.color,
    required this.enabled,
    required this.enableFeedback,
    required this.textDirection,
  }) : super(children: [child, ...tabs]);

  @override
  RenderTabFrame createRenderObject(BuildContext context) {
    return RenderTabFrame(
      context: context,
      controller: controller,
      scrollController: scrollController,
      progress: progress,
      curve: curve,
      tabs: tabs,
      borderRadius: borderRadius,
      tabBorderRadius: tabBorderRadius,
      tabExtent: tabExtent,
      tabEdge: tabEdge,
      tabAxis: tabAxis,
      tabsStart: tabsStart,
      tabsEnd: tabsEnd,
      tabMinLength: tabMinLength,
      tabMaxLength: tabMaxLength,
      color: color,
      enabled: enabled,
      enableFeedback: enableFeedback,
      textDirection: textDirection,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderTabFrame renderObject) {
    renderObject
      ..context = context
      ..controller = controller
      ..scrollController = scrollController
      ..progress = progress
      ..curve = curve
      ..tabs = tabs
      ..borderRadius = borderRadius
      ..tabBorderRadius = tabBorderRadius
      ..tabExtent = tabExtent
      ..tabEdge = tabEdge
      ..tabAxis = tabAxis
      ..tabsStart = tabsStart
      ..tabsEnd = tabsEnd
      ..tabMinLength = tabMinLength
      ..tabMaxLength = tabMaxLength
      ..color = color
      ..enabled = enabled
      ..enableFeedback = enableFeedback
      ..textDirection = textDirection;
  }
}

class TabFrameParentData extends ContainerBoxParentData<RenderBox> {}

class RenderTabFrame extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TabFrameParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TabFrameParentData> {
  RenderTabFrame({
    required BuildContext context,
    required TabController controller,
    required ScrollController scrollController,
    required double progress,
    required Curve curve,
    required List<Semantics> tabs,
    required BorderRadius borderRadius,
    required BorderRadius tabBorderRadius,
    required double tabExtent,
    required TabEdge tabEdge,
    required Axis tabAxis,
    required double tabsStart,
    required double tabsEnd,
    required double tabMinLength,
    required double tabMaxLength,
    required Color color,
    required bool enabled,
    required bool enableFeedback,
    required TextDirection textDirection,
  })  : _context = context,
        _controller = controller,
        _scrollController = scrollController,
        _progress = progress,
        _curve = curve,
        _borderRadius = borderRadius,
        _tabBorderRadius = tabBorderRadius,
        _tabs = tabs,
        _tabExtent = tabExtent,
        _tabEdge = tabEdge,
        _tabAxis = tabAxis,
        _tabsStart = tabsStart,
        _tabsEnd = tabsEnd,
        _tabMinLength = tabMinLength,
        _tabMaxLength = tabMaxLength,
        _color = color,
        _enabled = enabled,
        _enableFeedback = enableFeedback,
        _textDirection = textDirection,
        super();

  BuildContext get context => _context;
  BuildContext _context;
  set context(BuildContext value) {
    if (value == _context) return;
    _context = value;
    markNeedsLayout();
  }

  TabController get controller => _controller;
  TabController _controller;
  set controller(TabController value) {
    if (value == _controller) return;
    _controller = value;
    markNeedsLayout();
  }

  ScrollController get scrollController => _scrollController;
  ScrollController _scrollController;
  set scrollController(ScrollController value) {
    if (value == _scrollController) {
      return;
    }
    _scrollController = value;
    markNeedsLayout();
  }

  double get scrollOffset => _scrollOffset;
  double _scrollOffset = 0;
  set scrollOffset(double value) {
    if (value == _scrollOffset || !_hasTabOverflow) {
      return;
    }
    _scrollOffset = value.clamp(0, _tabOverflow);
    markNeedsLayout();
  }

  double get progress => _progress;
  double _progress;
  set progress(double value) {
    if (value == _progress) return;
    assert(value >= 0 && value <= _tabs.length);
    _progress = value;
    if (value == value.floor() || value == value.ceil()) {
      markNeedsSemanticsUpdate();
    }
    markNeedsLayout();
  }

  Curve get curve => _curve;
  Curve _curve;
  set curve(Curve value) {
    if (value == _curve) {
      return;
    }
    _curve = value;
  }

  List<Semantics> get tabs => _tabs;
  List<Semantics> _tabs;
  set tabs(List<Semantics> value) {
    if (value == _tabs) return;
    assert(value.isNotEmpty);
    _tabs = value;
    markNeedsLayout();
  }

  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  BorderRadius get tabBorderRadius => _tabBorderRadius;
  BorderRadius _tabBorderRadius;
  set tabBorderRadius(BorderRadius value) {
    if (value == _tabBorderRadius) return;
    _tabBorderRadius = value;
    markNeedsPaint();
  }

  double get tabExtent => _tabExtent;
  double _tabExtent;
  set tabExtent(double value) {
    if (value == _tabExtent) return;
    assert(value >= 0);
    _tabExtent = value;
    markNeedsLayout();
  }

  TabEdge get tabEdge => _tabEdge;
  TabEdge _tabEdge;
  set tabEdge(TabEdge value) {
    if (value == _tabEdge) return;
    _tabEdge = value;
    markNeedsLayout();
  }

  Axis get tabAxis => _tabAxis;
  Axis _tabAxis;
  set tabAxis(Axis value) {
    if (value == _tabAxis) {
      return;
    }
    _tabAxis = value;
    markNeedsLayout();
  }

  double get tabsStart => _tabsStart;
  double _tabsStart;
  set tabsStart(double value) {
    if (value == _tabsStart) return;
    _tabsStart = value;
    markNeedsLayout();
  }

  double get tabsEnd => _tabsEnd;
  double _tabsEnd;
  set tabsEnd(double value) {
    if (value == _tabsEnd) return;
    _tabsEnd = value;
    markNeedsLayout();
  }

  double get tabMinLength => _tabMinLength;
  double _tabMinLength;
  set tabMinLength(double value) {
    if (value == _tabMinLength) return;
    _tabMinLength = value;
    markNeedsLayout();
  }

  double get tabMaxLength => _tabMaxLength;
  double _tabMaxLength;
  set tabMaxLength(double value) {
    if (value == _tabMaxLength) return;
    _tabMaxLength = value;
    markNeedsLayout();
  }

  Color get color => _color;
  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    _tapGestureRecognizer.onTapDown = _enabled ? _onTapDown : null;
    _dragGestureRecognizer?.onUpdate = _enabled ? _onDragUpdate : null;
    markNeedsSemanticsUpdate();
  }

  bool get enableFeedback => _enableFeedback;
  bool _enableFeedback;
  set enableFeedback(bool value) {
    if (value == _enableFeedback) return;
    _enableFeedback = value;
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! TabFrameParentData) {
      child.parentData = TabFrameParentData();
    }
  }

  @override
  void attach(covariant PipelineOwner owner) {
    super.attach(owner);

    _tapGestureRecognizer = TapGestureRecognizer(debugOwner: this)
      ..onTapDown = enabled ? _onTapDown : null;

    if (tabAxis == Axis.vertical) {
      _dragGestureRecognizer = VerticalDragGestureRecognizer(debugOwner: this)
        ..onUpdate = enabled ? _onDragUpdate : null;
    } else {
      _dragGestureRecognizer = HorizontalDragGestureRecognizer(debugOwner: this)
        ..onUpdate = enabled ? _onDragUpdate : null;
    }
  }

  @override
  void detach() {
    super.detach();

    _tapGestureRecognizer.dispose();
    _dragGestureRecognizer?.dispose();
  }

  @override
  void dispose() {
    _clipPathLayer.layer = null;
    _tapGestureRecognizer.dispose();
    _dragGestureRecognizer?.dispose();
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) {
    return size.contains(position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool isHit = false;

    for (var child = firstChild; child != null; child = childAfter(child)) {
      final TabFrameParentData childParentData =
          child.parentData as TabFrameParentData;
      isHit = result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset? transformed) {
          assert(transformed == position - childParentData.offset);
          return child!.hitTest(result, position: transformed!);
        },
      );
    }

    return isHit;
  }

  late TapGestureRecognizer _tapGestureRecognizer;
  DragGestureRecognizer? _dragGestureRecognizer;

  @override
  void handleEvent(PointerEvent event, covariant HitTestEntry entry) {
    assert(debugHandleEvent(event, entry));

    if (event is PointerScrollEvent) {
      if (_hasTabOverflow) {
        _onPointerScroll(event);
      }
    } else if (event is PointerDownEvent) {
      _tapGestureRecognizer.addPointer(event);
      if (_hasTabOverflow) {
        _dragGestureRecognizer?.addPointer(event);
      }
    }
  }

  double _alignScrollDelta(PointerScrollEvent event) {
    final Set<LogicalKeyboardKey> pressed =
        HardwareKeyboard.instance.logicalKeysPressed;
    final bool flipAxes = pressed.any(
            ScrollConfiguration.of(context).pointerAxisModifiers.contains) &&
        event.kind == PointerDeviceKind.mouse;

    return flipAxes ? event.scrollDelta.dx : event.scrollDelta.dy;
  }

  void _handlePointerScroll(PointerSignalEvent event) {
    assert(event is PointerScrollEvent);
    final double delta = _alignScrollDelta(event as PointerScrollEvent);
    scrollOffset += delta;
  }

  void _onPointerScroll(PointerScrollEvent event) {
    final double dx = event.localPosition.dx;
    final double dy = event.localPosition.dy;

    final (tabViewport, tabMetrics) = _getTabViewportAndMetrics();

    if (tabViewport.contains(dx, dy, tabMetrics.totalLength)) {
      final double delta = _alignScrollDelta(event);
      if (delta != 0.0) {
        GestureBinding.instance.pointerSignalResolver
            .register(event, _handlePointerScroll);
      }
    }
  }

  void _onTapDown(TapDownDetails details) {
    final double dx = details.localPosition.dx;
    final double dy = details.localPosition.dy;

    final (tabViewport, tabMetrics) = _getTabViewportAndMetrics();

    if (tabViewport.contains(dx, dy, tabMetrics.totalLength)) {
      double pos = dx;

      if (tabAxis == Axis.vertical) {
        pos = dy;
      }

      controller.animateTo(
        (pos - tabViewport.start + scrollOffset) ~/ tabMetrics.length,
        curve: curve,
      );
      if (enableFeedback) {
        Feedback.forTap(context);
      }
    }

    return;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final double dx = details.localPosition.dx;
    final double dy = details.localPosition.dy;

    final (tabViewport, tabMetrics) = _getTabViewportAndMetrics();

    if (tabViewport.contains(dx, dy, tabMetrics.totalLength)) {
      scrollOffset -= details.primaryDelta!;
    }
  }

  @override
  bool get alwaysNeedsCompositing => _hasTabOverflow;

  bool _hasTabOverflow = false;
  double _tabOverflow = 0;

  (_TabViewport, _TabMetrics) _getTabViewportAndMetrics() {
    final _TabViewport tabViewport = _TabViewport(
      parentSize: size,
      tabEdge: tabEdge,
      tabExtent: tabExtent,
      tabsStart: tabsStart,
      tabsEnd: tabsEnd,
    );

    final _TabMetrics tabMetrics = _TabMetrics(
      count: tabs.length,
      range: tabViewport.range,
      minLength: tabMinLength,
      maxLength: tabMaxLength,
    );

    return (tabViewport, tabMetrics);
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    //Layout the main child
    RenderBox? child = firstChild;

    if (child == null) {
      return;
    }

    BoxConstraints mainChildConstraints = BoxConstraints(
      maxWidth: size.width,
      maxHeight: size.height - tabExtent,
    );
    if (tabAxis == Axis.vertical) {
      mainChildConstraints = BoxConstraints(
        maxWidth: size.width - tabExtent,
        maxHeight: size.height,
      );
    }

    child.layout(mainChildConstraints, parentUsesSize: true);

    final TabFrameParentData childParentData =
        child.parentData as TabFrameParentData;

    final EdgeInsets mainChildInsets = EdgeInsets.symmetric(
      vertical: (mainChildConstraints.maxHeight - child.size.height) / 4,
      horizontal: (mainChildConstraints.maxWidth - child.size.width) / 4,
    );

    childParentData.offset = Offset(
      mainChildInsets.horizontal,
      mainChildInsets.vertical,
    );

    if (tabEdge == TabEdge.left) {
      childParentData.offset += Offset(tabExtent, 0);
    } else if (tabEdge == TabEdge.top) {
      childParentData.offset += Offset(0, tabExtent);
    }

    //Layout the tabs
    child = childAfter(child);

    final (tabViewport, tabMetrics) = _getTabViewportAndMetrics();

    _tabOverflow = tabMetrics.totalLength - tabViewport.range;

    if (_hasTabOverflow != _tabOverflow > 0) {
      markNeedsCompositingBitsUpdate();
    }
    _hasTabOverflow = _tabOverflow > 0;

    if (_hasTabOverflow) {
      final double viewportWidth = tabViewport.size.width;
      final double viewportHeight = tabViewport.size.height;
      final double brx = tabBorderRadius.bottomRight.x;
      final double cutoff = max(0, tabViewport.start - brx);

      if (tabAxis == Axis.vertical) {
        _clipPath = Path.combine(
          PathOperation.xor,
          Path()
            ..addRect(
              Rect.fromPoints(
                Offset(0, cutoff),
                Offset(
                  viewportWidth,
                  min(size.height, cutoff + viewportHeight + brx),
                ),
              ),
            ),
          Path()
            ..addRect(
              Rect.fromPoints(
                Offset(tabExtent, 0),
                Offset(size.width, size.height),
              ),
            ),
        );
        if (tabEdge == TabEdge.right) {
          _clipPath = _clipPath.transform((Matrix4.identity()
                ..scale(-1.0, 1.0)
                ..translate(-size.width, 0.0))
              .storage);
        }
      } else {
        _clipPath = Path.combine(
            PathOperation.xor,
            Path()
              ..addRect(
                Rect.fromPoints(
                  Offset(cutoff, size.height - tabExtent),
                  Offset(
                    min(size.width, cutoff + viewportWidth + brx),
                    size.height,
                  ),
                ),
              ),
            Path()
              ..addRect(Rect.fromPoints(
                  Offset.zero, Offset(size.width, size.height - tabExtent))));
        if (tabEdge == TabEdge.top) {
          _clipPath = _clipPath.transform((Matrix4.identity()
                ..scale(1.0, -1.0)
                ..translate(0.0, -size.height))
              .storage);
        }
      }
    }

    BoxConstraints tabConstraints = BoxConstraints(
      maxWidth: tabMetrics.length,
      maxHeight: tabExtent,
    );

    if (tabAxis == Axis.vertical) {
      tabConstraints = BoxConstraints(
        maxWidth: tabConstraints.maxHeight,
        maxHeight: tabConstraints.maxWidth,
      );
    }

    for (var index = 0; child != null; index++, child = childAfter(child)) {
      child.layout(tabConstraints, parentUsesSize: true);

      final TabFrameParentData tabParentData =
          child.parentData as TabFrameParentData;

      final double displacement = tabMetrics.length * index - scrollOffset;

      final EdgeInsets tabInsets = EdgeInsets.symmetric(
        vertical: (tabConstraints.maxHeight - child.size.height) / 4,
        horizontal: (tabConstraints.maxWidth - child.size.width) / 4,
      );

      switch (tabEdge) {
        case TabEdge.left:
          tabParentData.offset = Offset(
            tabInsets.horizontal,
            tabInsets.vertical + displacement + tabViewport.start,
          );
          break;
        case TabEdge.top:
          tabParentData.offset = Offset(
            tabInsets.horizontal + displacement + tabViewport.start,
            tabInsets.vertical,
          );
          break;
        case TabEdge.right:
          tabParentData.offset = Offset(
            size.width - tabInsets.horizontal - child.size.width,
            tabInsets.vertical + displacement + tabViewport.start,
          );
          break;
        case TabEdge.bottom:
          tabParentData.offset = Offset(
            tabInsets.horizontal + displacement + tabViewport.start,
            size.height - tabInsets.vertical - child.size.height,
          );
          break;
      }
    }
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => false;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  double computeMinIntrinsicWidth(double height) {
    final double childMinIntrinsicWidth =
        firstChild?.getMinIntrinsicWidth(height) ?? 0.0;
    if (tabAxis == Axis.vertical) {
      return childMinIntrinsicWidth + tabExtent;
    }
    return childMinIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double childMaxIntrinsicWidth =
        firstChild?.getMaxIntrinsicWidth(height) ?? 0.0;
    if (tabAxis == Axis.vertical) {
      return childMaxIntrinsicWidth + tabExtent;
    }
    return childMaxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double childMinIntrinsicHeight =
        firstChild?.getMinIntrinsicHeight(width) ?? 0.0;
    if (tabAxis == Axis.vertical) {
      return childMinIntrinsicHeight;
    }
    return childMinIntrinsicHeight + tabExtent;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double childMaxIntrinsicHeight =
        firstChild?.getMaxIntrinsicHeight(width) ?? 0.0;
    if (tabAxis == Axis.vertical) {
      return childMaxIntrinsicHeight;
    }
    return childMaxIntrinsicHeight + tabExtent;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  Path _clipPath = Path();

  final LayerHandle<ClipPathLayer> _clipPathLayer =
      LayerHandle<ClipPathLayer>();

  Path _getPath() {
    final double width = size.width;
    final double height = size.height;

    final (tabViewport, tabMetrics) = _getTabViewportAndMetrics();

    final double leftPos =
        progress * tabMetrics.length + tabViewport.start - scrollOffset;
    final double rightPos = leftPos + tabMetrics.length;

    if (tabAxis == Axis.vertical) {
      double? critical1;
      double? critical2;
      double? critical3;
      double? critical4;
      double tbrx = tabBorderRadius.bottomRight.x;
      double tblx = tabBorderRadius.bottomLeft.x;
      double tly = borderRadius.topLeft.y;
      double bly = borderRadius.bottomLeft.y;
      if (leftPos < tbrx + tly) {
        critical1 = tbrx / (tbrx + tly) * leftPos;
        critical2 = tly / (tbrx + tly) * leftPos;
      }
      if (height - rightPos < tblx + bly) {
        critical3 = bly / (tblx + bly) * (height - rightPos);
        critical4 = tblx / (tblx + bly) * (height - rightPos);
      }
      Path path = Path()
        ..moveTo(width - borderRadius.topRight.x, 0)
        ..quadraticBezierTo(width, 0, width, borderRadius.topRight.y)
        ..lineTo(width, height - borderRadius.bottomRight.y)
        ..quadraticBezierTo(
            width, height, width - borderRadius.bottomRight.x, height)
        ..lineTo(tabExtent + borderRadius.bottomLeft.x, height)
        ..quadraticBezierTo(tabExtent, height, tabExtent,
            max(height - (critical3 ?? bly), rightPos))
        ..lineTo(tabExtent, min(height, rightPos + (critical4 ?? tblx)))
        ..quadraticBezierTo(tabExtent, rightPos,
            tabExtent - tabBorderRadius.bottomLeft.y, rightPos)
        ..lineTo(tabBorderRadius.topLeft.y, rightPos)
        ..quadraticBezierTo(
            0, rightPos, 0, rightPos - tabBorderRadius.topLeft.x)
        ..lineTo(0, leftPos + tabBorderRadius.topRight.x)
        ..quadraticBezierTo(0, leftPos, tabBorderRadius.topRight.y, leftPos)
        ..lineTo(tabExtent - tabBorderRadius.bottomRight.y, leftPos)
        ..quadraticBezierTo(tabExtent, leftPos, tabExtent,
            max(0, leftPos - (critical1 ?? tbrx)))
        ..lineTo(tabExtent, min(critical2 ?? tly, leftPos))
        ..quadraticBezierTo(tabExtent, 0, tabExtent + borderRadius.topLeft.x, 0)
        ..close();
      if (tabEdge == TabEdge.right) {
        return path.transform((Matrix4.identity()
              ..scale(1.0, -1.0)
              ..translate(0.0, -height))
            .storage);
      }
      return path;
    } else {
      double? critical1;
      double? critical2;
      double? critical3;
      double? critical4;
      double brx = borderRadius.bottomRight.x;
      double tblx = tabBorderRadius.bottomLeft.x;
      double tbrx = tabBorderRadius.topLeft.y;
      double blx = borderRadius.bottomLeft.x;
      if (width - rightPos < brx + tblx) {
        critical1 = brx / (brx + tblx) * (width - rightPos);
        critical2 = tblx / (brx + tblx) * (width - rightPos);
      }
      if (leftPos < tbrx + blx) {
        critical3 = tbrx / (tbrx + blx) * (leftPos);
        critical4 = blx / (tbrx + blx) * (leftPos);
      }
      Path path = Path()
        ..moveTo(0, borderRadius.topLeft.y)
        ..quadraticBezierTo(0, 0, borderRadius.topLeft.x, 0)
        ..lineTo(width - borderRadius.topRight.x, 0)
        ..quadraticBezierTo(width, 0, width, borderRadius.topRight.y)
        ..lineTo(width, height - tabExtent - borderRadius.bottomRight.y)
        ..quadraticBezierTo(width, height - tabExtent,
            max(width - (critical1 ?? brx), rightPos), height - tabExtent)
        ..lineTo(min(width, rightPos + (critical2 ?? tblx)), height - tabExtent)
        ..quadraticBezierTo(rightPos, height - tabExtent, rightPos,
            height - tabExtent + tabBorderRadius.bottomLeft.y)
        ..lineTo(rightPos, height - tabBorderRadius.topLeft.y)
        ..quadraticBezierTo(
            rightPos, height, rightPos - tabBorderRadius.topLeft.x, height)
        ..lineTo(leftPos + tabBorderRadius.topRight.x, height)
        ..quadraticBezierTo(
            leftPos, height, leftPos, height - tabBorderRadius.topRight.y)
        ..lineTo(leftPos, height - tabExtent + tabBorderRadius.bottomRight.y)
        ..quadraticBezierTo(leftPos, height - tabExtent,
            max(0, leftPos - (critical3 ?? tbrx)), height - tabExtent)
        ..lineTo(min(critical4 ?? blx, leftPos), height - tabExtent)
        ..quadraticBezierTo(0, height - tabExtent, 0,
            height - tabExtent - borderRadius.bottomLeft.y)
        ..close();
      if (tabEdge == TabEdge.top) {
        return path.transform((Matrix4.identity()
              ..scale(1.0, -1.0)
              ..translate(0.0, -height))
            .storage);
      }
      return path;
    }
  }

  void _paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()..color = color;

    canvas.drawPath(_getPath(), paint);

    for (var child = firstChild; child != null; child = childAfter(child)) {
      context.paintChild(
        child,
        (child.parentData as TabFrameParentData).offset,
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hasTabOverflow) {
      _clipPathLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        Offset.zero & size,
        _clipPath,
        _paint,
        oldLayer: _clipPathLayer.layer,
      );
    } else {
      _clipPathLayer.layer = null;
      _paint(context, offset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(covariant RenderObject child) {
    return Rect.fromPoints(Offset.zero, Offset(size.width, size.height));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    config
      ..textDirection = textDirection
      ..isEnabled = enabled;
  }
}
