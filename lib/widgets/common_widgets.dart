import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════
// AppCard — Tüm ekranlarda tekrar eden kart container'ı
// ═══════════════════════════════════════════════════════════════

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = AppConstants.cardRadius,
    this.backgroundColor,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: cs.outlineVariant),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppHeader — Gradient header (tüm ekranların üst kısmı)
// ═══════════════════════════════════════════════════════════════

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? bottomContent;
  final double? height;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.gradientColors = const [AppColors.primary, AppColors.primaryLight],
    this.onBack,
    this.trailing,
    this.bottomContent,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppConstants.headerRadius),
          bottomRight: Radius.circular(AppConstants.headerRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (onBack != null)
                    AppBackButton(onTap: onBack!)
                  else
                    AppBackButton(onTap: () => context.go('/app/dashboard')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              if (bottomContent != null) ...[
                const SizedBox(height: 20),
                bottomContent!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppBackButton — Header'daki yarı saydam geri butonu
// ═══════════════════════════════════════════════════════════════

class AppBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const AppBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppRefreshButton — Header'daki yenile butonu
// ═══════════════════════════════════════════════════════════════

class AppRefreshButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const AppRefreshButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.refresh,
          color: Colors.white.withValues(alpha: isLoading ? 0.4 : 1.0),
          size: 20,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppLoadingState — Yükleniyor göstergesi
// ═══════════════════════════════════════════════════════════════

class AppLoadingState extends StatelessWidget {
  final String message;
  final Color color;

  const AppLoadingState({
    super.key,
    this.message = 'Yükleniyor...',
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          CircularProgressIndicator(color: color),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppEmptyState — Veri yok ekranı
// ═══════════════════════════════════════════════════════════════

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const AppEmptyState({
    super.key,
    required this.icon,
    this.color = AppColors.primary,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppErrorBanner — Hata mesajı kasası
// ═══════════════════════════════════════════════════════════════

class AppErrorBanner extends StatelessWidget {
  final String message;

  const AppErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.destructive,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.destructive,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppIconBadge — İkon + arka plan kutusu
// ═══════════════════════════════════════════════════════════════

class AppIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.iconContainerRadius),
      ),
      child: Icon(icon, color: color, size: size),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppTextField — Modüler ve tutarlı form alanı
// ═══════════════════════════════════════════════════════════════

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.mutedForeground)
                : null,
            suffixIcon: suffixIcon,
            contentPadding: maxLines > 1
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                : null,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppButton — Modüler, loading durumlu butonlar
// ═══════════════════════════════════════════════════════════════

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(color: AppColors.border),
          ),
          child: _buildContent(),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(isElevated: true),
      ),
    );
  }

  Widget _buildContent({bool isElevated = false}) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          color: isElevated ? Colors.white : AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isElevated ? Colors.white : AppColors.foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Text(
      text,
      style: TextStyle(
        color: isElevated ? null : AppColors.foreground,
        fontWeight: isElevated ? null : FontWeight.w500,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AppLogo — AKSA Ortak Logo Parçası
// ═══════════════════════════════════════════════════════════════

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool center;

  const AppLogo({
    super.key,
    this.size = 28,
    this.showText = true,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Row(
      mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: center
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(size * 0.4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.6),
          ),
          child: Icon(
            Icons.monitor_heart_outlined,
            color: Colors.white,
            size: size,
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.45),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AKSA',
                style: TextStyle(
                  fontSize: size * 0.8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.foreground,
                ),
              ),
              Text(
                'Akıllı Kişisel Sağlık Asistanı',
                style: TextStyle(
                  fontSize: size * 0.4,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return content;
  }
}

// ═══════════════════════════════════════════════════════════════
// AppDivider — Veya Şununla vs.
// ═══════════════════════════════════════════════════════════════

class AppDivider extends StatelessWidget {
  final String text;

  const AppDivider({super.key, this.text = 'veya'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
