import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// NavixMind "Cyber-Clean" Theme
///
/// Design Philosophy:
/// - Deep Dark (#0F0F12) background
/// - Minimalist and high contrast
/// - Terminal aesthetic with modern mobile UX
class NavixTheme {
  // Core Colors
  static const Color background = Color(0xFF0F0F12);
  static const Color surface = Color(0xFF1A1A1F);
  static const Color surfaceVariant = Color(0xFF252530);

  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryVariant = Color(0xFF388E3C);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textTertiary = Color(0xFF606060);

  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB300);
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);

  // Accent colors for chips/tags
  static const Color accentBlue = Color(0xFF64B5F6);
  static const Color accentPurple = Color(0xFFBA68C8);
  static const Color accentOrange = Color(0xFFFFB74D);
  static const Color accentCyan = Color(0xFF4DD0E1);

  // Unicode glyphs for icons
  static const String iconSpinner = '⣷';
  static const String iconVoiceIdle = '●';
  static const String iconVoiceRecording = '■';
  static const String iconAdd = '⊕';
  static const String iconMenu = '≡';
  static const String iconClose = '×';
  static const String iconSend = '→';
  static const String iconWarning = '⚠';
  static const String iconCheck = '✓';
  static const String iconError = '✗';
  static const String iconFile = '◰';
  static const String iconImage = '◫';
  static const String iconVideo = '▶';
  static const String iconAudio = '♪';
  static const String iconLocation = '◉';
  static const String iconCalendar = '◫';
  static const String iconEmail = '✉';

  // Braille spinner animation frames
  static const List<String> spinnerFrames = [
    '⣷', '⣯', '⣟', '⡿', '⢿', '⣻', '⣽', '⣾',
  ];

  // Voice waveform characters
  static const List<String> waveformChars = ['▂', '▃', '▅', '▇', '█'];

  // Slash commands
  static const Map<String, SlashCommand> slashCommands = {
    '/crop': SlashCommand(
      name: '/crop',
      description: 'Crop a video to focus on faces',
      icon: '✂',
      category: 'media',
    ),
    '/extract': SlashCommand(
      name: '/extract',
      description: 'Extract audio from video',
      icon: '♪',
      category: 'media',
    ),
    '/summarize': SlashCommand(
      name: '/summarize',
      description: 'Summarize a document or webpage',
      icon: '◰',
      category: 'text',
    ),
    '/ocr': SlashCommand(
      name: '/ocr',
      description: 'Extract text from an image',
      icon: '◫',
      category: 'text',
    ),
    '/calendar': SlashCommand(
      name: '/calendar',
      description: 'View or create calendar events',
      icon: '◫',
      category: 'google',
    ),
    '/email': SlashCommand(
      name: '/email',
      description: 'Read or send emails',
      icon: '✉',
      category: 'google',
    ),
    '/download': SlashCommand(
      name: '/download',
      description: 'Download media from URL',
      icon: '↓',
      category: 'media',
    ),
    '/pdf': SlashCommand(
      name: '/pdf',
      description: 'Create or read PDF documents',
      icon: '◰',
      category: 'text',
    ),
  };

  /// Get the UI font family using Google Fonts (Nunito Sans)
  static String get fontFamilyUI => GoogleFonts.nunitoSans().fontFamily!;

  /// Get the monospace font family using Google Fonts (JetBrains Mono)
  static String get fontFamilyMono => GoogleFonts.jetBrainsMono().fontFamily!;

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.nunitoSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: textPrimary,
        secondary: accentBlue,
        onSecondary: textPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: textPrimary,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textTertiary,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunitoSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.nunitoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: GoogleFonts.nunitoSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withOpacity(0.2),
        labelStyle: GoogleFonts.nunitoSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceVariant,
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: GoogleFonts.nunitoSans(
          fontSize: 14,
          color: textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Monospace text style for code/logs
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.5,
  );

  /// Monospace text style for inline code
  static TextStyle get monoInlineStyle => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: accentCyan,
    backgroundColor: surfaceVariant,
  );
}

/// Slash command definition
class SlashCommand {
  final String name;
  final String description;
  final String icon;
  final String category;

  const SlashCommand({
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}
