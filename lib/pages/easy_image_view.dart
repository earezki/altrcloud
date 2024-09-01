import 'package:flutter/cupertino.dart';

class EasyImageView extends StatefulWidget {
  /// The image to display
  final ImageProvider imageProvider;

  /// Minimum scale factor
  final double minScale;

  /// Maximum scale factor
  final double maxScale;

  /// Callback for when the scale has changed, only invoked at the end of
  /// an interaction.
  final void Function(double)? onScaleChanged;

  /// Create a new instance
  const EasyImageView({
    super.key,
    required this.imageProvider,
    this.minScale = 1.0,
    this.maxScale = 5.0,
    this.onScaleChanged,
  });

  @override
  State<EasyImageView> createState() => _EasyImageViewState();
}

class _EasyImageViewState extends State<EasyImageView>
    with SingleTickerProviderStateMixin {
  final _scale = 3.0;

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        _transformationController.value = _zoomAnimation!.value;
      });

    super.initState();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      child: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          child: Image(
            image: widget.imageProvider,
            gaplessPlayback: true,
          ),
          onInteractionEnd: (scaleEndDetails) {
            _setScale(_transformationController.value);
          },
        ),
      ),
    );
  }

  void _setScale(Matrix4 transformation) {
    double scale = transformation.getMaxScaleOnAxis();
    if (widget.onScaleChanged != null) {
      widget.onScaleChanged!(scale);
    }
  }

  void _handleDoubleTap() {
    Matrix4 _endMatrix = _transformationController.value.isIdentity()
        ? _applyZoom()
        : _revertZoom();

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: _endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController.forward(from: 0);

    _setScale(_endMatrix);
  }

  Matrix4 _applyZoom() {
    final tapPosition = _doubleTapDetails!.localPosition;
    final translationCorrection = _scale - 1;
    final zoomed = Matrix4.identity()
      ..translate(
        -tapPosition.dx * translationCorrection,
        -tapPosition.dy * translationCorrection,
      )
      ..scale(_scale);
    return zoomed;
  }

  Matrix4 _revertZoom() => Matrix4.identity();
}
