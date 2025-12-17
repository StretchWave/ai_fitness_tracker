import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlobalAiOverlay extends StatefulWidget {
  final Widget child;

  const GlobalAiOverlay({super.key, required this.child});

  @override
  State<GlobalAiOverlay> createState() => _GlobalAiOverlayState();
}

class _GlobalAiOverlayState extends State<GlobalAiOverlay> {
  static const MethodChannel _appControl = MethodChannel(
    'com.workout/app_control',
  );
  bool _isAiReady = false;
  bool _showIndicator = true;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    try {
      // Trigger preload or check status
      final bool result =
          await _appControl.invokeMethod('preloadModel') ?? false;

      if (mounted) {
        setState(() {
          _isAiReady = result;
        });

        if (result) {
          _scheduleHide();
        }
      }
    } on PlatformException {
      debugPrint("Failed to check model status");
    }
  }

  void _scheduleHide() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showIndicator = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The main app content
        widget.child,

        // Floating AI Readiness Indicator
        Positioned(
          top: 50,
          right: 20,
          child: AnimatedOpacity(
            opacity: _showIndicator ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            // Ignore pointer events when hidden so it doesn't block touches
            child: IgnorePointer(
              ignoring: !_showIndicator,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.5),
                    ),
                  ),
                  child: _isAiReady
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                          size: 24,
                        )
                      : const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.greenAccent,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
