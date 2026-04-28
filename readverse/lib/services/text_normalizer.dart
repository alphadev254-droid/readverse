import 'package:flutter/foundation.dart';
import 'package:number_to_words/number_to_words.dart';

/// Professional TTS text normalization with context-aware token classification
/// 
/// Architecture:
/// 1. Detection Layer - Classify tokens by context (phone, date, currency, etc.)
/// 2. Normalization Layer - Apply context-specific rules
/// 3. Output Layer - Return speakable text
class TextNormalizer {
  TextNormalizer._();

  /// Main normalization entry point
  static String normalize(String rawText, {String locale = 'en-in'}) {
    debugPrint('[TextNormalizer] Input length: ${rawText.length}');
    debugPrint('[TextNormalizer] First 150 chars: "${rawText.length > 150 ? rawText.substring(0, 150) : rawText}"');
    
    String text = rawText;

    // CRITICAL FIXES for TTS reliability:
    // 1. Replace pipe separators with commas (TTS reads | as "email address")
    text = text.replaceAll(RegExp(r'\s*\|\s*'), ', ');
    
    // 2. Remove + prefix from phone numbers (confuses TTS engine)
    text = text.replaceAllMapped(RegExp(r'\+(\d)'), (m) => m[1]!);
    
    // 3. Replace email addresses entirely (TTS reads them badly)
    text = text.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b'),
      'email address omitted',
    );

    // 4. Inject sentence boundary between contact block and section headings
    // Turns "Nairobi, Kenya\nEXECUTIVE SUMMARY" → "Nairobi, Kenya. EXECUTIVE SUMMARY"
    text = text.replaceAllMapped(
      RegExp(r'([^\n.!?])\n([A-Z]{2}[A-Z\s&/]+)\n'),
      (m) => '${m[1]}.\n${m[2]}\n',
    );
    
    // 5. Inject break before all-caps run-ons when newlines were collapsed
    // Turns "Kenya EXECUTIVE SUMMARY" → "Kenya. EXECUTIVE SUMMARY"
    text = text.replaceAllMapped(
      RegExp(r'(\b[A-Z][a-z]+)\s+([A-Z]{3,}(?:\s+[A-Z&/]+){0,4})\s'),
      (m) => '${m[1]}. ${m[2]} ',
    );

    debugPrint('[TextNormalizer] After initial fixes: "${text.length > 150 ? text.substring(0, 150) : text}"');

    // Order matters: most specific patterns first
    text = _normalizePhoneNumbers(text);
    text = _normalizeCurrency(text, locale);
    text = _normalizeDates(text);
    text = _normalizeTime(text);
    text = _normalizeUnits(text, locale);
    text = _normalizeAbbreviations(text);
    text = _normalizeEmailsAndUrls(text);
    text = _normalizeNumbers(text, locale);
    
    // Cleanup
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    debugPrint('[TextNormalizer] Final output length: ${text.length}');
    debugPrint('[TextNormalizer] Final first 150 chars: "${text.length > 150 ? text.substring(0, 150) : text}"');

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PHONE NUMBERS
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizePhoneNumbers(String text) {
    // Simple regex-based approach - more reliable than library parsing
    // Matches: +254712345678, 0712345678, etc.
    text = text.replaceAllMapped(
      RegExp(r'(\+?\d{10,15})'),
      (m) {
        final phoneStr = m[1]!;
        // Only convert if it looks like a phone number (not a year, ID, etc.)
        if (phoneStr.startsWith('+') || phoneStr.startsWith('0')) {
          return _phoneToWords(phoneStr);
        }
        return phoneStr;
      },
    );
    
    return text;
  }

