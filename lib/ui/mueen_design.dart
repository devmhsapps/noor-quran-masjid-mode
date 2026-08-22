import 'package:flutter/material.dart';

abstract final class MueenColors {
  static const forest = Color(0xFF064B38);
  static const forestDeep = Color(0xFF073C2E);
  static const gold = Color(0xFFC99327);
  static const ivory = Color(0xFFFBF8F0);
  static const paper = Color(0xFFFFFCF5);
  static const mint = Color(0xFFE7F3E9);
  static const ink = Color(0xFF142D23);
  static const muted = Color(0xFF718076);
  static const line = Color(0xFFE5E4DB);
}

class MueenPalette {
  const MueenPalette._({required this.isDark});
  final bool isDark;

  static MueenPalette of(BuildContext context) => MueenPalette._(isDark: Theme.of(context).brightness == Brightness.dark);

  Color get background => isDark ? const Color(0xFF0B1713) : MueenColors.ivory;
  Color get surface => isDark ? const Color(0xFF12261D) : MueenColors.paper;
  Color get surfaceSoft => isDark ? const Color(0xFF193126) : const Color(0xFFF9F2E2);
  Color get ink => isDark ? const Color(0xFFF2F5EF) : MueenColors.ink;
  Color get muted => isDark ? const Color(0xFFB1C2B7) : MueenColors.muted;
  Color get line => isDark ? const Color(0xFF294438) : MueenColors.line;
  Color get iconBackground => isDark ? const Color(0xFF1C3B2C) : MueenColors.mint;
  Color get actionBackground => isDark ? const Color(0xFF1C3B2C) : MueenColors.forest;
  Color get actionForeground => isDark ? const Color(0xFFBDE9CC) : Colors.white;
  Color get shadow => isDark ? Colors.black.withValues(alpha: .26) : const Color(0x0F083C2E);
}

class MueenPageHeader extends StatelessWidget {
  const MueenPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onMenu,
    required this.onTheme,
    required this.darkMode,
  });

  final String title;
  final String subtitle;
  final VoidCallback onMenu;
  final VoidCallback onTheme;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          _CircleAction(icon: Icons.menu_rounded, onTap: onMenu),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: palette.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: TextStyle(fontSize: 10, color: palette.muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          _CircleAction(icon: darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, onTap: onTheme, gold: true),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.gold = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Material(
      color: gold ? MueenColors.gold.withValues(alpha: .14) : palette.actionBackground,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: gold ? MueenColors.gold : palette.actionForeground, size: 21),
        ),
      ),
    );
  }
}

class MueenSurface extends StatelessWidget {
  const MueenSurface({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.radius = 23, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.line),
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 17, offset: const Offset(0, 7))],
      ),
      child: child,
    );
    if (onTap == null) return body;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: body));
  }
}

class MueenIconBubble extends StatelessWidget {
  const MueenIconBubble({super.key, required this.icon, this.color = MueenColors.forest, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    final effectiveColor = color == MueenColors.forest && palette.isDark ? const Color(0xFFBDE9CC) : color;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.isDark ? palette.iconBackground : effectiveColor.withValues(alpha: .11)),
      child: Icon(icon, color: effectiveColor, size: size * .52),
    );
  }
}

class MueenSectionLabel extends StatelessWidget {
  const MueenSectionLabel({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = MueenPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 20, 3, 9),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: palette.ink)),
        const Spacer(),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: MueenColors.gold, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class MueenToggle extends StatelessWidget {
  const MueenToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: MueenColors.forest,
        activeThumbColor: Colors.white,
      );
}
