import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/app_image_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_dimensions.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final bool centerTitle;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.centerTitle = true,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
      ),
      backgroundColor: backgroundColor ?? AppColors.backgroundLight,
      elevation: elevation,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? borderWidth;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final double? width;
  final double? height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderWidth,
    this.padding,
    this.borderRadius,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppColors.primaryGreen;
    final effectiveTextColor = textColor ?? AppColors.textWhite;

    return SizedBox(
      width: width,
      height: height ?? AppDimensions.buttonHeightLarge,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined
              ? Colors.transparent
              : effectiveBackgroundColor,
          foregroundColor: effectiveTextColor,
          elevation: isOutlined ? 0 : 4,
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              borderRadius ?? AppDimensions.buttonRadius,
            ),
            side: isOutlined
                ? BorderSide(
                    color: borderColor ?? effectiveBackgroundColor,
                    width: borderWidth ?? 1,
                  )
                : BorderSide.none,
          ),
          shadowColor: AppColors.primaryGreen.withValues(alpha: 0.25),
        ),
        child: isLoading
            ? SizedBox(
                width: AppDimensions.iconMd,
                height: AppDimensions.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppDimensions.spacing8),
                  ],
                  Text(
                    text,
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: isOutlined
                          ? (textColor ??
                                (borderColor ?? effectiveBackgroundColor))
                          : effectiveTextColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final Border? border;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.paddingMd),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDimensions.cardRadius,
        ),
        boxShadow: boxShadow ?? [AppColors.cardShadow],
        border: border,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: cardWidget);
    }

    return cardWidget;
  }
}

class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;
  final TextAlign textAlign;
  final Color? fillColor;
  final Color? disabledFillColor;
  final Color? borderColor;
  final Color? focusedBorderColor;
  final double? borderRadius;
  final TextStyle? labelStyle;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final Color? iconColor;
  final double? iconSize;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  const CustomTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.contentPadding,
    this.textAlign = TextAlign.start,
    this.fillColor,
    this.disabledFillColor,
    this.borderColor,
    this.focusedBorderColor,
    this.borderRadius,
    this.labelStyle,
    this.readOnly = false,
    this.onTap,
    this.textInputAction,
    this.iconColor,
    this.iconSize,
    this.inputFormatters,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = BorderRadius.circular(
      borderRadius ?? AppDimensions.inputRadius,
    );
    final effectiveBorderColor = borderColor ?? AppColors.outline;
    final effectiveFocusBorderColor =
        focusedBorderColor ?? AppColors.primaryGreen;
    final effectiveFillColor = fillColor ?? AppColors.surface;
    final effectiveDisabledFillColor =
        disabledFillColor ?? AppColors.backgroundDark;
    final effectiveLabelStyle =
        labelStyle ??
        AppTextStyles.bodyMedium.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w500,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: effectiveLabelStyle),
          const SizedBox(height: AppDimensions.spacing8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          minLines: minLines,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          textAlign: textAlign,
          readOnly: readOnly,
          onTap: onTap,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint,
            errorText: errorText,
            prefixIcon: prefixIcon == null
                ? null
                : IconTheme.merge(
                    data: IconThemeData(
                      color: iconColor ?? AppColors.outline,
                      size: iconSize ?? AppDimensions.iconMd,
                    ),
                    child: prefixIcon!,
                  ),
            suffixIcon: suffixIcon == null
                ? null
                : IconTheme.merge(
                    data: IconThemeData(
                      color: iconColor ?? AppColors.outline,
                      size: iconSize ?? AppDimensions.iconMd,
                    ),
                    child: suffixIcon!,
                  ),
            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingLg,
                  vertical: AppDimensions.paddingMd,
                ),
            filled: true,
            fillColor: enabled
                ? effectiveFillColor
                : effectiveDisabledFillColor,
            border: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(color: effectiveBorderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(color: effectiveBorderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: BorderSide(
                color: effectiveFocusBorderColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: effectiveBorderRadius,
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoadingWidget extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingWidget({super.key, this.message, this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: color ?? AppColors.primaryGreen),
          if (message != null) ...[
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              message!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? icon;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.padding2xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(height: AppDimensions.spacing24),
            ],
            Text(title, style: AppTextStyles.h5, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimensions.spacing24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingSm,
            vertical: AppDimensions.spacing4,
          ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.badgeText.copyWith(color: textColor),
      ),
    );
  }
}

class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initial;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    this.initial,
    this.size = AppDimensions.avatarMd,
    this.backgroundColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Validate URL format
    final bool hasValidUrl =
        imageUrl != null &&
        imageUrl!.isNotEmpty &&
        (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor ?? AppColors.primaryGreen,
      backgroundImage: hasValidUrl ? AppImageProvider(imageUrl!) : null,
      child: !hasValidUrl
          ? Text(
              initial ?? '?',
              style: AppTextStyles.h6.copyWith(
                color: textColor ?? AppColors.textWhite,
                fontSize: size * 0.4,
              ),
            )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }
}
