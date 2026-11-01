import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'screens/legal_screen.dart';

import 'theme.dart';

/// Round orange call-to-action with an arrow, the app's signature button.
class ArrowButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double size;
  final String tooltip;
  const ArrowButton({super.key, this.onPressed, this.size = 64, this.tooltip = 'Continue'});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? VeilColors.orange : VeilColors.line,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: VeilColors.orange.withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: size * 0.42),
          ),
        ),
      ),
    );
  }
}

/// Outlined rounded-square back button.
class BackSquare extends StatelessWidget {
  const BackSquare({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: VeilColors.orange, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.maybePop(context),
            child: const SizedBox.square(
              dimension: 40,
              child: Icon(Icons.chevron_left_rounded, color: VeilColors.ink, size: 26),
            ),
          ),
        ),
      );
}

/// Small orange icon + label pair, used for at-a-glance facts.
class Fact extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  const Fact(this.icon, this.label, {super.key, this.accent = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: VeilColors.orange),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
                  color: accent ? VeilColors.orange : VeilColors.ink,
                )),
          ),
        ],
      );
}

/// Soft illustrated badge: layered peach circles behind a large icon.
class Illustration extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color tint;
  const Illustration(this.icon, {super.key, this.size = 220, this.tint = VeilColors.orange});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle, color: VeilColors.peach),
            ),
            Positioned(
              right: size * 0.04,
              top: size * 0.08,
              child: _dot(size * 0.16, VeilColors.sky.withValues(alpha: 0.18)),
            ),
            Positioned(
              left: size * 0.06,
              bottom: size * 0.12,
              child: _dot(size * 0.12, VeilColors.orange.withValues(alpha: 0.22)),
            ),
            Container(
              width: size * 0.66,
              height: size * 0.66,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: VeilColors.orangeSoft),
            ),
            Icon(icon, size: size * 0.38, color: tint),
          ],
        ),
      );

  static Widget _dot(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );
}

/// Section heading with an optional trailing action, e.g. "See all".
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          ?trailing,
        ],
      );
}

/// "By continuing you agree to the Terms of Service and Privacy Policy",
/// with both titles tappable.
class LegalLinks extends StatefulWidget {
  final String lead;
  final TextAlign align;
  const LegalLinks({super.key, this.lead = 'By continuing you agree to the ', this.align = TextAlign.center});

  @override
  State<LegalLinks> createState() => _LegalLinksState();
}

class _LegalLinksState extends State<LegalLinks> {
  late final _terms = TapGestureRecognizer()..onTap = () => LegalDoc.terms.open(context);
  late final _privacy = TapGestureRecognizer()..onTap = () => LegalDoc.privacy.open(context);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: VeilColors.orange, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: widget.lead),
          TextSpan(text: 'Terms of Service', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: widget.align,
    );
  }
}
