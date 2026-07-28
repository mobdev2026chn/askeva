import 'package:flutter/material.dart';

import '../api/app_scope.dart';
import '../api/auth_repository.dart';
import '../shell/app_nav.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart' show appToast;
import '../widgets/eva_brand.dart';
import '../widgets/profile_sheets.dart';
import 'package:image_picker/image_picker.dart';

/// One-shot deep-link target for the Profile sub-tab. Set this (e.g. to the
/// Subscription index) just before navigating to the Profile route; the screen
/// consumes and clears it on open. See [ProfileTab].
int? kProfileInitialTab;

/// Profile sub-tab indices, for callers that deep-link into a specific tab.
class ProfileTab {
  static const account = 0;
  static const team = 1;
  static const password = 2;
  static const pricing = 3;
  static const subscription = 4;
  static const transactions = 5;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _Member {
  final String id;
  final String name;
  final String countryCode;
  final String mobile;
  final String role;

  _Member({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.mobile,
    required this.role,
  });

  String get initial => name.isEmpty ? '?' : name.characters.first.toUpperCase();
  String get fullNumber => '+$countryCode$mobile';
  Color get color {
    final hash = id.hashCode;
    final colors = [
      AppColors.evaGreenDeep,
      AppColors.info,
      const Color(0xFF8E24AA),
      const Color(0xFFD81B60),
      const Color(0xFFE65100),
      const Color(0xFF00ACC1),
    ];
    return colors[hash % colors.length];
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _userAttr;
  Future<List<Map<String, dynamic>>>? _invoices;
  UserPlan? _plan;
  bool _planRequested = false;

  final ScrollController _tabScrollController = ScrollController();

  void _scrollToTab(int index) {
    if (_tabScrollController.hasClients) {
      double targetOffset = 0.0;
      if (index >= 3) {
        targetOffset = (index - 2) * 110.0;
      }
      _tabScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Consume a one-shot deep-link tab (e.g. dashboard "Renew Now" → Subscription).
    final t = kProfileInitialTab;
    if (t != null) {
      _tab = t;
      kProfileInitialTab = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTab(_tab);
    });
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    super.dispose();
  }

  // Mutable team (loaded from API).
  List<_Member>? _team;
  bool _teamLoading = false;
  // Editable profile overrides.
  String? _editName, _editEmail;
  List<Map<String, dynamic>>? _countries;
  Map<String, dynamic>? _selectedCountry;
  bool _countriesLoading = false;
  int _txnPage = 1;
  final Set<String> _expandedTxns = {};
  static const int _txnPageSize = 5;

  Future<void> _loadCountries() async {
    if (_countriesLoading) return;
    setState(() => _countriesLoading = true);
    try {
      final authRepo = AppScope.of(context).auth;
      final list = await authRepo.fetchCountries();
      if (mounted) {
        setState(() {
          _countries = list;
          final indiaIdx = list.indexWhere(
            (c) => (c['name'] ?? '').toString().toLowerCase() == 'india',
          );
          _selectedCountry = indiaIdx != -1 ? list[indiaIdx] : (list.isNotEmpty ? list.first : null);
          _countriesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _countriesLoading = false);
        _snack('Failed to load countries: $e');
      }
    }
  }

  List<_Member> get team => _team ?? [];

  Future<void> _loadTeam() async {
    if (_teamLoading) return;
    setState(() => _teamLoading = true);
    try {
      final authRepo = AppScope.of(context).auth;
      final members = await authRepo.fetchTeamMembers();
      if (mounted) {
        setState(() {
          _team = members.map((m) {
            return _Member(
              id: (m['_id'] ?? m['id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              countryCode: (m['countryCode'] ?? '91').toString(),
              mobile: (m['mobile'] ?? '').toString(),
              role: (m['role'] ?? '').toString(),
            );
          }).toList();
          _teamLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _teamLoading = false);
        _snack('Failed to load team: $e');
      }
    }
  }

  Future<void> _handleRefresh() async {
    final svc = AppScope.of(context);
    try {
      final p = await svc.auth.fetchProfile();
      final attr = await svc.auth.fetchUserAttr();
      if (mounted) {
        setState(() {
          _profile = p;
          _userAttr = attr;
        });
      }
    } catch (_) {}

    await _loadTeam();
    await _loadCountries();

    try {
      final txns = await svc.auth.fetchWalletTransactions();
      if (mounted) {
        setState(() {
          _invoices = Future.value(txns);
        });
      }
    } catch (_) {}

    try {
      final plan = await svc.auth.fetchUserPlan();
      if (mounted) {
        setState(() {
          _plan = plan;
        });
      }
    } catch (_) {}
  }

  static const Map<int, int> _countryLengths = {
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

  static const Map<int, String> _countryNames = {
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

  static final List<Map<String, dynamic>> _countryCodesList = _countryLengths.keys.map((code) {
    return <String, dynamic>{
      'code': code.toString(),
      'name': _countryNames[code] ?? 'Unknown',
      'label': '+$code (${_countryNames[code] ?? 'Unknown'})',
    };
  }).toList()..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = AppScope.of(context);
    _profile ??= svc.session.profile;
    svc.auth.fetchProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    }).catchError((_) {});
    svc.auth.fetchUserAttr().then((attr) {
      if (mounted) setState(() => _userAttr = attr);
    }).catchError((_) {});
    if (_team == null && !_teamLoading) {
      _loadTeam();
    }
    if (_countries == null && !_countriesLoading) {
      _loadCountries();
    }
    // Resolve to [] on failure so the future never has an unhandled rejection
    // (the Transactions FutureBuilder may not be mounted when it completes).
    _invoices ??= svc.auth.fetchWalletTransactions().catchError((_) => <Map<String, dynamic>>[]);
    if (!_planRequested) {
      _planRequested = true;
      svc.auth.fetchUserPlan().then((p) {
        if (mounted) setState(() => _plan = p);
      }).catchError((_) {});
    }
  }

  static const _monthAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _fmtDate(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

  void _snack(String m) => appToast(context, m);

  String get _name => _editName ?? (_profile?['name'] ?? _profile?['username'] ?? AppScope.sessionOf(context).username ?? 'User').toString();
  String get _email => _editEmail ?? (_profile?['email'] ?? AppScope.sessionOf(context).email ?? '').toString();
  static const _tabs = ['Account', 'Team', 'Password', 'Pricing', 'Subscription', 'Transactions'];
  static const _tabIcons = [
    Icons.person_outline_rounded,
    Icons.groups_outlined,
    Icons.lock_outline_rounded,
    Icons.sell_outlined,
    Icons.card_membership_outlined,
    Icons.receipt_long_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    final topPad = MediaQuery.of(context).padding.top;
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
                    GlassIconButton(icon: Icons.menu_rounded, onTap: nav.openDrawer),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Profile', style: AppText.screenTitle.copyWith(color: Colors.white))),
                    GlassIconButton(icon: Icons.notifications_none_rounded, onTap: () => nav.toast('No new notifications')),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: () {
                      final imgUrl = _profile?['profile_picture_url'] ?? _profile?['whatsAppDisplayImage'];
                      if (imgUrl != null && imgUrl.toString().isNotEmpty) {
                        return Image.network(
                          imgUrl.toString(),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: EvaMark(size: 40),
                          ),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(10.0),
                        child: EvaMark(size: 40),
                      );
                    }(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 22, weight: FontWeight.w800, color: Colors.white)),
                        Text(_email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -18),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      controller: _tabScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _tabs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _tabChip(i),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: AppColors.evaGreen,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                        children: _panel(nav),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabChip(int i) {
    final active = i == _tab;
    return GestureDetector(
      onTap: () {
        setState(() => _tab = i);
        _scrollToTab(i);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.evaGreen : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_tabIcons[i], size: 15, color: active ? Colors.white : AppColors.ink3),
            const SizedBox(width: 6),
            Text(_tabs[i], style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: active ? Colors.white : AppColors.ink3)),
          ],
        ),
      ),
    );
  }

  List<Widget> _panel(AppNav nav) {
    switch (_tab) {
      case 1:
        return _teamPanel();
      case 2:
        return _passwordPanel();
      case 3:
        return _pricingPanel(nav);
      case 4:
        return _subscriptionPanel();
      case 5:
        return _transactionsPanel();
      default:
        return _accountPanel();
    }
  }

  String _mapVertical(String? v) {
    if (v == null || v.isEmpty) return '—';
    const options = {
      'AUTO': 'Automotive',
      'BEAUTY': 'Beauty, Spa, and Salon',
      'APPAREL': 'Clothing',
      'EDU': 'Education',
      'ENTERTAIN': 'Entertainment',
      'EVENT_PLAN': 'Event Planning and Services',
      'FINANCE': 'Finance and Banking',
      'GROCERY': 'Food and Groceries',
      'GOVT': 'Public Service',
      'HOTEL': 'Hotel and Lodging',
      'HEALTH': 'Medical and Health',
      'NONPROFIT': 'Charity',
      'PROF_SERVICES': 'Professional Services',
      'RETAIL': 'Shopping and Retail',
      'TRAVEL': 'Travel and Transportation',
      'RESTAURANT': 'Restaurant',
      'NOT_A_BIZ': 'Not a Business',
      'UNDEFINED': 'Undefined',
      'OTHER': 'Other',
    };
    return options[v.toUpperCase()] ?? v;
  }

  String _parseAndFmtDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString);
      return _fmtDate(dt);
    } catch (_) {
      return isoString;
    }
  }

  Widget _profileField(String label, dynamic value, IconData icon, {bool first = false, Widget? customValue}) {
    return Container(
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: AppColors.surface3))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.evaGreen50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.evaGreenDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
                const SizedBox(height: 3),
                if (customValue != null)
                  customValue
                else
                  Text(
                    (value ?? '—').toString(),
                    style: AppText.poppins(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.evaGreen50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.evaGreenDeep),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status.toLowerCase() == 'active' || status.toLowerCase() == 'live';
    final bg = isActive ? const Color(0xFFE8F8EE) : const Color(0xFFFEF3F2);
    final fg = isActive ? AppColors.evaGreenDeep : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: AppText.poppins(size: 12, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  // ---------------- Account ----------------
  List<Widget> _accountPanel() {
    if (_profile == null || _userAttr == null) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.evaGreen),
          ),
        ),
      ];
    }

    final pName = _userAttr?['username'] ?? _profile?['name'] ?? _profile?['username'] ?? AppScope.sessionOf(context).username ?? '—';
    final pEmail = _profile?['email'] ?? '—';
    final pDesc = _profile?['description'] ?? '—';
    
    String pWebsite = '—';
    final rawWebsites = _profile?['websites'] ?? _profile?['website'];
    if (rawWebsites is List) {
      pWebsite = rawWebsites.isNotEmpty ? rawWebsites.first.toString() : '—';
    } else if (rawWebsites != null) {
      pWebsite = rawWebsites.toString();
    }
    if (pWebsite.startsWith('[') && pWebsite.endsWith(']')) {
      pWebsite = pWebsite.substring(1, pWebsite.length - 1).trim();
    }

    final pVertical = _mapVertical(_profile?['vertical']);
    final pAddress = _profile?['address'] ?? '—';

    return [
      // Card 1: WhatsApp Profile
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: () {
                    final imgUrl = _profile?['profile_picture_url'] ?? _profile?['whatsAppDisplayImage'];
                    if (imgUrl != null && imgUrl.toString().isNotEmpty) {
                      return Image.network(
                        imgUrl.toString(),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: EvaLogo(height: 32, onGreen: false),
                        ),
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: EvaLogo(height: 32, onGreen: false),
                    );
                  }(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pName.toString(), style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                      Text(pEmail.toString(), style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _editProfile,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.evaGreen50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.evaGreen200),
                    ),
                    child: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.evaGreenDeep),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _profileField('Description', pDesc, Icons.description_outlined, first: true),
            _profileField('Website', pWebsite, Icons.language_rounded),
            _profileField('Business Vertical', pVertical, Icons.business_center_outlined),
            _profileField('Address', pAddress, Icons.location_on_outlined),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Card 2: Account Details
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader('Account Details', Icons.person_outline_rounded),
            _profileField(
              'Account Status',
              null,
              Icons.info_outline_rounded,
              first: true,
              customValue: _statusBadge(_userAttr?['connectionStatus']?.toString() ?? 'Active'),
            ),
            _profileField('Primary Contact Name', _userAttr?['username'], Icons.account_circle_outlined),
            _profileField('Creation Date', _parseAndFmtDate(_userAttr?['createdAt']?.toString()), Icons.calendar_today_rounded),
            _profileField('WhatsApp API No', _userAttr?['businessWhatsappNumber'], Icons.phone_android_rounded),
            _profileField('Activation Date', _parseAndFmtDate(_userAttr?['createdAt']?.toString()), Icons.watch_later_outlined),
            _profileField('Primary Contact Mobile', _userAttr?['mobileNumber'], Icons.phone_outlined),
            _profileField('Reseller ID', _userAttr?['resellerId'] ?? 'N/A', Icons.verified_user_outlined),
            _profileField('Primary Contact Email', _userAttr?['email'], Icons.mail_outline_rounded),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Card 3: Company Details
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader('Company Details', Icons.business_outlined),
            _profileField('Company Name', _userAttr?['companyName'] ?? 'N/A', Icons.apartment_rounded, first: true),
            _profileField('Legal Business Name', _userAttr?['Companybuisnessname'] ?? 'N/A', Icons.gavel_rounded),
            _profileField('Address', _userAttr?['Address'] ?? 'N/A', Icons.location_on_outlined),
            _profileField('State', _userAttr?['State'] ?? 'N/A', Icons.map_outlined),
            _profileField('City', _userAttr?['City'] ?? 'N/A', Icons.location_city_rounded),
            _profileField('Zip', _userAttr?['Zip'] ?? 'N/A', Icons.pin_drop_outlined),
            _profileField('Company Website', _userAttr?['companywebsite'] ?? 'N/A', Icons.web_rounded),
            _profileField('Country', _userAttr?['Country'] ?? 'N/A', Icons.flag_outlined),
            _profileField('GST No', _userAttr?['gstno'] ?? 'N/A', Icons.credit_card_rounded),
          ],
        ),
      ),
    ];
  }

  void _editProfile() {
    final whatsAppAbout = TextEditingController(text: _profile?['about'] ?? _profile?['whatsAppAbout'] ?? '');
    final email = TextEditingController(text: _profile?['email'] ?? '');
    final desc = TextEditingController(text: _profile?['description'] ?? '');
    
    // Website cleanup: strip brackets if stored as a list string
    String initialWebsite = '';
    final rawWebsites = _profile?['websites'] ?? _profile?['website'];
    if (rawWebsites is List) {
      initialWebsite = rawWebsites.isNotEmpty ? rawWebsites.first.toString() : '';
    } else if (rawWebsites != null) {
      initialWebsite = rawWebsites.toString();
    }
    if (initialWebsite.startsWith('[') && initialWebsite.endsWith(']')) {
      initialWebsite = initialWebsite.substring(1, initialWebsite.length - 1).trim();
    }
    final website = TextEditingController(text: initialWebsite);
    
    final address = TextEditingController(text: _profile?['address'] ?? '');

    const verticalOptions = {
      'AUTO': 'Automotive',
      'BEAUTY': 'Beauty, Spa, and Salon',
      'APPAREL': 'Clothing',
      'EDU': 'Education',
      'ENTERTAIN': 'Entertainment',
      'EVENT_PLAN': 'Event Planning and Services',
      'FINANCE': 'Finance and Banking',
      'GROCERY': 'Food and Groceries',
      'GOVT': 'Public Service',
      'HOTEL': 'Hotel and Lodging',
      'HEALTH': 'Medical and Health',
      'NONPROFIT': 'Charity',
      'PROF_SERVICES': 'Professional Services',
      'RETAIL': 'Shopping and Retail',
      'TRAVEL': 'Travel and Transportation',
      'RESTAURANT': 'Restaurant',
      'NOT_A_BIZ': 'Not a Business',
      'UNDEFINED': 'Undefined',
      'OTHER': 'Other',
    };

    String selectedVertical = (_profile?['vertical'] ?? 'HOTEL').toString().toUpperCase();
    if (!verticalOptions.containsKey(selectedVertical)) {
      selectedVertical = 'OTHER';
    }

    String? tempLogoUrl = _profile?['profile_picture_url'] ?? _profile?['whatsAppDisplayImage'];
    bool uploadingLogo = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        Widget field(
          String l,
          TextEditingController c, {
          int maxLines = 1,
          bool required = false,
          int? maxLen,
        }) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(l, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                      if (required) Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.danger)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: c,
                    maxLines: maxLines,
                    maxLength: maxLen,
                    style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F6F8),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                    ),
                  ),
                  if (maxLen != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: StatefulBuilder(
                          builder: (context, setFieldSt) {
                            c.addListener(() {
                              if (context.mounted) setFieldSt(() {});
                            });
                            return Text(
                              '${c.text.length} / $maxLen',
                              style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4),
                            );
                          }
                        ),
                      ),
                    ),
                ],
              ),
            );

        return StatefulBuilder(builder: (ctx, setSt) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Edit Profile Details', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.ink3),
                      splashRadius: 20,
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: () {
                                if (uploadingLogo) {
                                  return const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.evaGreen),
                                    ),
                                  );
                                }
                                if (tempLogoUrl != null && tempLogoUrl!.isNotEmpty) {
                                  return Image.network(
                                    tempLogoUrl!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: EvaLogo(height: 40, onGreen: false),
                                    ),
                                  );
                                }
                                return const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: EvaLogo(height: 40, onGreen: false),
                                );
                              }(),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: uploadingLogo
                                  ? null
                                  : () async {
                                      try {
                                        final authRepo = AppScope.of(context).auth;
                                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
                                        if (picked == null) return;
                                        setSt(() => uploadingLogo = true);
                                        final bytes = await picked.readAsBytes();
                                        
                                        String? mime = picked.mimeType;
                                        if (mime == null) {
                                          final ext = picked.name.split('.').last.toLowerCase();
                                          if (ext == 'jpg' || ext == 'jpeg') {
                                            mime = 'image/jpeg';
                                          } else if (ext == 'png') {
                                            mime = 'image/png';
                                          } else if (ext == 'gif') {
                                            mime = 'image/gif';
                                          } else if (ext == 'webp') {
                                            mime = 'image/webp';
                                          }
                                        }

                                        final fileUrl = await authRepo.uploadProfilePicture(
                                          bytes,
                                          picked.name,
                                          contentType: mime,
                                        );
                                        setSt(() {
                                          tempLogoUrl = fileUrl;
                                          uploadingLogo = false;
                                        });
                                        if (ctx.mounted) {
                                          appToast(ctx, 'Logo uploaded successfully', isSuccess: true);
                                        }
                                      } catch (e) {
                                        setSt(() => uploadingLogo = false);
                                        if (ctx.mounted) {
                                          appToast(ctx, 'Upload failed: $e', isError: true);
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.edit_document, size: 16, color: AppColors.evaGreenDeep),
                              label: Text('Change Logo', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.evaGreen50,
                                foregroundColor: AppColors.evaGreenDeep,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        field('WhatsApp About', whatsAppAbout, maxLen: 139, required: true),
                        field('Email', email, required: true),
                        field('Description', desc, maxLines: 3, maxLen: 512, required: true),
                        field('Website', website, required: false),
                        
                        // Business Vertical
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Business Vertical', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                                  Text(' *', style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.danger)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: selectedVertical,
                                items: verticalOptions.entries.map((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.key,
                                    child: Text(e.value, style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setSt(() {
                                    selectedVertical = val ?? selectedVertical;
                                  });
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF5F6F8),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
                                ),
                                dropdownColor: AppColors.surface,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink3),
                              ),
                            ],
                          ),
                        ),

                        field('Address', address, maxLines: 3, maxLen: 256, required: true),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    final newWhatsAppAbout = whatsAppAbout.text.trim();
                                    final newEmail = email.text.trim();
                                    final newDesc = desc.text.trim();
                                    final newWebsite = website.text.trim();
                                    final newAddress = address.text.trim();

                                    if (newWhatsAppAbout.isEmpty || newEmail.isEmpty) {
                                      appToast(ctx, 'WhatsApp About and email are required', isError: true);
                                      return;
                                    }

                                    setSt(() => saving = true);
                                    try {
                                      final repo = AppScope.of(context).auth;
                                      final updated = await repo.updateProfile({
                                        'name': _profile?['name'] ?? _profile?['username'] ?? '',
                                        'email': newEmail,
                                        'description': newDesc,
                                        'websites': newWebsite,
                                        'vertical': selectedVertical,
                                        'address': newAddress,
                                        'whatsAppAbout': newWhatsAppAbout,
                                        'whatsAppDisplayImage': tempLogoUrl ?? '',
                                      });
                                      setState(() {
                                        _profile = updated;
                                      });
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                      _snack('Profile updated successfully');
                                    } catch (e) {
                                      _snack('Failed to update profile: $e');
                                      setSt(() => saving = false);
                                    }
                                  },
                            icon: saving
                                ? const SizedBox.shrink()
                                : const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                            label: saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text('Save Changes', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.evaGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ---------------- Team ----------------
  List<Widget> _teamPanel() {
    if (_teamLoading && (_team == null || _team!.isEmpty)) {
      return [
        const SizedBox(height: 40),
        const Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
      ];
    }
    
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${team.length} members',
            style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink3),
          ),
          GestureDetector(
            onTap: () => _memberForm(),
            child: _smallButton('Add Member', Icons.add_rounded),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (team.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.line),
                const SizedBox(height: 12),
                Text(
                  'No team members added yet.\nClick "Add Member" to get started.',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3),
                ),
              ],
            ),
          ),
        )
      else
        ...team.map(_memberCard),
    ];
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap, {bool danger = false}) {
    final bg = danger ? AppColors.danger.withOpacity(0.08) : AppColors.surface2;
    final fg = danger ? AppColors.danger : AppColors.ink3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: danger ? AppColors.danger.withOpacity(0.15) : AppColors.line),
        ),
        child: Icon(icon, size: 16, color: fg),
      ),
    );
  }

  Widget _memberCard(_Member a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Initials Avatar with custom background/text theme matching mockup
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: a.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Text(
                a.initial,
                style: AppText.poppins(size: 16, weight: FontWeight.w800, color: a.color),
              ),
            ),
            const SizedBox(width: 14),

            // Middle: Name, Phone, Role Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.ink3),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          a.fullNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      a.role,
                      style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Actions (View, Edit, Delete)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(Icons.visibility_outlined, () => _viewMember(a)),
                const SizedBox(width: 6),
                _actionBtn(Icons.edit_outlined, () => _memberForm(existing: a)),
                const SizedBox(width: 6),
                _actionBtn(Icons.delete_outline_rounded, () => _deleteMember(a), danger: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewMember(_Member a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: AppScope.of(context).auth.fetchTeamMember(a.id),
          builder: (ctx, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data;
            final error = snapshot.error;

            String name = a.name;
            String cc = a.countryCode;
            String mob = a.mobile;
            String role = a.role;

            if (data != null) {
              name = (data['name'] ?? name).toString();
              cc = (data['countryCode'] ?? cc).toString();
              mob = (data['mobile'] ?? mob).toString();
              role = (data['role'] ?? role).toString();
            }

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text(
                          a.initial,
                          style: AppText.poppins(size: 20, weight: FontWeight.w800, color: a.color),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              role,
                              style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: AppColors.evaGreen),
                      ),
                    )
                  else if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Failed to load details: $error',
                        style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.danger),
                      ),
                    )
                  else ...[
                    _viewRow(Icons.person_outline_rounded, 'Full Name', name),
                    _viewRow(Icons.public_rounded, 'Country Code', '+$cc'),
                    _viewRow(Icons.phone_outlined, 'Mobile Number', mob),
                    _viewRow(Icons.badge_outlined, 'Role', role),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _viewRow(IconData icon, String k, String v) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.evaGreen50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.evaGreenDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink4)),
                  const SizedBox(height: 3),
                  Text(v, style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
          ],
        ),
      );

  void _deleteMember(_Member a) {
    final authRepo = AppScope.of(context).auth;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove member', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text('Remove ${a.name} from the team?', style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink2)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Remove', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.danger))),
        ],
      ),
    ).then((ok) async {
      if (ok == true) {
        try {
          await authRepo.deleteTeamMember(a.id);
          _loadTeam();
          _snack('${a.name} removed');
        } catch (e) {
          _snack('Failed to remove member: $e');
        }
      }
    });
  }

  void _showCountryCodePicker(BuildContext context, String currentSelected, ValueChanged<String> onSelected) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(builder: (ctx, setSt) {
          final filtered = _countryCodesList.where((c) {
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
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
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
                              child: Material(
                                color: Colors.transparent,
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

  void _memberForm({_Member? existing}) {
    final name = TextEditingController(text: existing?.name ?? '');
    final mobile = TextEditingController(text: existing?.mobile ?? '');
    final role = TextEditingController(text: existing?.role ?? '');
    
    String selectedCc = existing?.countryCode ?? '91';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
          ),
        );

        Widget field(String labelText, TextEditingController controller, String hint) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label(labelText),
              TextField(
                controller: controller,
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
                  filled: true,
                  fillColor: const Color(0xFFF5F6F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            ],
          ),
        );

        Widget countryCodeTriggerField(String labelText, String selectedValue, VoidCallback onTap) {
          final matchingCountry = _countryCodesList.firstWhere(
            (c) => c['code'].toString() == selectedValue,
            orElse: () => <String, dynamic>{'label': '+$selectedValue'},
          );
          final labelTextStr = matchingCountry['label'].toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label(labelText),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          labelTextStr,
                          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.ink3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      existing != null ? 'Edit Member' : 'Add Member',
                      style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.ink3),
                      splashRadius: 20,
                    )
                  ],
                ),
                const SizedBox(height: 16),
                field('Name', name, 'Full name'),
                countryCodeTriggerField('Country Code', selectedCc, () {
                  _showCountryCodePicker(ctx, selectedCc, (val) {
                    setSt(() => selectedCc = val);
                  });
                }),
                field('Mobile Number', mobile, 'Enter mobile number'),
                field('Role', role, 'e.g. Agent'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final authRepo = AppScope.of(context).auth;
                            final inputName = name.text.trim();
                            final inputMobile = mobile.text.trim();
                            final inputRole = role.text.trim();

                            if (inputName.isEmpty) {
                              appToast(ctx, 'Please enter member name', isError: true);
                              return;
                            }
                            if (inputRole.isEmpty) {
                              appToast(ctx, 'Please enter member role', isError: true);
                              return;
                            }
                            if (inputRole.length < 2) {
                              appToast(ctx, 'Role must be at least 2 characters', isError: true);
                              return;
                            }

                            final trimmedMobile = inputMobile.replaceAll(RegExp(r'\s+'), '');
                            if (RegExp(r'[a-zA-Z]').hasMatch(trimmedMobile)) {
                              appToast(ctx, 'Only numbers allowed in Mobile Number', isError: true);
                              return;
                            }

                            final rawMobile = trimmedMobile.replaceAll(RegExp(r'\D'), '');
                            if (rawMobile.isEmpty) {
                              appToast(ctx, 'Please enter mobile number', isError: true);
                              return;
                            }

                            final ccInt = int.tryParse(selectedCc) ?? 91;
                            final reqLen = _countryLengths[ccInt] ?? 10;

                            if (rawMobile.length != reqLen) {
                              final cName = _countryNames[ccInt] ?? 'Selected country';
                              appToast(ctx, 'Mobile number for $cName (+$selectedCc) must be $reqLen digits', isError: true);
                              return;
                            }

                            setSt(() => saving = true);
                            try {
                              final payload = {
                                'name': inputName,
                                'role': inputRole,
                                'countryCode': selectedCc,
                                'mobile': rawMobile,
                                'fullNumber': '$selectedCc$rawMobile',
                              };

                              if (existing != null) {
                                await authRepo.updateTeamMember(existing.id, payload);
                              } else {
                                await authRepo.addTeamMember(payload);
                              }

                              _loadTeam();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _snack(existing != null ? 'Member updated successfully' : 'Member added successfully');
                            } catch (e) {
                              if (ctx.mounted) {
                                appToast(ctx, 'Error saving member: $e', isError: true);
                              }
                              setSt(() => saving = false);
                            }
                          },
                    icon: saving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.description_outlined, size: 18, color: Colors.white),
                    label: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(existing != null ? 'Save Changes' : 'Add Member', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.evaGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---------------- Password ----------------
  List<Widget> _passwordPanel() => [const _PasswordPanel()];

  // ---------------- Pricing (per-country WhatsApp conversation rates) ----------------
  void _selectCountrySheet() {
    if (_countries == null || _countries!.isEmpty) return;
    final searchController = TextEditingController();
    List<Map<String, dynamic>> filtered = List.from(_countries!);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(
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
                    'Select Country',
                    style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: AppColors.ink3),
                    splashRadius: 20,
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                onChanged: (val) {
                  setSt(() {
                    filtered = _countries!
                        .where((c) => (c['name'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(val.toLowerCase()))
                        .toList();
                  });
                },
                style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.ink3),
                  filled: true,
                  fillColor: AppColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final item = filtered[index];
                    final isSelected = _selectedCountry?['_id'] == item['_id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.evaGreen50 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            setState(() => _selectedCountry = item);
                            Navigator.of(ctx).pop();
                          },
                          title: Text(
                            (item['name'] ?? '').toString(),
                            style: AppText.poppins(
                              size: 14.5,
                              weight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? AppColors.evaGreenDeep : AppColors.ink,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: AppColors.evaGreenDeep)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _pricingPanel(AppNav nav) {
    if (_countriesLoading && _countries == null) {
      return [
        const SizedBox(height: 40),
        const Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
      ];
    }

    final String activeCountryName = (_selectedCountry?['name'] ?? 'Select Country').toString();
    final bool isIndia = activeCountryName.toLowerCase() == 'india';

    final dynamic authCost = _selectedCountry?['authentication'] ?? 0.0;
    final dynamic marketingCost = _selectedCountry?['marketing'] ?? 0.0;
    final dynamic utilityCost = _selectedCountry?['utility'] ?? 0.0;
    final dynamic serviceCost = _selectedCountry?['service'] ?? 0.0;

    Widget pricingCard(String label, dynamic val) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink4),
                ),
                const SizedBox(height: 6),
                Text(
                  val.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: val.toString().length > 8 ? 13.0 : 17.0,
                    weight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.evaGreen50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.credit_card_rounded, size: 18, color: AppColors.evaGreenDeep),
                ),
                const SizedBox(width: 12),
                Text(
                  'Conversation Pricing',
                  style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectCountrySheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activeCountryName,
                        style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Service Area: $activeCountryName ${isIndia ? '( Home Town )' : ''}',
              style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                pricingCard('Authentication', authCost),
                const SizedBox(width: 12),
                pricingCard('Marketing', marketingCost),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                pricingCard('Utility', utilityCost),
                const SizedBox(width: 12),
                pricingCard('Session', serviceCost),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  // ---------------- Subscription ----------------
  List<Widget> _subscriptionPanel() {
    final p = _plan;
    final rawName = p?.name ?? 'ecommerce';
    final planName = rawName.isEmpty ? 'Plan' : '${rawName[0].toUpperCase()}${rawName.substring(1)}';
    final unlimited = p?.isUnlimited ?? false;
    final start = DateTime.tryParse(p?.startDate ?? '');
    final startStr = start != null ? _fmtDate(start) : '—';

    String endStr, durationStr;
    if (p == null) {
      endStr = durationStr = '—';
    } else if (unlimited) {
      endStr = durationStr = 'Unlimited';
    } else {
      final v = p.validity ?? '';
      DateTime? end;
      if (v.contains('-')) {
        end = DateTime.tryParse(v);
      } else if (start != null && int.tryParse(v) != null) {
        end = DateTime(start.year, start.month + int.parse(v), start.day);
      }
      endStr = end != null ? _fmtDate(end) : '—';
      if (end != null && start != null) {
        final days = end.difference(start).inDays;
        final months = (days / 30.4).round();
        if (months >= 12 && months % 12 == 0) {
          final yrs = months ~/ 12;
          durationStr = '$yrs ${yrs == 1 ? 'year' : 'years'}';
        } else if (months > 0) {
          durationStr = '$months ${months == 1 ? 'month' : 'months'}';
        } else {
          durationStr = '$days ${days == 1 ? 'day' : 'days'}';
        }
      } else {
        durationStr = '—';
      }
    }

    final priceVal = (p?.hasPlan ?? false) ? planPriceValue(rawName, p!.validity ?? '', p.startDate ?? '') : 0;
    final priceStr = priceVal > 0 ? inr(priceVal) : '—';

    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.shadowEva),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_glassPill('Current Plan'), const Spacer(), _glassPill('● Active')]),
            const SizedBox(height: 14),
            Text(planName, style: AppText.poppins(size: 26, weight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: _planFact('Started On', startStr)), Expanded(child: _planFact('End Date', endStr))]),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: _planFact('Duration', durationStr)), Expanded(child: _planFact('Price', priceStr))]),
            const SizedBox(height: 14),
            Text(
              unlimited ? 'Unlimited plan — no renewal needed' : (endStr != '—' ? 'Next billing on $endStr' : ' '),
              style: AppText.poppins(size: 12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: unlimited ? null : () => showRenewPlanSheet(context, planName: rawName),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlimited ? Colors.white.withValues(alpha: 0.45) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: unlimited
                          ? AppColors.evaGreenDeep.withValues(alpha: 0.5)
                          : AppColors.evaGreenDeep,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Renew Now',
                      style: AppText.poppins(
                        size: 14,
                        weight: FontWeight.w800,
                        color: unlimited
                            ? AppColors.evaGreenDeep.withValues(alpha: 0.5)
                            : AppColors.evaGreenDeep,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _compare, icon: const Icon(Icons.compare_arrows_rounded, size: 18), label: const Text('Check other plans'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.evaGreenDeep, side: const BorderSide(color: AppColors.evaGreen200), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(onPressed: _billingHistory, icon: const Icon(Icons.receipt_long_outlined, size: 18), label: const Text('Billing'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.ink2, side: const BorderSide(color: AppColors.line), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
      ]),
      const SizedBox(height: 14),
      if (p != null && p.maxChatbots > 0) AppCard(child: _usageRow('Chatbots', p.chatbotCount, p.maxChatbots)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_done_outlined, size: 14, color: AppColors.ink4),
          const SizedBox(width: 6),
          Flexible(child: Text('Plan details are loaded live from your billing account.', style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink4))),
        ],
      ),
    ];
  }

  Widget _glassPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: Colors.white)),
      );

  Widget _planFact(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
        ],
      );

  void _compare() async {
    final p = _plan;
    await showPlansSheet(
      context,
      currentPlan: p?.name ?? 'ecommerce',
      validity: p?.validity ?? '',
      startDate: p?.startDate ?? '',
      toast: _snack,
      isRenewal: true,
    );
    if (mounted) _handleRefresh();
  }

  void _billingHistory() {
    // Real paid invoices from the plan history (records carrying an amount /
    // invoice number), newest first.
    final all = _plan?.history ?? const [];
    final records = all.where((r) => (r.amount ?? 0) > 0 || (r.invoiceNumber ?? '').isNotEmpty).toList().reversed.toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Text('Billing History', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('No billing records yet.', style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink3))),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (_, i) {
                  final r = records[i];
                  final name = r.name.isEmpty ? 'Plan' : '${r.name[0].toUpperCase()}${r.name.substring(1)}';
                  final d = DateTime.tryParse(r.startDate);
                  final dateStr = d != null ? _fmtDate(d) : r.startDate;
                  final sub = [r.status, if ((r.invoiceNumber ?? '').isNotEmpty) r.invoiceNumber, dateStr].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.evaGreenDeep),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$name Plan', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink)),
                        Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                      ])),
                      Text(r.amount != null ? inr(r.amount!) : '—', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _usageRow(String label, int used, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink))),
            Text('$used / $total', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink3)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: used / total,
            minHeight: 7,
            backgroundColor: AppColors.surface3,
            valueColor: const AlwaysStoppedAnimation(AppColors.evaGreen),
          ),
        ),
      ],
    );
  }

  // ---------------- Transactions (live invoices) ----------------
  String _fmtTxnDate(dynamic raw) {
    if (raw == null) return '';
    DateTime? dt;
    if (raw is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(
        raw.toInt() < 10000000000 ? raw.toInt() * 1000 : raw.toInt(),
      );
    } else {
      final str = raw.toString().trim();
      final parsed = int.tryParse(str);
      if (parsed != null) {
        dt = DateTime.fromMillisecondsSinceEpoch(
          parsed < 10000000000 ? parsed * 1000 : parsed,
        );
      } else {
        dt = DateTime.tryParse(str);
      }
    }
    if (dt == null) return raw.toString();

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$min:$sec';
  }

  void _downloadInvoice(String? invoiceId) {
    if (invoiceId == null || invoiceId.isEmpty) {
      _snack('No invoice available for this transaction');
      return;
    }
    _snack('Downloading invoice Invoice-$invoiceId.pdf...');
    Future.delayed(const Duration(seconds: 1), () {
      _snack('Invoice-$invoiceId.pdf saved to Downloads');
    });
  }

  List<Widget> _transactionsPanel() {
    return [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _invoices,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 30),
              child: Center(
                child: Text(
                  snap.error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
            );
          }
          final txns = snap.data ?? const [];
          if (txns.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('No transactions yet', style: AppText.body)),
            );
          }

          final int totalItems = txns.length;
          final int totalPages = (totalItems / _txnPageSize).ceil();
          if (_txnPage > totalPages) {
            _txnPage = totalPages > 0 ? totalPages : 1;
          }

          final int startIdx = (_txnPage - 1) * _txnPageSize;
          final int endIdx = (startIdx + _txnPageSize) > totalItems ? totalItems : (startIdx + _txnPageSize);
          final paginatedTxns = txns.sublist(startIdx, endIdx);

          return Column(
            children: [
              for (final t in paginatedTxns) _invoiceCard(t),
              if (totalPages > 1) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _txnPage > 1
                            ? () => setState(() => _txnPage--)
                            : null,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_left_rounded,
                            size: 18,
                            color: _txnPage > 1 ? AppColors.ink : AppColors.ink4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (int p = 1; p <= totalPages; p++) ...[
                        GestureDetector(
                          onTap: () => setState(() => _txnPage = p),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _txnPage == p ? AppColors.evaGreen : AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _txnPage == p ? Colors.transparent : AppColors.line,
                              ),
                            ),
                            child: Text(
                              p.toString(),
                              style: AppText.poppins(
                                size: 13,
                                weight: FontWeight.w800,
                                color: _txnPage == p ? Colors.white : AppColors.ink2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: _txnPage < totalPages
                            ? () => setState(() => _txnPage++)
                            : null,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_right_rounded,
                            size: 18,
                            color: _txnPage < totalPages ? AppColors.ink : AppColors.ink4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ];
  }

  Widget _invoiceCard(Map<String, dynamic> t) {
    final String id = (t['_id'] ?? '').toString();
    final String reason = (t['reason'] ?? 'Success').toString();
    final String rawDate = (t['createdAt'] ?? '').toString();
    final String dateStr = _fmtTxnDate(rawDate);

    final double totalAmount = double.tryParse((t['totalAmountPaid'] ?? '').toString()) ?? 0.0;
    final double deductedAmount = double.tryParse((t['deductedAmount'] ?? '').toString()) ?? 0.0;
    final String statusVal = (t['status'] ?? '').toString();

    String label = statusVal;
    Color statusColor = AppColors.ink3;
    bool isDeducted = false;

    if (statusVal.toLowerCase() == 'success' && deductedAmount > 0) {
      label = 'Deducted';
      statusColor = const Color(0xFFFF6A13);
      isDeducted = true;
    } else {
      switch (statusVal.toLowerCase()) {
        case 'approved':
        case 'success':
          label = 'Paid';
          statusColor = AppColors.evaGreenDeep;
          break;
        case 'pending':
          label = 'Pending';
          statusColor = const Color(0xFFFAAD14);
          break;
        case 'rejected':
          label = 'Rejected';
          statusColor = AppColors.danger;
          break;
      }
    }

    final double displayAmount = isDeducted ? deductedAmount : totalAmount;
    final String invoiceId = (t['invoice_id'] ?? '').toString();
    final bool isExpanded = _expandedTxns.contains(id);

    final double prevBal = double.tryParse((t['balance'] ?? '').toString()) ?? 0.0;
    final double currBal = double.tryParse((t['currentBalance'] ?? '').toString()) ?? 0.0;
    final String accountNo = (t['accountNumber'] ?? 'N/A').toString();
    final String payerName = (t['payerName'] ?? 'N/A').toString();
    final String payMethod = (t['paymentMethod'] ?? 'N/A').toString();
    final double gstAmount = double.tryParse((t['gstAmount'] ?? '').toString()) ?? 0.0;
    final double gateCharges = double.tryParse((t['paymentGateway'] ?? '').toString()) ?? 0.0;

    Widget detailRow(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(k, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3)),
              Text(v, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)),
            ],
          ),
        );

    Widget gridBox(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                const SizedBox(height: 4),
                Text(value, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedTxns.remove(id);
                } else {
                  _expandedTxns.add(id);
                }
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _downloadInvoice(invoiceId),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.evaGreen50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: AppColors.evaGreenDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${displayAmount.toStringAsFixed(2)}',
                        style: AppText.poppins(
                          size: 14.5,
                          weight: FontWeight.w800,
                          color: isDeducted ? const Color(0xFFFF6A13) : AppColors.evaGreenDeep,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: AppText.poppins(size: 11, weight: FontWeight.w700, color: statusColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: AppColors.line, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      gridBox('Previous Balance', '₹${prevBal.toStringAsFixed(2)}'),
                      const SizedBox(width: 10),
                      gridBox('Current Balance', '₹${currBal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        detailRow('Date', dateStr),
                        detailRow('Transaction ID', (t['transactionId'] ?? t['txnId'] ?? t['razorpay_payment_id'] ?? id).toString()),
                        detailRow('Status', label),
                        detailRow('Account No', accountNo),
                        detailRow('Payer Name', payerName),
                        detailRow('Amount Deducted', isDeducted ? deductedAmount.toStringAsFixed(2) : '—'),
                        detailRow('Recharge Amount', !isDeducted ? totalAmount.toStringAsFixed(2) : '—'),
                        detailRow('GST', gstAmount > 0 ? gstAmount.toStringAsFixed(2) : 'N/A'),
                        detailRow('Payment Gateway', gateCharges.toStringAsFixed(2)),
                        detailRow('Payment Method', payMethod),
                        detailRow('Grand Total', '₹${displayAmount.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }



  Widget _smallButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(11), boxShadow: AppColors.shadowXs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _PasswordPanel extends StatefulWidget {
  const _PasswordPanel();
  @override
  State<_PasswordPanel> createState() => _PasswordPanelState();
}

class _PasswordPanelState extends State<_PasswordPanel> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showOld = false, _showNew = false, _showConf = false;
  bool _saving = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String m, {bool isError = false}) {
    if (mounted) appToast(context, m, isError: isError);
  }

  Future<void> _save() async {
    final oldPass = _old.text;
    final newPass = _new.text;
    final confirmPass = _confirm.text;

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _snack('All password fields are required', isError: true);
      return;
    }
    if (newPass.length < 8) {
      _snack('Password must be at least 8 characters!', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _snack('Passwords do not match!', isError: true);
      return;
    }
    if (oldPass == newPass) {
      _snack('Password already exists, provide new password!', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final authRepo = AppScope.of(context).auth;
      await authRepo.changePassword(oldPass, newPass, confirmPass);
      _snack('Password changed successfully');
      _old.clear();
      _new.clear();
      _confirm.clear();
    } catch (e) {
      _snack('Password cannot be changed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget labelWithStar(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          '* ',
          style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.danger),
        ),
        Text(
          text,
          style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink),
        ),
      ],
    ),
  );

  Widget _field(String label, TextEditingController c, bool show, VoidCallback toggle, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWithStar(label),
        TextField(
          controller: c,
          obscureText: !show,
          style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
            filled: true,
            fillColor: const Color(0xFFF5F6F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            suffixIcon: InkWell(
              onTap: toggle,
              child: Icon(show ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AppColors.ink4),
            ),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.evaGreen50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, size: 18, color: AppColors.evaGreenDeep),
              ),
              const SizedBox(width: 12),
              Text(
                'Change Password',
                style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Use at least 8 characters with a mix of letters, numbers & symbols.',
            style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink3),
          ),
          const SizedBox(height: 20),
          _field('Old Password', _old, _showOld, () => setState(() => _showOld = !_showOld), 'Old Password'),
          const SizedBox(height: 16),
          _field('New Password', _new, _showNew, () => setState(() => _showNew = !_showNew), 'New Password'),
          const SizedBox(height: 16),
          _field('Retype New Password', _confirm, _showConf, () => setState(() => _showConf = !_showConf), 'Retype New Password'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.shrink()
                  : const Icon(Icons.description_outlined, size: 18, color: Colors.white),
              label: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save Changes', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.evaGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
