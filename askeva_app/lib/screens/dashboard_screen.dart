import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/app_scope.dart';
import '../api/auth_repository.dart';
import 'notification_settings_screen.dart';
import 'profile_screen.dart';
import '../shell/app_nav.dart';
import '../shell/app_sidebar.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/common.dart';
import '../widgets/dashboard_sheets.dart';
import '../widgets/date_range_sheet.dart';
import '../widgets/trend_chart.dart';

/// Live wallet balance, shared so the Add Fund flow can bump it on success.
final ValueNotifier<double> kWalletBalance = ValueNotifier<double>(0);

/// Messaging-tier daily message limit (mirrors the web `calculateTierLimit`).
/// Returns null for the unlimited tier_4.
int? tierMsgLimit(String tier) {
  switch (tier) {
    case 'tier_0':
      return 250;
    case 'tier_1':
      return 1000;
    case 'tier_2':
      return 10000;
    case 'tier_3':
      return 100000;
    case 'tier_4':
      return null;
  }
  return 100000;
}

/// The main "Dashboard" (`#app-home`): WABA account status, wallet balance,
/// message-limit gauge + plan, conversation totals, and broadcast / API
/// message summaries with trend charts. Mirrors the AskEva design 1:1.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _refreshId = 0;
  Timer? _notificationPollTimer;
  final Set<String> _seenNotificationIds = {};
  bool _isFirstPoll = true;
  UserPlan? _userPlan;

  @override
  void initState() {
    super.initState();
    _fetchInitialUnread();
    _startNotificationPolling();
  }

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollNotifications());
  }

  Future<void> _pollNotifications() async {
    if (!mounted) return;
    try {
      final s = AppScope.of(context);
      final unreadList = await s.notifications.fetchNotifications(isRead: false, limit: 20);
      final count = await s.notifications.fetchUnreadCount();
      if (!mounted) return;

      kNotificationUnreadCount.value = count;

      if (_isFirstPoll) {
        _isFirstPoll = false;
        try {
          final prefs = await SharedPreferences.getInstance();
          final stored = prefs.getStringList('seen_notification_ids') ?? [];
          _seenNotificationIds.addAll(stored);
        } catch (_) {}

        for (final n in unreadList) {
          _seenNotificationIds.add(n.id);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('seen_notification_ids', _seenNotificationIds.toList());
        } catch (_) {}
        return;
      }

      bool newSeen = false;
      for (final n in unreadList) {
        if (!_seenNotificationIds.contains(n.id)) {
          _seenNotificationIds.add(n.id);
          newSeen = true;
          dispatchNotificationAlert(
            context,
            title: n.title.isNotEmpty ? n.title : 'New Notification',
            message: n.body,
          );
        }
      }

      if (newSeen) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('seen_notification_ids', _seenNotificationIds.toList());
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialUnread() async {
    try {
      final s = AppScope.of(context);
      final count = await s.notifications.fetchUnreadCount();
      kNotificationUnreadCount.value = count;

      await refreshUnreadChatsCount(context);

      final leadsPage = await s.leads.fetchLeads(limit: 1);
      kTotalLeadsCount.value = leadsPage.total;
    } catch (_) {}
  }

  Future<void> _handleRefresh() async {
    try {
      final s = AppScope.of(context);
      await s.auth.fetchProfile();
      await _loadUserPlan();
      await _fetchInitialUnread();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _refreshId++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = AppNav.of(context);
    final session = AppScope.sessionOf(context);
    final name = session.username ?? 'there';
    final p = session.profile ?? const <String, dynamic>{};
    return GreenHeaderScaffold(
      title: 'Dashboard',
      onMenu: nav.openDrawer,
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GlassIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onTap: () => showNotificationsPanel(context),
            ),
            ValueListenableBuilder<int>(
              valueListenable: kNotificationUnreadCount,
              builder: (context, count, _) {
                if (count == 0) return const SizedBox.shrink();
                return Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text('$count', style: AppText.poppins(size: 10, weight: FontWeight.w800, color: Colors.white)),
                  ),
                );
              },
            ),
          ],
        ),
        //const SizedBox(width:2),
        const DashboardProfileAvatar(),
      ],
      sheet: RefreshIndicator(
        color: AppColors.evaGreenDeep,
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            _wabaCard(p),
            const SizedBox(height: 10),
            _balance(context, name, nav),
            const SizedBox(height: 10),
            _greenRow(context, nav, p),
            const SizedBox(height: 10),
            _TotalConversationCard(key: ValueKey('total_conv_$_refreshId')),
            const SizedBox(height: 10),
            _SummaryCard(
              key: ValueKey('broadcast_$_refreshId'),
              title: 'Overview Summary of Broadcast Message',
              isApi: false,
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              key: ValueKey('api_$_refreshId'),
              title: 'Overview Summary of API Message',
              isApi: true,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- WABA account status ----------------
  Widget _wabaCard(Map<String, dynamic> p) {
    final waba = (p['business_whatsapp'] ?? p['businessWhatsapp'] ?? p['wabaNumber'] ?? p['phone'] ?? '').toString();
    final isLive = (p['connectionStatus'] ?? p['connection_status'] ?? 'active').toString().toLowerCase() == 'active';
    final quality = (p['qualityRating'] ?? 'GREEN').toString();
    final qualityLabel = quality.isEmpty ? 'Green' : '${quality[0].toUpperCase()}${quality.substring(1).toLowerCase()}';
    final isGreen = quality.toUpperCase() == 'GREEN';
    final tier = (p['tier'] ?? 'tier_3').toString();
    final limit = tierMsgLimit(tier);
    final tierText = limit == null ? '$tier: UNLIMITED' : '$tier: MSG_$limit LIMIT';
    Widget item(IconData icon, String k, Widget v, {required bool right, required bool bottom}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 17),
        decoration: BoxDecoration(
          border: Border(
            right: right ? const BorderSide(color: AppColors.line) : BorderSide.none,
            bottom: bottom ? const BorderSide(color: AppColors.line) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.evaGreenDeep),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k, style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3)),
                  const SizedBox(height: 4),
                  v,
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget val(String text, {Color? dot, bool live = false, int maxLines = 1}) {
      return Row(
        children: [
          if (dot != null) ...[
            _Dot(color: dot, live: live),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
              style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: item(Icons.workspace_premium_outlined, 'WABA Number', val(waba), right: true, bottom: true)),
                Expanded(child: item(Icons.power_settings_new_rounded, 'Status', val(isLive ? 'Live' : 'Offline'), right: false, bottom: true)),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: item(Icons.flag_rounded, 'Quality Rating', val(qualityLabel, dot: isGreen ? AppColors.evaGreen : AppColors.warning, live: true), right: true, bottom: false)),
                Expanded(child: item(Icons.forum_rounded, 'Messaging Tier', val(tierText, maxLines: 2), right: false, bottom: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- balance / greeting ----------------
  Widget _balance(BuildContext context, String name, AppNav nav) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadowXs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $name!', style: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink3)),
                const SizedBox(height: 8),
                _BalanceText(key: ValueKey('bal_$_refreshId')),
              ],
            ),
          ),
          Material(
            color: AppColors.evaGreen,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showAddFundSheet(
                context,
                onCredit: (amt) => kWalletBalance.value = kWalletBalance.value + amt,
                toast: nav.toast,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                child: Text('Add Fund', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greenRow(BuildContext context, AppNav nav, Map<String, dynamic> p) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _MessageLimitCard(key: ValueKey('limit_$_refreshId'))),
          const SizedBox(width: 13),
          Expanded(child: _planCard(context, nav, p)),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchInitialUnread();
    _loadUserPlan();
    AppScope.of(context).auth.fetchProfile().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _loadUserPlan() async {
    try {
      final plan = await AppScope.of(context).auth.fetchUserPlan();
      if (mounted) {
        setState(() {
          _userPlan = plan;
        });
      }
    } catch (_) {}
  }

  Widget _planCard(BuildContext context, AppNav nav, Map<String, dynamic> p) {
    final profilePlan = (p['plan'] is Map) ? (p['plan'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final rawName = (_userPlan?.name ?? profilePlan['name'] ?? 'ecommerce').toString();
    final planName = rawName.toUpperCase();
    final rawValidity = (_userPlan?.validity ?? profilePlan['validity'] ?? '').toString();
    final isUnlimited = rawValidity.toLowerCase() == 'unlimited' ||
        rawName.toLowerCase().contains('unlimited');
    String formattedValidity = rawValidity;
    if (rawValidity.isNotEmpty && !rawValidity.contains('/')) {
      final dt = DateTime.tryParse(rawValidity);
      if (dt != null) {
        final dayStr = dt.day.toString().padLeft(2, '0');
        final monthStr = dt.month.toString().padLeft(2, '0');
        formattedValidity = '$dayStr/$monthStr/${dt.year}';
      }
    }
    final validText = isUnlimited
        ? 'Validity: Unlimited'
        : (formattedValidity.isNotEmpty ? 'Valid until: $formattedValidity' : 'Valid until: —');
    return _greenSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Plan', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 11),
          Text(planName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 19, weight: FontWeight.w700, color: Colors.white, letterSpacing: -0.2)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              validText,
              maxLines: 1,
              style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
          const Spacer(),
          Material(
            color: isUnlimited ? Colors.white.withValues(alpha: 0.45) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isUnlimited
                  ? null
                  : () async {
                      kProfileInitialTab = ProfileTab.subscription;
                      nav.goTo(AppRoute.profile);
                      if (mounted) {
                        try {
                          await AppScope.of(context).auth.fetchProfile();
                          setState(() {});
                        } catch (_) {}
                      }
                    },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  'Renew Now',
                  style: AppText.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: isUnlimited
                        ? AppColors.evaGreenDeep.withValues(alpha: 0.5)
                        : AppColors.evaGreenDeep,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Green gradient surface shared by the Message Limit + Current Plan cards.
Widget _greenSurface({required Widget child}) {
  return Container(
    constraints: const BoxConstraints(minHeight: 172),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.evaGradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Color(0x8C177A36), blurRadius: 24, offset: Offset(0, 10), spreadRadius: -16)],
    ),
    child: child,
  );
}

/// Message Limit gauge — today's business-initiated conversation count vs the
/// account's messaging-tier limit. Loads GET /v1/users/totalConversations/0
/// (today) and reads the tier from the login profile, mirroring the web
/// TotalStatus card (calculatePercentage(todaysTotal, tierLimit)).
class _MessageLimitCard extends StatefulWidget {
  const _MessageLimitCard({super.key});
  @override
  State<_MessageLimitCard> createState() => _MessageLimitCardState();
}

class _MessageLimitCardState extends State<_MessageLimitCard> with AutomaticKeepAliveClientMixin {
  int? _todayTotal;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await AppScope.of(context).auth.fetchTotalConversation(filter: '0');
      if (!mounted || m.isEmpty) return;
      final v = m['business'] ?? m['total'];
      final n = (v is num) ? v.toInt() : int.tryParse('$v');
      if (n != null) setState(() => _todayTotal = n);
    } catch (_) {/* keep placeholder */}
  }

  /// Mirrors web calculatePercentage: 1-decimal rounding, a non-zero value that
  /// rounds to 0 shows as 0.1, capped at 100.
  double _percent(int current, int total) {
    if (current <= 0 || total <= 0) return 0;
    final pct = (current / total) * 100;
    final rounded = (pct * 10).round() / 10;
    if (rounded == 0 && pct > 0) return 0.1;
    return rounded > 100 ? 100 : rounded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tier = (AppScope.sessionOf(context).profile?['tier'] ?? 'tier_3').toString();
    final limit = tierMsgLimit(tier);
    final today = _todayTotal ?? 0;
    final pct = limit == null ? 0.0 : _percent(today, limit);
    final limitLabel = limit == null ? 'Unlimited' : '$limit';
    return _greenSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Message Limit', style: AppText.poppins(size: 13, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.92))),
          const SizedBox(height: 8),
          Center(child: SemiGauge(percent: pct / 100, centerLabel: '$pct%')),
          const Spacer(),
          Center(
            child: Text('$today out of $limitLabel',
                style: AppText.poppins(size: 12, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }
}

/// White card with a header row (title + optional [action]) — `.d2-card .hm-cardhd`.
Widget _dashCard({required String title, required Widget child, Widget? action}) {
  return Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.line),
      boxShadow: AppColors.shadowXs,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(title, style: AppText.poppins(size: 16, weight: FontWeight.w600, color: AppColors.ink, height: 1.35, letterSpacing: -0.16))),
            action ?? const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink4),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

/// Broadcast / API summary card, wired to the live chart endpoints
/// (GET /v1/users/broadcastChart | /apiBroadcastChart?startDate=&endDate=).
/// The 3-dot menu (Today / Last 7 days / Last 28 days) and the date-range
/// pill both change the queried window and refetch; the stat pills show the
/// summed Sent/Delivered/Read, the chart and axis the per-day series.
class _SummaryCard extends StatefulWidget {
  final String title;
  final bool isApi; // false = broadcast, true = API message
  const _SummaryCard({super.key, required this.title, required this.isApi});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> with AutomaticKeepAliveClientMixin {
  static const _periods = ['Today', 'Last 7 days', 'Last 28 days'];

  // Default to "Last 7 days" to match the web dashboard (StatisticsStatus.jsx
  // defaults dateBroad/dateApi to "7"). Defaulting to "Today" slices to a single
  // day that often has no data yet, so the card looked empty until the user
  // changed the period.
  String _period = 'Last 7 days';
  DateTimeRange? _range;
  MessageChart? _all; // every bucket; the displayed view is sliced in build
  String? _error; // surfaced when the fetch fails (e.g. 401 / no network)

  bool _loaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope is an inherited widget, so resolve it here (not in initState).
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  // The dataset is dated independently of the phone, so query a wide window
  // once and treat the latest data day as "today" — periods then work no matter
  // what the device clock says.
  Future<void> _load() async {
    try {
      final auth = AppScope.of(context).auth;
      final data = widget.isApi
          ? await auth.fetchApiBroadcastChart(startDate: '2000-01-01', endDate: '2100-01-01')
          : await auth.fetchBroadcastChart(startDate: '2000-01-01', endDate: '2100-01-01');
      if (mounted) setState(() { _all = data; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// The chart limited to the selected period, relative to the latest data day.
  MessageChart? _sliced() {
    final all = _all;
    if (all == null) return null;
    final ref = all.latest ?? DateTime.now();
    DateTime from, to;
    if (_range != null) {
      from = _range!.start;
      to = _range!.end;
    } else {
      to = ref;
      final days = _period == 'Today'
          ? 0
          : _period == 'Last 28 days'
              ? 28
              : 7;
      from = ref.subtract(Duration(days: days));
    }
    return all.slice(
      DateTime(from.year, from.month, from.day),
      DateTime(to.year, to.month, to.day, 23, 59, 59),
    );
  }



  String _reportLabel() {
    if (_range != null) {
      final s = _range!.start, e = _range!.end;
      const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final txt = '${s.day} ${m[s.month - 1]}${e != s ? ' – ${e.day} ${m[e.month - 1]}' : ''}';
      return '$txt\nReport';
    }
    return '$_period\nReport';
  }

  String _fmt(num n) {
    final s = (n.round()).toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Future<void> _pickRange() async {
    // Bound the picker to the data's own date range (the device clock may not
    // match the dataset), falling back to a wide window before any data loads.
    final all = _all;
    final last = all?.latest ?? DateTime.now();
    final first = (all != null && all.dates.isNotEmpty)
        ? all.dates.reduce((a, b) => a.isBefore(b) ? a : b)
        : DateTime(last.year - 2);
    final r = await showAppDateRangePicker(
      context,
      initialRange: _range,
      firstDate: first,
      lastDate: last,
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final d = _sliced();
    return _dashCard(
      title: widget.title,
      action: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink4),
        position: PopupMenuPosition.under,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (p) {
          // Sliced client-side from the already-loaded data — no refetch.
          setState(() {
            _period = p;
            _range = null;
          });
        },
        itemBuilder: (_) => [
          for (final p in _periods)
            PopupMenuItem(
              value: p,
              child: Row(
                children: [
                  Expanded(child: Text(p, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink))),
                  if (p == _period && _range == null) const Icon(Icons.check_rounded, size: 16, color: AppColors.evaGreenDeep),
                ],
              ),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill(Icons.check_rounded, _fmt(d?.sent ?? 0), 'Sent'),
              _pill(Icons.done_all_rounded, _fmt(d?.delivered ?? 0), 'Delivered'),
              _pill(Icons.visibility_outlined, _fmt(d?.read ?? 0), 'Read'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text(_reportLabel(), style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink))),
              GestureDetector(
                onTap: _pickRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.evaGreen200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_range == null ? 'Start date → End date' : _reportLabel().replaceAll('\nReport', ''),
                          style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3)),
                      const SizedBox(width: 6),
                      if (_range == null)
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.evaGreenDeep)
                      else
                        GestureDetector(
                          onTap: () => setState(() => _range = null),
                          child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _legend(const Color(0xFF177A36), 'Sent'),
              const SizedBox(width: 15),
              _legend(const Color(0xFF3CC23F), 'Delivered'),
              const SizedBox(width: 15),
              _legend(const Color(0xFF85D653), 'Read'),
            ],
          ),
          const SizedBox(height: 6),
          if (_all == null && _error != null)
            SizedBox(
              height: 150,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _error!.contains('expired') || _error!.contains('401')
                        ? 'Session expired — please sign out and sign in again.'
                        : "Couldn't load data: $_error",
                    textAlign: TextAlign.center,
                    style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.danger),
                  ),
                ),
              ),
            )
          else if (_all == null)
            const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: AppColors.evaGreen)))
          else
            TrendChart(
              series: trendSeriesFromData(
                sent: d?.sentDaily ?? const <int>[],
                delivered: d?.deliveredDaily ?? const <int>[],
                read: d?.readDaily ?? const <int>[],
              ),
              dates: d?.dates
                  .map((dt) => dt.year > 2000
                      ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
                      : '')
                  .toList(),
              sentValues: d?.sentDaily,
              deliveredValues: d?.deliveredDaily,
              readValues: d?.readDaily,
              labels: d?.labels,
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String n, String k) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 33,
            height: 33,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: AppColors.ink4),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 18, weight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.36)),
                const SizedBox(height: 2),
                Text(k, style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink3)),
      ],
    );
  }
}

