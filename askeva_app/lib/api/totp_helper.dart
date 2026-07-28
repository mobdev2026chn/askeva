import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpHelper {
  TotpHelper._();

  /// Decodes a Base32 string into a [Uint8List].
  static Uint8List decodeBase32(String secret) {
    final cleanSecret = secret.replaceAll(' ', '').replaceAll('=', '').toUpperCase();
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    
    var bits = 0;
    var value = 0;
    final bytes = <int>[];
    
    for (var i = 0; i < cleanSecret.length; i++) {
      final char = cleanSecret[i];
      final idx = alphabet.indexOf(char);
      if (idx < 0) continue;
      
      value = (value << 5) | idx;
      bits += 5;
      
      if (bits >= 8) {
        bytes.add((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    
    return Uint8List.fromList(bytes);
  }

  /// Generates a 6-digit TOTP code for a given Base32 secret and counter.
  static String generateTotp(String secret, int counter) {
    try {
      final key = decodeBase32(secret);
      final hmac = Hmac(sha1, key);
      
      // Manually pack the 64-bit integer into 8 bytes (big-endian)
      final counterBytes = Uint8List(8);
      var temp = counter;
      for (var i = 7; i >= 0; i--) {
        counterBytes[i] = temp & 0xff;
        temp = temp >> 8;
      }
      
      final digest = hmac.convert(counterBytes);
      final hash = digest.bytes;
      
      // Dynamic truncation
      final offset = hash[hash.length - 1] & 0x0f;
      final binary = ((hash[offset] & 0x7f) << 24) |
                     ((hash[offset + 1] & 0xff) << 16) |
                     ((hash[offset + 2] & 0xff) << 8) |
                     (hash[offset + 3] & 0xff);
                     
      final code = binary % 1000000;
      return code.toString().padLeft(6, '0');
    } catch (_) {
      return '';
    }
  }

  /// Gets the current 30-second epoch counter.
  static int getTotpCounter() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;
  }

  /// Verifies a 6-digit TOTP code against the secret (with ±1 step time skew).
  static bool verifyTotpCode(String secret, String code) {
    final cleanCode = code.replaceAll(RegExp(r'\D'), '');
    if (cleanCode.length != 6 || secret.isEmpty) return false;
    
    final currentCounter = getTotpCounter();
    
    // Check current step, one step back, and one step forward
    for (var i = -1; i <= 1; i++) {
      final expected = generateTotp(secret, currentCounter + i);
      if (expected == cleanCode) {
        return true;
      }
    }
    
    return false;
  }

  /// Verifies and consumes a backup code. Returns true if valid, false otherwise.
  static bool verifyBackupCode(List<String> backups, String code) {
    final cleanCode = code.trim().toLowerCase();
    if (cleanCode.isEmpty) return false;
    
    for (var i = 0; i < backups.length; i++) {
      if (backups[i].toLowerCase() == cleanCode) {
        backups.removeAt(i);
        return true;
      }
    }
    
    return false;
  }
}
