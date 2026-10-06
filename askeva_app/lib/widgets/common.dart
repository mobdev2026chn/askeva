import 'package:flutter/material.dart';

import '../api/app_scope.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../data/models.dart';

/// Translucent glass icon button used inside the green header chrome.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const GlassIconButton({super.key, required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// The signature green gradient header. The white content sheet curves up
/// over it (radius 24, -18 overlap) — matching `.lp-head` / `.lp-sheet`.
class GreenHeaderScaffold extends StatelessWidget {
  final String title;
  final VoidCallback? onMenu;
  final List<Widget> actions;

  /// Extra content rendered inside the green header below the top bar
  /// (segmented controls, hero numbers, etc).
  final Widget? headerChild;

  /// Scrollable white-sheet content.
  final Widget sheet;

  final Color? sheetColor;

  const GreenHeaderScaffold({
    super.key,
    required this.title,
    this.onMenu,
    this.actions = const [],
    this.headerChild,
    required this.sheet,
    this.sheetColor,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final bottomPad = mq.padding.bottom;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 24),
          decoration: const BoxDecoration(gradient: AppColors.evaGradient),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 46,
                child: Row(
                  children: [
                    GlassIconButton(icon: Icons.menu_rounded, onTap: onMenu, tooltip: 'Menu'),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.screenTitle.copyWith(color: Colors.white))),
                    ...actions.expand((a) => [a, const SizedBox(width: 8)]),
                  ],
                ),
              ),
              if (headerChild != null) ...[const SizedBox(height: 12), headerChild!],
            ],
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              decoration: BoxDecoration(
                color: sheetColor ?? AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              // Propagate the system-navigation-bar bottom inset so that
              // every scrollable child (ListView, SingleChildScrollView, etc.)
              // inside the sheet automatically adds the correct bottom gap.
              child: MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(top: 0, bottom: bottomPad),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: sheet,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// White segmented control on green (`.lp-seg`).
class GreenSegmented extends StatelessWidget {
  final List<String> items;
  final int selected;
  final ValueChanged<int> onChanged;

  const GreenSegmented({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [const BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))]
                      : null,
                ),
                child: Text(
                  items[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: active ? AppColors.evaGreenDeep : Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Scrollable chip row on green (secondary sub-tabs).
/// Scrollable chip row on green (secondary sub-tabs).
class GreenChipTabs extends StatelessWidget {
  final List<String> items;
  final List<IconData?>? icons;
  final int selected;
  final ValueChanged<int> onChanged;

  const GreenChipTabs({
    super.key,
    required this.items,
    this.icons,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final active = i == selected;
          final hasIcon = icons != null && i < icons!.length && icons![i] != null;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? Colors.white : Colors.white.withValues(alpha: 0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasIcon) ...[
                    Icon(
                      icons![i],
                      size: 14,
                      color: active ? AppColors.evaGreenDeep : Colors.white.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    items[i],
                    style: AppText.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: active ? AppColors.evaGreenDeep : Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// White rounded card (`.cp-card` / `.d2-card`).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Uppercase section heading with optional trailing action (`.lp-secrow`).
class SectionRow extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionRow({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.overline)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
            ),
        ],
      ),
    );
  }
}

/// Section heading with an icon (`.d2-sec`).
class IconSectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  const IconSectionHeading({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 13),
      child: Row(
        children: [
          Icon(icon, size: 21, color: AppColors.evaGreenDeep),
          const SizedBox(width: 9),
          Text(title, style: AppText.sectionTitle),
        ],
      ),
    );
  }
}

/// Lead status pill (`.lp-status`).
class StatusPill extends StatelessWidget {
  final LeadStatus status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: status.fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(status.label.toUpperCase(),
              style: AppText.poppins(size: 11, weight: FontWeight.w800, color: status.fg, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

/// Rounded letter/initials avatar (`.lp-av`).
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  final double size;
  final double radius;

  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 50,
    this.radius = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
      child: Text(initials,
          style: AppText.poppins(size: size * 0.36, weight: FontWeight.w800, color: Colors.white)),
    );
  }
}

/// Dashed-border drop zone used by template/file pickers (`.dropzone`).
class DottedDropzone extends StatelessWidget {
  final Widget child;
  final double height;
  final VoidCallback? onTap;

  const DottedDropzone({super.key, required this.child, this.height = 120, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.evaGreen200
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A small soft-tinted icon chip (`.cp-row .ic`).
class TintIcon extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;
  final double size;
  const TintIcon({
    super.key,
    required this.icon,
    this.fg = AppColors.evaGreenDeep,
    this.bg = AppColors.evaGreen50,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}

class AppTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onChanged;
  const AppTabBar({super.key, required this.tabs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(right: 24, top: 13),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      size: 14.5,
                      weight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.evaGreen : const Color(0xFF6B7A6E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2.5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: active ? AppColors.evaGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Parses a raw JSON string and returns a RichText widget with syntax highlighting matching the reference designs.
Widget buildSyntaxHighlightJson(String json) {
  final List<TextSpan> spans = [];
  
  // Regular expression to match string literals, numbers, booleans/nulls, and JSON punctuation.
  final regExp = RegExp(
    r'("[^"\\]*(?:\\.[^"\\]*)*")|(\b\d+(?:\.\d+)?\b)|(\b(?:true|false|null)\b)|([{}[\],:])|(\s+)|([^"{}[\],:\s\d]+)',
    multiLine: true,
  );
  
  final matches = regExp.allMatches(json);
  
  for (final match in matches) {
    if (match.group(1) != null) {
      final rawStr = match.group(1)!;
      final remaining = json.substring(match.end);
      final trimRemaining = remaining.trimLeft();
      final currentIsKey = trimRemaining.startsWith(':');
      
      if (currentIsKey) {
        spans.add(TextSpan(
          text: rawStr,
          style: const TextStyle(
            color: Color(0xFF0366D6), // Deep blue for keys
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: rawStr,
          style: const TextStyle(
            color: AppColors.evaGreen, // brand green for string values
            fontWeight: FontWeight.w600,
          ),
        ));
      }
    } else if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2)!,
        style: const TextStyle(
          color: Color(0xFFEA580C), // Orange/Brown for numbers
          fontWeight: FontWeight.w600,
        ),
      ));
    } else if (match.group(3) != null) {
      spans.add(TextSpan(
        text: match.group(3)!,
        style: const TextStyle(
          color: Color(0xFF0560FF), // Violet for booleans
          fontWeight: FontWeight.w700,
        ),
      ));
    } else if (match.group(4) != null) {
      spans.add(TextSpan(
        text: match.group(4)!,
        style: const TextStyle(
          color: Color(0xFF334155), // Dark grey for braces/colons/commas
          fontWeight: FontWeight.w600,
        ),
      ));
    } else if (match.group(5) != null) {
      spans.add(TextSpan(text: match.group(5)!));
    } else {
      spans.add(TextSpan(text: match.group(0)!));
    }
  }

  return RichText(
    text: TextSpan(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        height: 1.4,
      ),
      children: spans,
    ),
  );
}

class CountryCodesHelper {
  static const Map<int, int> countryLengths = {
    91: 10, // India
    93: 9, // Afghanistan
    355: 9, // Albania
    213: 9, // Algeria
    1684: 7, // American Samoa
    376: 6, // Andorra
    244: 9, // Angola
    1264: 7, // Anguilla
    672: 6, // Antarctica
    1268: 7, // Antigua and Barbuda
    54: 10, // Argentina
    374: 8, // Armenia
    297: 7, // Aruba
    61: 9, // Australia
    43: 10, // Austria
    994: 9, // Azerbaijan
    1242: 7, // Bahamas
    973: 8, // Bahrain
    880: 10, // Bangladesh
    1246: 7, // Barbados
    375: 9, // Belarus
    32: 9, // Belgium
    501: 7, // Belize
    229: 8, // Benin
    1441: 7, // Bermuda
    975: 8, // Bhutan
    591: 8, // Bolivia
    387: 8, // Bosnia and Herzegovina
    267: 7, // Botswana
    55: 11, // Brazil
    246: 7, // British Indian Ocean Territory
    1284: 7, // British Virgin Islands
    673: 7, // Brunei
    359: 9, // Bulgaria
    226: 8, // Burkina Faso
    257: 8, // Burundi
    855: 9, // Cambodia
    237: 9, // Cameroon
    1: 10, // USA/Canada
    238: 7, // Cape Verde
    1345: 7, // Cayman Islands
    236: 8, // Central African Republic
    235: 9, // Chad
    56: 9, // Chile
    86: 11, // China
    57: 10, // Colombia
    269: 7, // Comoros
    682: 5, // Cook Islands
    506: 8, // Costa Rica
    385: 9, // Croatia
    53: 8, // Cuba
    599: 7, // Curacao
    357: 8, // Cyprus
    420: 9, // Czech Republic
    243: 9, // Congo (DRC)
    45: 8, // Denmark
    253: 6, // Djibouti
    1767: 7, // Dominica
    1809: 10, // Dominican Republic
    670: 8, // East Timor
    593: 9, // Ecuador
    20: 10, // Egypt
    503: 8, // El Salvador
    240: 9, // Equatorial Guinea
    291: 7, // Eritrea
    372: 7, // Estonia
    251: 9, // Ethiopia
    500: 5, // Falkland Islands
    298: 6, // Faroe Islands
    679: 7, // Fiji
    358: 10, // Finland
    33: 9, // France
    241: 9, // Gabon
    220: 7, // Gambia
    995: 9, // Georgia
    49: 10, // Germany
    233: 9, // Ghana
    350: 8, // Gibraltar
    30: 10, // Greece
    299: 6, // Greenland
    1473: 7, // Grenada
    1671: 7, // Guam
    502: 8, // Guatemala
    224: 9, // Guinea
    245: 9, // Guinea-Bissau
    592: 7, // Guyana
    509: 8, // Haiti
    504: 8, // Honduras
    852: 8, // Hong Kong
    36: 9, // Hungary
    354: 7, // Iceland
    62: 10, // Indonesia
    98: 10, // Iran
    964: 10, // Iraq
    353: 9, // Ireland
    972: 9, // Israel
    39: 10, // Italy
    225: 8, // Ivory Coast
    1876: 7, // Jamaica
    81: 10, // Japan
    962: 9, // Jordan
    7: 10, // Kazakhstan/Russia
    254: 9, // Kenya
    686: 8, // Kiribati
    383: 9, // Kosovo
    850: 17, // Korea
    965: 8, // Kuwait
    996: 9, // Kyrgyzstan
    856: 8, // Laos
    371: 8, // Latvia
    961: 8, // Lebanon
    266: 8, // Lesotho
    231: 9, // Liberia
    218: 9, // Libya
    423: 7, // Liechtenstein
    370: 8, // Lithuania
    352: 9, // Luxembourg
    853: 8, // Macau
    389: 8, // Macedonia
    261: 9, // Madagascar
    265: 9, // Malawi
    60: 10, // Malaysia
    960: 7, // Maldives
    223: 8, // Mali
    356: 8, // Malta
    692: 7, // Marshall Islands
    222: 8, // Mauritania
    230: 8, // Mauritius
    262: 9, // Reunion
    52: 10, // Mexico
    691: 7, // Micronesia
    373: 8, // Moldova
    377: 9, // Monaco
    976: 8, // Mongolia
    382: 9, // Montenegro
    1664: 7, // Montserrat
    212: 9, // Morocco
    258: 9, // Mozambique
    95: 9, // Myanmar
    264: 8, // Namibia
    977: 10, // Nepal
    31: 9, // Netherlands
    687: 6, // New Caledonia
    64: 10, // New Zealand
    505: 8, // Nicaragua
    227: 8, // Niger
    234: 10, // Nigeria
    47: 8, // Norway
    968: 8, // Oman
    92: 10, // Pakistan
    680: 7, // Palau
    507: 8, // Panama
    675: 8, // Papua New Guinea
    595: 9, // Paraguay
    51: 9, // Peru
    63: 10, // Philippines
    48: 9, // Poland
    351: 9, // Portugal
    974: 8, // Qatar
    40: 10, // Romania
    250: 9, // Rwanda
    590: 9, // Saint Martin
    966: 9, // Saudi Arabia
    221: 9, // Senegal
    381: 9, // Serbia
    248: 7, // Seychelles
    232: 9, // Sierra Leone
    65: 8, // Singapore
    421: 9, // Slovakia
    386: 9, // Slovenia
    677: 7, // Solomon Islands
    27: 9, // South Africa
    82: 10, // South Korea
    94: 10, // Sri Lanka
    46: 9, // Sweden
    41: 9, // Switzerland
    963: 9, // Syria
    886: 10, // Taiwan
    255: 9, // Tanzania
    66: 9, // Thailand
    228: 8, // Togo
    676: 7, // Tonga
    1868: 7, // Trinidad and Tobago
    216: 8, // Tunisia
    90: 10, // Turkey
    993: 8, // Turkmenistan
    256: 9, // Uganda
    380: 9, // Ukraine
    971: 9, // UAE
    44: 10, // UK
    598: 9, // Uruguay
    998: 9, // Uzbekistan
    678: 7, // Vanuatu
    58: 10, // Venezuela
    84: 10, // Vietnam
    260: 9, // Zambia
    263: 9, // Zimbabwe
  };

  static const Map<int, String> countryNames = {
    91: "India",
    93: "Afghanistan",
    355: "Albania",
    213: "Algeria",
    1684: "American Samoa",
    376: "Andorra",
    244: "Angola",
    1264: "Anguilla",
    672: "Antarctica",
    1268: "Antigua and Barbuda",
    54: "Argentina",
    374: "Armenia",
    297: "Aruba",
    61: "Australia",
    43: "Austria",
    994: "Azerbaijan",
    1242: "Bahamas",
    973: "Bahrain",
    880: "Bangladesh",
    1246: "Barbados",
    375: "Belarus",
    32: "Belgium",
    501: "Belize",
    229: "Benin",
    1441: "Bermuda",
    975: "Bhutan",
    591: "Bolivia",
    387: "Bosnia and Herzegovina",
    267: "Botswana",
    55: "Brazil",
    246: "British Indian Ocean Territory",
    1284: "British Virgin Islands",
    673: "Brunei",
    359: "Bulgaria",
    226: "Burkina Faso",
    257: "Burundi",
    855: "Cambodia",
    237: "Cameroon",
    1: "USA/Canada",
    238: "Cape Verde",
    1345: "Cayman Islands",
    236: "Central African Republic",
    235: "Chad",
    56: "Chile",
    86: "China",
    57: "Colombia",
    269: "Comoros",
    682: "Cook Islands",
    506: "Costa Rica",
    385: "Croatia",
    53: "Cuba",
    599: "Curacao",
    357: "Cyprus",
    420: "Czech Republic",
    243: "Congo (DRC)",
    45: "Denmark",
    253: "Djibouti",
    1767: "Dominica",
    1809: "Dominican Republic",
    670: "East Timor",
    593: "Ecuador",
    20: "Egypt",
    503: "El Salvador",
    240: "Equatorial Guinea",
    291: "Eritrea",
    372: "Estonia",
    251: "Ethiopia",
    500: "Falkland Islands",
    298: "Faroe Islands",
    679: "Fiji",
    358: "Finland",
    33: "France",
    241: "Gabon",
    220: "Gambia",
    995: "Georgia",
    49: "Germany",
    233: "Ghana",
    350: "Gibraltar",
    30: "Greece",
    299: "Greenland",
    1473: "Grenada",
    1671: "Guam",
    502: "Guatemala",
    224: "Guinea",
    245: "Guinea-Bissau",
    592: "Guyana",
    509: "Haiti",
    504: "Honduras",
    852: "Hong Kong",
    36: "Hungary",
    354: "Iceland",
    62: "Indonesia",
    98: "Iran",
    964: "Iraq",
    353: "Ireland",
    972: "Israel",
    39: "Italy",
    225: "Ivory Coast",
    1876: "Jamaica",
    81: "Japan",
    962: "Jordan",
    7: "Kazakhstan/Russia",
    254: "Kenya",
    686: "Kiribati",
    383: "Kosovo",
    850: "Korea",
    965: "Kuwait",
    996: "Kyrgyzstan",
    856: "Laos",
    371: "Latvia",
    961: "Lebanon",
    266: "Lesotho",
    231: "Liberia",
    218: "Libya",
    423: "Liechtenstein",
    370: "Lithuania",
    352: "Luxembourg",
    853: "Macau",
    389: "Macedonia",
    261: "Madagascar",
    265: "Malawi",
    60: "Malaysia",
    960: "Maldives",
    223: "Mali",
    356: "Malta",
    692: "Marshall Islands",
    222: "Mauritania",
    230: "Mauritius",
    262: "Reunion",
    52: "Mexico",
    691: "Micronesia",
    373: "Moldova",
    377: "Monaco",
    976: "Mongolia",
    382: "Montenegro",
    1664: "Montserrat",
    212: "Morocco",
    258: "Mozambique",
    95: "Myanmar",
    264: "Namibia",
    977: "Nepal",
    31: "Netherlands",
    687: "New Caledonia",
    64: "New Zealand",
    505: "Nicaragua",
    227: "Niger",
    234: "Nigeria",
    47: "Norway",
    968: "Oman",
    92: "Pakistan",
    680: "Palau",
    507: "Panama",
    675: "Papua New Guinea",
    595: "Paraguay",
    51: "Peru",
    63: "Philippines",
    48: "Poland",
    351: "Portugal",
    974: "Qatar",
    40: "Romania",
    250: "Rwanda",
    590: "Saint Martin",
    966: "Saudi Arabia",
    221: "Senegal",
    381: "Serbia",
    248: "Seychelles",
    232: "Sierra Leone",
    65: "Singapore",
    421: "Slovakia",
    386: "Slovenia",
    677: "Solomon Islands",
    27: "South Africa",
    82: "South Korea",
    94: "Sri Lanka",
    46: "Sweden",
    41: "Switzerland",
    963: "Syria",
    886: "Taiwan",
    255: "Tanzania",
    66: "Thailand",
    228: "Togo",
    676: "Tonga",
    1868: "Trinidad and Tobago",
    216: "Tunisia",
    90: "Turkey",
    993: "Turkmenistan",
    256: "Uganda",
    380: "Ukraine",
    971: "UAE",
    44: "UK",
    598: "Uruguay",
    998: "Uzbekistan",
    678: "Vanuatu",
    58: "Venezuela",
    84: "Vietnam",
    260: "Zambia",
    263: "Zimbabwe",
  };

  static final List<Map<String, dynamic>> countryCodesList = countryLengths.keys.map((code) {
    return <String, dynamic>{
      'code': code.toString(),
      'name': countryNames[code] ?? 'Unknown',
      'label': '+$code (${countryNames[code] ?? 'Unknown'})',
    };
  }).toList()..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
}

void showSharedCountryCodePicker(BuildContext context, String currentSelected, ValueChanged<String> onSelected) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String searchQuery = '';
      return StatefulBuilder(builder: (ctx, setSt) {
        final filtered = CountryCodesHelper.countryCodesList.where((c) {
          final name = c['name'].toString().toLowerCase();
          final code = c['code'].toString().toLowerCase();
          final q = searchQuery.toLowerCase().replaceAll('+', '').trim();
          return name.contains(q) || code.contains(q);
        }).toList();

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.70,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(ctx).padding.bottom + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Country Code',
                    style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: AppColors.ink3),
                    splashRadius: 20,
                  )
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (val) {
                  setSt(() => searchQuery = val);
                },
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search country or code...',
                  hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
                  prefixIcon: const Icon(Icons.search, color: AppColors.ink3),
                  filled: true,
                  fillColor: const Color(0xFFF5F6F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No countries found',
                          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink4),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final code = c['code'].toString();
                          final isSel = code == currentSelected;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.evaGreen50 : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              title: Text(
                                c['label'].toString(),
                                style: AppText.poppins(
                                  size: 14,
                                  weight: isSel ? FontWeight.w700 : FontWeight.w600,
                                  color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                                ),
                              ),
                              trailing: isSel
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.evaGreenDeep)
                                  : null,
                              onTap: () {
                                onSelected(code);
                                Navigator.of(ctx).pop();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      });
    },
  );
}