/// Total Conversation — loads from GET /v1/users/totalConversations/3 (All),
/// falling back to the design's placeholder figures.
class _TotalConversationCard extends StatefulWidget {
  const _TotalConversationCard({super.key});
  @override
  State<_TotalConversationCard> createState() => _TotalConversationCardState();
}

class _TotalConversationCardState extends State<_TotalConversationCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // (label, filter key) — mirrors the web TotalStatus dropdown.
  static const _periods = [
    ('Today', '0'),
    ('Last 7 Days', '1'),
    ('Last 28 Days', '2'),
    ('All', '3'),
  ];

  String _filter = '3'; // All

  // (value, label, emphasised)
  List<(String, String, bool)> _stats = const [
    ('5,644', 'Marketing', false),
    ('278', 'Authentication', false),
    ('5,638', 'Utility', false),
    ('939', 'User initiated', false),
    ('11,560', 'Business initiated', false),
    ('12,499', 'Total', true),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _fmt(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  num _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      final p = num.tryParse('$v');
      if (p != null) return p;
    }
    return 0;
  }

  Future<void> _load() async {
    try {
      final m = await AppScope.of(context).auth.fetchTotalConversation(filter: _filter);
      if (!mounted || m.isEmpty) return;
      final marketing = _pick(m, ['marketing', 'marketingCount']);
      final auth = _pick(m, ['authentication', 'auth', 'authenticationCount']);
      final utility = _pick(m, ['utility', 'utilityCount']);
      final userInit = _pick(m, ['user', 'userInitiated', 'user_initiated', 'userInitiatedCount']);
      final bizInit = _pick(m, ['business', 'businessInitiated', 'business_initiated', 'businessInitiatedCount']);
      final total = _pick(m, ['total', 'totalConversation', 'totalCount']);
      final totalVal = total > 0 ? total : (marketing + auth + utility);
      setState(() {
        _stats = [
          (_fmt(marketing), 'Marketing', false),
          (_fmt(auth), 'Authentication', false),
          (_fmt(utility), 'Utility', false),
          (_fmt(userInit), 'User initiated', false),
          (_fmt(bizInit), 'Business initiated', false),
          (_fmt(totalVal), 'Total', true),
        ];
      });
    } catch (_) {/* keep fallback */}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _dashCard(
      title: 'Total Conversation',
      action: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.ink4),
        position: PopupMenuPosition.under,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (f) {
          if (f == _filter) return;
          setState(() => _filter = f);
          _load();
        },
        itemBuilder: (_) => [
          for (final p in _periods)
            PopupMenuItem(
              value: p.$2,
              child: Row(
                children: [
                  Expanded(child: Text(p.$1, style: AppText.poppins(size: 13.5, weight: FontWeight.w600, color: AppColors.ink))),
                  if (p.$2 == _filter) const Icon(Icons.check_rounded, size: 16, color: AppColors.evaGreenDeep),
                ],
              ),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _statItem(_stats[0])),
              const SizedBox(width: 12),
              Expanded(child: _statItem(_stats[1])),
              const SizedBox(width: 12),
              Expanded(child: _statItem(_stats[2])),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _statItem(_stats[3])),
              const SizedBox(width: 12),
              Expanded(child: _statItem(_stats[4])),
              const SizedBox(width: 12),
              Expanded(child: _statItem(_stats[5])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem((String, String, bool) s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.$1,
          style: AppText.poppins(
            size: 22,
            weight: FontWeight.w700,
            color: s.$3 ? AppColors.evaGreenDeep : AppColors.ink,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          s.$2,
          style: AppText.poppins(
            size: 11.5,
            weight: FontWeight.w500,
            color: AppColors.ink3,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

/// Wallet balance — loads from GET /v1/users/getUserBalance, falling back to
/// the design's placeholder until the live value arrives.
class _BalanceText extends StatefulWidget {
  const _BalanceText({super.key});
  @override
  State<_BalanceText> createState() => _BalanceTextState();
}

class _BalanceTextState extends State<_BalanceText> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bal = await AppScope.of(context).auth.fetchBalance();
      if (mounted && bal != null) kWalletBalance.value = bal;
    } catch (_) {/* keep current value */}
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: kWalletBalance,
      builder: (_, bal, _) => Text('INR ${bal.toStringAsFixed(2)}',
          style: AppText.poppins(size: 30, weight: FontWeight.w700, color: AppColors.ink, letterSpacing: -0.6)),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final bool live;
  const _Dot({required this.color, this.live = false});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.live) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (widget.live && !old.live) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.live && old.live) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.live) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _anim.value * 0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular profile avatar button displayed exclusively on the Dashboard header.
/// Fits the user's profile image edge-to-edge (BoxFit.cover) with no empty space.
class DashboardProfileAvatar extends StatelessWidget {
  const DashboardProfileAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.sessionOf(context);
    final profile = session.profile;
    final imgUrlRaw = (profile?['profile_picture_url'] ?? profile?['whatsAppDisplayImage'])?.toString().trim();
    final isLogoUrl = imgUrlRaw != null && (imgUrlRaw.toLowerCase().contains('askeva') || imgUrlRaw.toLowerCase().contains('logo'));
    final imgUrl = (imgUrlRaw != null && imgUrlRaw.isNotEmpty && imgUrlRaw.startsWith('http') && !isLogoUrl) ? imgUrlRaw : null;
    final userName = (profile?['name'] ?? profile?['username'] ?? session.username ?? '').toString();
    final initials = userName.isNotEmpty
        ? userName.trim().split(' ').where((s) => s.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join()
        : 'U';

    return Tooltip(
      message: 'Profile',
      child: GestureDetector(
        onTap: () => AppNav.of(context).goTo(AppRoute.profile),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.evaGreenDeep,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: imgUrl != null
              ? Image.network(
                  imgUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.evaGreenDeep,
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                )
              : Container(
                  color: AppColors.evaGreenDeep,
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white),
                  ),
                ),
        ),
      ),
    );
  }
}

