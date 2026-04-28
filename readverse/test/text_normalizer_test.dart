import 'package:flutter_test/flutter_test.dart';
import 'package:readverse/services/text_normalizer.dart';

void main() {
  group('TextNormalizer', () {
    test('normalizes phone numbers', () {
      final input = 'Call me at +254712345678 or 0712345678';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('plus'));
      expect(output, contains('two five four'));
    });

    test('normalizes Kenyan currency', () {
      final input = 'The price is Ksh 5,000 or KSh 10,500.50';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('Kenya shillings'));
      expect(output, contains('five thousand'));
    });

    test('normalizes dates', () {
      final input = 'Meeting on 10/04/2026 at 14:30';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('April'));
      expect(output, contains('2026'));
      expect(output, contains('PM'));
    });

    test('normalizes abbreviations', () {
      final input = 'Dr. Njoroge from St. James Rd. called';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('Doctor'));
      expect(output, contains('Saint'));
      expect(output, contains('Road'));
    });

    test('normalizes units', () {
      final input = 'Speed limit is 80 km/h and weight is 50 kg';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('kilometers per hour'));
      expect(output, contains('kilograms'));
    });

    test('normalizes emails and URLs', () {
      final input = 'Contact john@example.com or visit https://example.com';
      final output = TextNormalizer.normalize(input);
      
      expect(output, contains('email address'));
      expect(output, contains('link'));
    });

    test('comprehensive normalization', () {
      final input = '''
Dr. Njoroge called +254712345678 about Ksh 5,000 payment.
Meeting on 10/04/2026 at St. James Rd.
Contact: john@example.com or visit https://example.com
Speed limit: 80 km/h, Temperature: 25°C
''';
      
      final output = TextNormalizer.normalize(input);
      
      // Should contain normalized forms
      expect(output, contains('Doctor'));
      expect(output, contains('Kenya shillings'));
      expect(output, contains('April'));
      expect(output, contains('Saint'));
      expect(output, contains('Road'));
      expect(output, contains('email address'));
      expect(output, contains('link'));
      expect(output, contains('kilometers per hour'));
      expect(output, contains('degrees Celsius'));
      
      // Should NOT contain raw forms
      expect(output, isNot(contains('Dr.')));
      expect(output, isNot(contains('Ksh')));
      expect(output, isNot(contains('@')));
      expect(output, isNot(contains('http')));
    });

    test('handles edge cases gracefully', () {
      final input = 'Invalid date 99/99/9999 and malformed phone 123';
      final output = TextNormalizer.normalize(input);
      
      // Should not crash, just leave invalid data as-is or handle gracefully
      expect(output, isNotEmpty);
    });

    test('preserves years and large numbers', () {
      final input = 'In 2024, the ID was 12345';
      final output = TextNormalizer.normalize(input);
      
      // Years and IDs should NOT be converted to words
      expect(output, contains('2024'));
      expect(output, contains('12345'));
    });
  });
}