  static String _phoneToWords(String digits) {
    final parts = <String>[];
    String current = '';
    
    for (int i = 0; i < digits.length; i++) {
      final char = digits[i];
      if (char == '+') {
        parts.add('plus');
        continue;
      }
      
      current += char;
      
      // Group every 3 digits for natural pacing
      if (current.length == 3 || i == digits.length - 1) {
        parts.add(current.split('').map(_digitToWord).join(' '));
        current = '';
      }
    }
    
    return parts.join(', ');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CURRENCY - Context-aware detection
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeCurrency(String text, String locale) {
    // Kenyan Shillings: KSh, Ksh, KES
    text = text.replaceAllMapped(
      RegExp(r'\b(KSh|Ksh|KES)\.?\s?(\d+(?:,\d{3})*(?:\.\d+)?)\b', caseSensitive: false),
      (m) {
        final numStr = m[2]!.replaceAll(',', '');
        return _currencyToWords(numStr, 'Kenya shillings', locale);
      },
    );

    // US Dollars
    text = text.replaceAllMapped(
      RegExp(r'\$(\d+(?:,\d{3})*(?:\.\d+)?)\b'),
      (m) {
        final numStr = m[1]!.replaceAll(',', '');
        return _currencyToWords(numStr, 'dollars', locale);
      },
    );

    // Euros
    text = text.replaceAllMapped(
      RegExp(r'€(\d+(?:,\d{3})*(?:\.\d+)?)\b'),
      (m) {
        final numStr = m[1]!.replaceAll(',', '');
        return _currencyToWords(numStr, 'euros', locale);
      },
    );

    // Pounds
    text = text.replaceAllMapped(
      RegExp(r'£(\d+(?:,\d{3})*(?:\.\d+)?)\b'),
      (m) {
        final numStr = m[1]!.replaceAll(',', '');
        return _currencyToWords(numStr, 'pounds', locale);
      },
    );

    return text;
  }

  static String _currencyToWords(String numStr, String currency, String locale) {
    final parts = numStr.split('.');
    final whole = int.tryParse(parts[0]);
    
    if (whole == null) return '$currency $numStr';
    
    try {
      final words = NumberToWord().convert(locale, whole);
      
      if (parts.length > 1 && parts[1].isNotEmpty) {
        final cents = int.tryParse(parts[1].padRight(2, '0').substring(0, 2));
        if (cents != null && cents > 0) {
          final centsWords = NumberToWord().convert(locale, cents);
          return '$currency $words and $centsWords cents';
        }
      }
      
      return '$currency $words';
    } catch (e) {
      return '$currency $numStr';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DATES - Multiple formats with context detection
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeDates(String text) {
    // DD/MM/YYYY or DD-MM-YYYY
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{4})\b'),
      (m) {
        final day = int.tryParse(m[1]!);
        final month = int.tryParse(m[2]!);
        final year = m[3];
        
        if (day == null || month == null || month > 12 || day > 31) {
          return m[0]!;
        }
        
        final monthName = _getMonthName(month);
        return '$day $monthName $year';
      },
    );

    // YYYY-MM-DD (ISO format)
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b'),
      (m) {
        final year = m[1];
        final month = int.tryParse(m[2]!);
        final day = int.tryParse(m[3]!);
        
        if (day == null || month == null || month > 12 || day > 31) {
          return m[0]!;
        }
        
        final monthName = _getMonthName(month);
        return '$day $monthName $year';
      },
    );

    // Month abbreviations: Jan, Feb, etc.
    final monthAbbrevs = {
      r'\bJan\.?': 'January',
      r'\bFeb\.?': 'February',
      r'\bMar\.?': 'March',
      r'\bApr\.?': 'April',
      r'\bMay\.?': 'May',
      r'\bJun\.?': 'June',
      r'\bJul\.?': 'July',
      r'\bAug\.?': 'August',
      r'\bSep\.?|Sept\.?': 'September',
      r'\bOct\.?': 'October',
      r'\bNov\.?': 'November',
      r'\bDec\.?': 'December',
    };

    monthAbbrevs.forEach((pattern, replacement) {
      text = text.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TIME - 12:30, 14:45, etc.
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeTime(String text) {
    // HH:MM format
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}):(\d{2})\s?(AM|PM|am|pm)?\b'),
      (m) {
        final hour = int.tryParse(m[1]!);
        final minute = int.tryParse(m[2]!);
        final period = m[3]?.toUpperCase();
        
        if (hour == null || minute == null || hour > 23 || minute > 59) {
          return m[0]!;
        }
        
        String result = '';
        
        if (period != null) {
          // 12-hour format
          result = '$hour ${minute == 0 ? "o'clock" : minute.toString()} $period';
        } else {
          // 24-hour format
          final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          final displayPeriod = hour >= 12 ? 'PM' : 'AM';
          result = '$displayHour ${minute == 0 ? "o'clock" : minute.toString()} $displayPeriod';
        }
        
        return result;
      },
    );

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UNITS - kg, km, km/h, etc.
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeUnits(String text, String locale) {
    final unitMap = {
      r'(\d+)\s?kg\b': (Match m) => '${_numberToWords(m[1]!, locale)} kilograms',
      r'(\d+)\s?g\b': (Match m) => '${_numberToWords(m[1]!, locale)} grams',
      r'(\d+)\s?km\b': (Match m) => '${_numberToWords(m[1]!, locale)} kilometers',
      r'(\d+)\s?m\b': (Match m) => '${_numberToWords(m[1]!, locale)} meters',
      r'(\d+)\s?cm\b': (Match m) => '${_numberToWords(m[1]!, locale)} centimeters',
      r'(\d+)\s?km/h\b': (Match m) => '${_numberToWords(m[1]!, locale)} kilometers per hour',
      r'(\d+)\s?mph\b': (Match m) => '${_numberToWords(m[1]!, locale)} miles per hour',
      r'(\d+)\s?%': (Match m) => '${_numberToWords(m[1]!, locale)} percent',
      r'(\d+)\s?°C\b': (Match m) => '${_numberToWords(m[1]!, locale)} degrees Celsius',
      r'(\d+)\s?°F\b': (Match m) => '${_numberToWords(m[1]!, locale)} degrees Fahrenheit',
    };

    unitMap.forEach((pattern, converter) {
      text = text.replaceAllMapped(RegExp(pattern, caseSensitive: false), converter);
    });

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ABBREVIATIONS - Context dictionary for Kenyan/African context
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeAbbreviations(String text) {
    // Titles & Honorifics
    final abbrevMap = {
      // Common titles
      r'\bDr\.': 'Doctor',
      r'\bMr\.': 'Mister',
      r'\bMrs\.': 'Missus',
      r'\bMs\.': 'Miss',
      r'\bProf\.': 'Professor',
      r'\bSgt\.': 'Sergeant',
      r'\bCpt\.': 'Captain',
      r'\bCol\.': 'Colonel',
      r'\bGen\.': 'General',
      r'\bRev\.': 'Reverend',
      r'\bFr\.': 'Father',
      r'\bSr\.': 'Sister',
      
      // Kenyan/African specific
      r'\bMheshimiwa\b': 'Honorable',
      r'\bMhe\.': 'Honorable',
      
      // Places
      r'\bSt\.': 'Saint',
      r'\bRd\.': 'Road',
      r'\bAve\.': 'Avenue',
      r'\bBlvd\.': 'Boulevard',
      r'\bSt\b(?!\.)': 'Street', // "St" without period
      
      // Business
      r'\bCo\.': 'Company',
      r'\bLtd\.': 'Limited',
      r'\bInc\.': 'Incorporated',
      r'\bCorp\.': 'Corporation',
      r'\bPty\.': 'Proprietary',
      
      // Common phrases
      r'\be\.g\.': 'for example',
      r'\bi\.e\.': 'that is',
      r'\betc\.': 'et cetera',
      r'\bvs\.': 'versus',
      r'\bNo\.': 'Number',
      r'\bS/N\b': 'Serial Number',
      r'\bJr\.': 'Junior',
      r'\bSr\.': 'Senior',
      r'\bEsq\.': 'Esquire',
      
      // Academic
      r'\bPhD\b': 'Doctor of Philosophy',
      r'\bMBA\b': 'Master of Business Administration',
      r'\bBA\b': 'Bachelor of Arts',
      r'\bBSc\b': 'Bachelor of Science',
      
      // Organizations
      r'\bUN\b': 'United Nations',
      r'\bNGO\b': 'Non-Governmental Organization',
      r'\bCEO\b': 'Chief Executive Officer',
      r'\bCFO\b': 'Chief Financial Officer',
      r'\bCTO\b': 'Chief Technology Officer',
    };

    abbrevMap.forEach((pattern, replacement) {
      text = text.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMAILS & URLs
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeEmailsAndUrls(String text) {
    // Replace emails
    text = text.replaceAll(
      RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'),
      'email address',
    );

    // Replace URLs
    text = text.replaceAll(
      RegExp(r'https?://[^\s]+'),
      'link',
    );

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NUMBERS - Context-aware (avoid years, IDs, etc.)
  // ═══════════════════════════════════════════════════════════════════════

  static String _normalizeNumbers(String text, String locale) {
    // Only convert standalone numbers 0-999 to avoid converting:
    // - Years (1945, 2024)
    // - IDs (12345)
    // - Large numbers that are better as digits
    text = text.replaceAllMapped(
      RegExp(r'\b(\d{1,2})\b'),
      (m) => _numberToWords(m[1]!, locale),
    );

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  static String _numberToWords(String numStr, String locale) {
    final num = int.tryParse(numStr);
    if (num == null) return numStr;
    
    try {
      return NumberToWord().convert(locale, num);
    } catch (e) {
      return numStr;
    }
  }

  static String _digitToWord(String digit) {
    const words = {
      '0': 'zero',
      '1': 'one',
      '2': 'two',
      '3': 'three',
      '4': 'four',
      '5': 'five',
      '6': 'six',
      '7': 'seven',
      '8': 'eight',
      '9': 'nine',
    };
    return words[digit] ?? digit;
  }

  static String _getMonthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return month >= 1 && month <= 12 ? months[month] : month.toString();
  }
}
