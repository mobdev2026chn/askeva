import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MLKitOCRService {
  static Future<Map<String, dynamic>> processImage(String imagePath) async {
    final InputImage inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      final String rawText = recognizedText.text;

      // Extract lines for processing
      List<String> lines = rawText
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Smart Detection Logic
      String? email = _detectEmail(rawText);
      String? mobile = _detectPhone(rawText);
      String? website = _detectWebsite(rawText, email);

      // Address detection requires multiline analysis
      Map<String, String?> addressAndZip = _detectAddressAndPincode(
        lines,
        email,
        mobile,
        website,
      );
      String? address = addressAndZip['address'];
      String? pincode = addressAndZip['pincode'];
      String? city = _detectCity(lines, address);

      // Associate pincode with address if found but not in the address string
      if (pincode != null && address != null && !address.contains(pincode)) {
        address = '$address, $pincode';
      }

      // Name and Company heuristics
      String? name = _detectName(lines, email, mobile, website, address);
      String? company = _detectCompany(
        lines,
        email,
        mobile,
        website,
        address,
        name,
      );
      String? position = _detectPosition(lines, name, company, address);

      // Final cleaning of phone number to 10 digits if it's longer (e.g. +91)
      if (mobile != null && mobile.length > 10) {
        if (mobile.startsWith('91')) {
          mobile = mobile.substring(2);
        } else if (mobile.startsWith('0'))
          mobile = mobile.substring(1);
      }

      return {
        'parsed': {
          'name': name,
          'companyName': company,
          'mobile': mobile,
          'email': email,
          'website': website,
          'address': address ?? '',
          'city': city,
          'position': position ?? '',
          'pincode': pincode,
          'confidence': _calculateConfidence(name, company, mobile, email),
        },
        'rawText': rawText,
      };
    } catch (e) {
      print('MLKitOCRService Error: $e');
      return {'parsed': {}, 'rawText': ''};
    } finally {
      textRecognizer.close();
    }
  }

  static String? _detectEmail(String text) {
    // Handle artifacts like "gm ail . com" or "user (at) domain.com"
    String normalized = text
        .replaceAll(' (a) ', '@')
        .replaceAll(' @ ', '@')
        .replaceAll('(at)', '@')
        .replaceAll('[at]', '@')
        .replaceAll(RegExp(r'\s+'), ' ');

    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+\s?@\s?[a-zA-Z0-9.-]+\s?\.\s?[a-zA-Z]{2,6}',
      caseSensitive: false,
    );

    final match = emailRegex.firstMatch(normalized);
    if (match != null) {
      return match.group(0)!.replaceAll(' ', '').toLowerCase();
    }

    // Deeper search for spaced out emails
    final spacedEmailRegex = RegExp(
      r'([a-zA-Z0-9]\s?)+\s?@\s?([a-zA-Z0-9-]\s?)+(\.\s?([a-zA-Z0-9-]\s?)+)+',
    );
    final spacedMatch = spacedEmailRegex.firstMatch(text);
    if (spacedMatch != null) {
      return spacedMatch.group(0)!.replaceAll(' ', '').toLowerCase();
    }

    return null;
  }

  static String? _detectPhone(String text) {
    // Remove labels like "Mob:", "Ph:", "T:"
    String cleaned = text.replaceAll(
      RegExp(r'[Mm]ob(?:ile)?[:\s]+|[Pp]h(?:one)?[:\s]+|[Tt]el[:\s]+'),
      '',
    );

    // Indian phone regex: +91 or 0 prefix, starting with 6-9, 10 digits total
    final phoneRegex = RegExp(
      r'(?:\+91|0|91)?\s?[6-9]\s?\d{1}\s?\d{3}\s?\d{5}',
    );

    final matches = phoneRegex.allMatches(cleaned);
    if (matches.isNotEmpty) {
      String bestMatch = matches.first.group(0)!;
      return bestMatch.replaceAll(RegExp(r'\D'), '');
    }

    final genericRegex = RegExp(r'\d{3}[\s-]?\d{3}[\s-]?\d{4}');
    final gMatch = genericRegex.firstMatch(cleaned);
    if (gMatch != null) {
      return gMatch.group(0)!.replaceAll(RegExp(r'\D'), '');
    }

    return null;
  }

  static String? _detectWebsite(String text, String? email) {
    final domainRegex = RegExp(
      r'\b(https?:\/\/)?(www\.)?([a-zA-Z0-9-]+\.)+(com|in|org|net|co|biz|info|gov|edu)\b',
      caseSensitive: false,
    );

    final commonEmailDomains = {
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'icloud.com',
      'aol.com',
      'zoho.com',
      'mail.com',
      'rediffmail.com',
      'live.com',
      'me.com',
    };

    final matches = domainRegex.allMatches(text);
    for (var m in matches) {
      String w = m.group(0)!;
      String lowerW = w.toLowerCase();

      // Basic check: must not contain @ (to avoid matching full emails)
      if (lowerW.contains('@')) continue;

      // Filter out common email domains
      String domainOnly = lowerW
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .replaceAll('www.', '');
      if (commonEmailDomains.contains(domainOnly)) continue;

      // Filter out domain of found email if it doesn't have 'www.'
      if (email != null && email.toLowerCase().endsWith('@$domainOnly')) {
        if (!lowerW.contains('www.')) continue;
      }

      if (!w.startsWith('http')) {
        w = 'https://$w';
      }
      return w.toLowerCase();
    }
    return null;
  }

  static Map<String, String?> _detectAddressAndPincode(
    List<String> lines,
    String? email,
    String? mobile,
    String? website,
  ) {
    final pincodeRegex = RegExp(r'\b\d{6}\b');
    final phonePattern = RegExp(
      r'(?:\+91|0|91)?\s?[6-9]\s?\d{1}\s?\d{1}(?:\s?\d{1}){7}|\d{3}[\s-]?\d{3}[\s-]?\d{4}|\d{10}',
    );
    final addrKeywords = {
      'nagar',
      'street',
      'road',
      'rd',
      'st',
      'plaza',
      'layout',
      'hosur',
      'chennai',
      'bangalore',
      'mumbai',
      'floor',
      'building',
      'bldg',
      'plot',
      'sector',
      'city',
      'state',
      'india',
      'avenue',
      'colony',
      'apartment',
      'flat',
      'complex',
      'opposite',
      'opp',
      'near',
      'landmark',
      'phase',
      'industrial',
      'area',
      'lane',
      'cross',
      'main',
      'district',
      'village',
      'taluk',
      'extension',
      'extn',
    };

    List<String> addressLines = [];
    String? foundPincode;

    for (var i = 0; i < lines.length; i++) {
      String line = lines[i];
      String lowerLine = line.toLowerCase();

      if (email != null && lowerLine.contains(email.toLowerCase())) continue;
      if (website != null &&
          lowerLine.contains(website.replaceAll('https://', '').toLowerCase())) {
        continue;
      }

      String flatLine = line.replaceAll(RegExp(r'\s+'), '');
      if (phonePattern.hasMatch(flatLine)) continue;
      if (mobile != null && flatLine.contains(mobile)) continue;

      bool hasPincode = pincodeRegex.hasMatch(line);
      if (hasPincode) {
        foundPincode = pincodeRegex.firstMatch(line)?.group(0);
      }

      bool hasAddressKeyword = addrKeywords.any((kw) => lowerLine.contains(kw));
      bool hasAddressStructure = RegExp(
        r'\d{1,5}(/|-)?\d{0,5},',
      ).hasMatch(line);

      if (hasPincode || hasAddressKeyword || hasAddressStructure) {
        addressLines.add(line);

        if (addressLines.length == 1 && i > 0) {
          String prev = lines[i - 1];
          String flatPrev = prev.replaceAll(RegExp(r'\s+'), '');
          if (prev.length > 5 &&
              !prev.contains('@') &&
              !phonePattern.hasMatch(flatPrev)) {
            addressLines.insert(0, prev);
          }
        }
      }
    }

    return {
      'address': addressLines.isNotEmpty ? addressLines.join(', ') : null,
      'pincode': foundPincode,
    };
  }

  static String? _detectCity(List<String> lines, String? address) {
    final cities = {
      'chennai',
      'bangalore',
      'mumbai',
      'delhi',
      'hyderabad',
      'pune',
      'kolkata',
      'ahmedabad',
      'surat',
      'jaipur',
      'lucknow',
      'kanpur',
      'indore',
      'nagpur',
      'thane',
      'bhopal',
      'visakhapatnam',
      'pimpri-chinchwad',
      'patna',
      'vadodara',
      'ghaziabad',
      'ludhiana',
      'agra',
      'nashik',
      'faridabad',
      'meerut',
      'rajkot',
      'kalyan-dombivli',
      'vasai-virar',
      'varanasi',
      'srinagar',
      'aurangabad',
      'dhanbad',
      'amritsar',
      'navi mumbai',
      'allahabad',
      'ranchi',
      'howrah',
      'jabalpur',
      'gwalior',
    };

    if (address != null) {
      for (String city in cities) {
        if (address.toLowerCase().contains(city)) {
          return city[0].toUpperCase() + city.substring(1);
        }
      }
    }

    for (String line in lines) {
      for (String city in cities) {
        if (line.toLowerCase().contains(city)) {
          return city[0].toUpperCase() + city.substring(1);
        }
      }
    }
    return null;
  }

  static String? _detectName(
    List<String> lines,
    String? email,
    String? mobile,
    String? website,
    String? address,
  ) {
    final nameRegex = RegExp(r'^[a-zA-Z.\s]{3,30}$');
    final companySuffixes = {
      'pvt',
      'ltd',
      'inc',
      'corp',
      'solutions',
      'tech',
      'systems',
      'group',
      'services',
      'enterprise',
      'industries',
      'associates',
    };

    for (var i = 0; i < (lines.length < 5 ? lines.length : 5); i++) {
      String line = lines[i].trim();
      String lowerLine = line.toLowerCase();

      if (line.isEmpty) continue;
      if (email != null && lowerLine.contains(email.toLowerCase())) continue;
      if (mobile != null && line.contains(mobile)) continue;
      if (address != null && address.contains(line)) continue;
      if (companySuffixes.any((s) => lowerLine.contains(s))) continue;

      final titles = {
        'manager',
        'director',
        'founder',
        'ceo',
        'vp',
        'executive',
        'partner',
        'proprietor',
        'salestrack',
      };
      if (titles.any((t) => lowerLine.contains(t))) continue;

      if (nameRegex.hasMatch(line) && line.split(' ').length >= 2) {
        return line;
      }
    }
    return null;
  }

  static String? _detectCompany(
    List<String> lines,
    String? email,
    String? mobile,
    String? website,
    String? address,
    String? name,
  ) {
    final companySuffixes = {
      'pvt',
      'ltd',
      'inc',
      'corp',
      'solutions',
      'technologies',
      'systems',
      'group',
      'services',
      'enterprise',
      'industries',
      'associates',
    };
    final genericExclusions = {
      'wholesaler',
      'retail',
      'dealer',
      'store',
      'supplies',
      'shop',
      'mob',
      'email',
      'ph',
      'tel',
      'address',
      'visit',
    };

    for (String line in lines) {
      String lowerLine = line.toLowerCase();
      if (companySuffixes.any((s) => lowerLine.contains(s))) {
        if (name != null && (name == line || line.contains(name))) continue;
        return line;
      }
    }

    if (lines.isNotEmpty) {
      for (int i = 0; i < (lines.length < 3 ? lines.length : 3); i++) {
        String top = lines[i];
        if (top != name &&
            !top.contains('@') &&
            !RegExp(r'\d').hasMatch(top) &&
            top.length > 3) {
          bool isExclusion = genericExclusions.any(
            (e) => top.toLowerCase().contains(e),
          );
          if (!isExclusion) return top;
        }
      }
    }

    return null;
  }

  static String? _detectPosition(
    List<String> lines,
    String? name,
    String? company,
    String? address,
  ) {
    final posKeywords = {
      'manager',
      'director',
      'lead',
      'engineer',
      'developer',
      'founder',
      'ceo',
      'vp',
      'president',
      'consultant',
      'executive',
      'chief',
      'proprietor',
      'partner',
      'specialist',
      'analyst',
      'associate',
      'owner',
      'co-founder',
    };

    for (String line in lines) {
      String lowerLine = line.toLowerCase();
      if (line == name ||
          line == company ||
          (address != null && address.contains(line))) {
        continue;
      }

      if (posKeywords.any((kw) => lowerLine.contains(kw))) {
        return line;
      }
    }
    return null;
  }

  static int _calculateConfidence(
    String? name,
    String? company,
    String? mobile,
    String? email,
  ) {
    int score = 0;
    if (name != null) score += 25;
    if (company != null) score += 25;
    if (mobile != null) score += 25;
    if (email != null) score += 25;
    return score;
  }
}
