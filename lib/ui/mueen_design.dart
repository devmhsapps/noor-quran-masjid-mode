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
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: MueenColors.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: MueenColors.muted, fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) => Material(
        color: gold ? MueenColors.gold.withValues(alpha: .14) : MueenColors.forest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: gold ? MueenColors.gold : Colors.white, size: 21),
          ),
        ),
      );
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
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? MueenColors.paper,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: MueenColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0F083C2E), blurRadius: 17, offset: Offset(0, 7))],
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
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .11)),
        child: Icon(icon, color: color, size: size * .52),
      );
}

class MueenSectionLabel extends StatelessWidget {
  const MueenSectionLabel({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(3, 20, 3, 9),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: MueenColors.ink)),
          const Spacer(),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: MueenColors.gold, fontWeight: FontWeight.w900))),
        ]),
      );
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
