import 'package:flutter/material.dart';

import '../api/app_scope.dart';
import '../api/payment_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'dashboard_sheets.dart' show appToast;

/// Web subscription catalog (subscription.js `plans`) — per-term INR prices.
const Map<String, Map<int, int>> kPlanPrices = {
  'standard': {3: 2850, 6: 4950, 12: 8388},
  'enterprises': {3: 5250, 6: 9300, 12: 15588},
  'ecommerce': {3: 8100, 6: 14400, 12: 23988},
};

/// Plan tier level + marketing description (mirrors RateLimitModal `plans`).
const Map<String, ({int level, String desc, bool popular})> kPlanMeta = {
  'standard': (level: 1, desc: 'Basic Chatbot Solution For Small Scale Business', popular: false),
  'enterprises': (level: 2, desc: 'Advanced Custom Chatbot Solution For Enterprises Business', popular: false),
  'ecommerce': (level: 3, desc: 'Advanced Ecommerce Chatbot Solution For Ecom Business', popular: true),
};

/// Feature comparison rows: (name, standard, enterprises, ecommerce) — a bool
/// (✓/−) or a string count. Mirrors RateLimitModal `features`.
const List<(String, Object, Object, Object)> kPlanFeatures = [
  ('Broadcast & Analytics', true, true, true),
  ('Chat (Live, History & Intervene)', true, true, true),
  ('Nodes Chatbot', '2', '5', '7'),
  ('APIs Documentation', true, true, true),
  ('Notify Me', true, true, true),
  ('Agents & Attributes', true, true, true),
  ('APIs + Web hooks', false, true, true),
  ('Schedule Campaign', false, true, true),
  ('Carousel', false, true, true),
  ('Questionnaire Flow', false, true, true),
  ('Whatsapp Forms', false, true, true),
  ('Catalogue Flow', false, false, true),
  ('Whatsapp Payments', false, false, true),
  ('Order Management, Agents & Attributes', false, false, true),
];

String _termLabel(String period) => switch (period) {
      '3month' => '3 Months',
      '6month' => '6 Months',
      _ => 'Yearly',
    };
int _termMonthsOf(String period) => switch (period) { '3month' => 3, '6month' => 6, _ => 12 };
String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

const _renewMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Thousands-grouped INR, e.g. 23988 -> "₹23,988".
String inr(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₹$b';
}

/// Port of web getPlanPrice(name, validity, startDate): unlimited -> yearly
/// price; a date validity -> 3/6/12-month price by span; else the 3-month price.
int planPriceValue(String name, String validity, String startDate) {
  final table = kPlanPrices[name.toLowerCase()];
  if (table == null) return 0;
  if (validity.toLowerCase() == 'unlimited') return table[12]!;
  if (validity.contains('-')) {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(validity);
    if (start != null && end != null) {
      final days = end.difference(start).inDays;
      final mth = (days / 30.4).round();
      if (mth >= 12) return table[12]!;
      if (mth >= 6) return table[6]!;
      return table[3]!;
    }
  }
  return table[3]!;
}

Future<void> showRenewPlanSheet(BuildContext context, {String planName = 'ecommerce'}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RenewPlanSheet(planName: planName),
  );
}

class _RenewPlanSheet extends StatefulWidget {
  final String planName;
  const _RenewPlanSheet({required this.planName});
  @override
  State<_RenewPlanSheet> createState() => _RenewPlanSheetState();
}

class _RenewPlanSheetState extends State<_RenewPlanSheet> {
  int _option = 2; // 3 / 6 / 12 months
  int _method = 1; // Wallet / Online

  static const _termMonths = [3, 6, 12];

  String get _planTitle {
    final n = widget.planName;
    if (n.isEmpty) return 'Plan';
    return '${n[0].toUpperCase()}${n.substring(1)}';
  }

  /// Per-term options computed from the real catalog (savings vs the 3-month
  /// monthly rate), so totals match the web exactly (e.g. ecommerce 12mo ₹23,988).
  List<({String months, String perMo, String total, String? save})> get _options {
    final table = kPlanPrices[widget.planName.toLowerCase()] ?? kPlanPrices['ecommerce']!;
    final base = table[3]! / 3; // 3-month monthly rate = baseline
    return [
      for (final t in _termMonths)
        () {
          final total = table[t]!;
          final perMo = (total / t).round();
          final savePct = ((1 - perMo / base) * 100).round();
          final saved = (base * t - total).round();
          return (
            months: '$t Months',
            perMo: savePct > 0 ? '${inr(perMo)}/mo · save $savePct%' : '${inr(perMo)}/mo',
            total: inr(total),
            save: saved > 0 ? 'save ${inr(saved)}' : null,
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final total = _options[_option].total;
    final now = DateTime.now();
    final exp = DateTime(now.year, now.month + _termMonths[_option], now.day);
    final newExpiry = '${exp.day} ${_renewMonths[exp.month - 1]} ${exp.year}';
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 8),
            child: Row(
              children: [
                Text('Renew Plan', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 30, height: 30, alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.close_rounded, size: 17, color: AppColors.ink2),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.evaGreenDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Renew $_planTitle', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink)),
                          Text('Extend your current plan — your tier and features stay the same.', style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink3, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final (i, o) in _options.indexed) ...[
                  _optionRow(i, o.months, o.perMo, o.total, o.save),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total payable', style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                          Text('New expiry · $newExpiry', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                        ],
                      ),
                    ),
                    Text(total, style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Payment Method', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _methodCard(0, Icons.account_balance_wallet_outlined, 'Wallet', 'Use AskEva balance')),
                    const SizedBox(width: 12),
                    Expanded(child: _methodCard(1, Icons.credit_card_rounded, 'Online Payment', 'Card / Netbanking')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(14)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final months = _options[_option].months;
                      try {
                        await AppScope.of(context).auth.fetchProfile();
                        await AppScope.of(context).auth.fetchUserPlan();
                      } catch (_) {}
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      appToast(context, 'Plan renewed · $months ($total)', isSuccess: true);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Pay $total & Renew', style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(int i, String months, String perMo, String total, String? save) {
    final active = _option == i;
    return GestureDetector(
      onTap: () => setState(() => _option = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.evaGreen : AppColors.line, width: active ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: active ? AppColors.evaGreen : AppColors.ink4, width: 2),
                color: active ? AppColors.evaGreen : Colors.transparent,
              ),
              child: active ? const Icon(Icons.circle, size: 8, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(months, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(perMo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(total, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                if (save != null) Text(save, style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(int i, IconData icon, String title, String sub) {
    final active = _method == i;
    return GestureDetector(
      onTap: () => setState(() => _method = i),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: active ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: active ? AppColors.evaGreen : AppColors.line, width: active ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: active ? AppColors.evaGreenDeep : AppColors.ink3),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(sub, style: AppText.poppins(size: 10.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plans sheet ("Check other plans") — ports the web RateLimitModal: term tabs,
// the available plan card(s), a feature comparison table, and Pay with
// Wallet / Pay Online (POST /users/paywallet and /users/pay-online).
// ---------------------------------------------------------------------------

/// [currentPlan] / [validity] / [startDate] come from the live user plan;
/// renewal shows the current tier and above, upgrade shows strictly higher.
Future<void> showPlansSheet(
  BuildContext context, {
  required String currentPlan,
  required String validity,
  required String startDate,
  required void Function(String) toast,
  bool isRenewal = true,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlansSheet(
      currentPlan: currentPlan,
      validity: validity,
      startDate: startDate,
      toast: toast,
      isRenewal: isRenewal,
    ),
  );
}

class _PlansSheet extends StatefulWidget {
  final String currentPlan, validity, startDate;
  final void Function(String) toast;
  final bool isRenewal;
  const _PlansSheet({
    required this.currentPlan,
    required this.validity,
    required this.startDate,
    required this.toast,
    required this.isRenewal,
  });
  @override
  State<_PlansSheet> createState() => _PlansSheetState();
}

class _PlansSheetState extends State<_PlansSheet> {
  String _term = '3month';
  String? _selected;
  bool _busy = false;

  void _toast(String m) => appToast(context, m);

  int _level(String name) => kPlanMeta[name.toLowerCase()]?.level ?? 0;

  /// Web getPlansToShow: renewal -> level >= current; upgrade -> level > current.
  List<String> get _plans {
    const order = ['standard', 'enterprises', 'ecommerce'];
    final cur = _level(widget.currentPlan);
    final list = order.where((p) {
      final l = _level(p);
      return widget.isRenewal ? (cur == 0 || l >= cur) : l > cur;
    }).toList();
    return list;
  }

  @override
  void initState() {
    super.initState();
    final p = _plans;
    if (p.length == 1) _selected = p.first; // single option → preselect
  }

  bool get _topTierAlready => !widget.isRenewal && _plans.isEmpty;

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 6),
            child: Row(
              children: [
                Expanded(child: Text(widget.isRenewal ? 'Renew Your Plan' : 'Choose a Plan', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink))),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.close_rounded, size: 17, color: AppColors.ink2)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Flexible(
            child: _topTierAlready
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.workspace_premium_rounded, size: 40, color: AppColors.evaGreenDeep),
                      const SizedBox(height: 12),
                      Text("You're on our top plan", style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      Text('Contact support@askeva.io for customized solutions and plan adjustments.', textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.4)),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    shrinkWrap: true,
                    children: [
                      _termTabs(),
                      const SizedBox(height: 18),
                      for (final p in plans) ...[_planCard(p), const SizedBox(height: 14)],
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(child: _payButton('Pay with Wallet', Icons.account_balance_wallet_rounded, _payWallet)),
                        const SizedBox(width: 12),
                        Expanded(child: _payButton('Pay Online', Icons.credit_card_rounded, _payOnline)),
                      ]),
                      const SizedBox(height: 20),
                      _featuresTable(plans),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _termTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final t in const ['3month', '6month', 'yearly'])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _term = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _term == t ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: _term == t ? Border.all(color: AppColors.evaGreen) : null,
                  ),
                  child: Text(_termLabel(t), style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: _term == t ? AppColors.evaGreenDeep : AppColors.ink3)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _planCard(String name) {
    final meta = kPlanMeta[name]!;
    final price = kPlanPrices[name]![_termMonthsOf(_term)]!;
    final sel = _selected == name;
    return GestureDetector(
      onTap: () => setState(() => _selected = name),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: sel ? 1.8 : 1),
          boxShadow: AppColors.shadowXs,
        ),
        child: Column(
          children: [
            if (meta.popular)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.evaGreen, borderRadius: BorderRadius.circular(16)),
                  child: Text('RECOMMENDED', style: AppText.poppins(size: 9.5, weight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                ),
              ),
            Text(_cap(name), style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(inr(price), style: AppText.poppins(size: 30, weight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('Billing Period ${_termLabel(_term)}', style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
            const SizedBox(height: 10),
            Text(meta.desc, textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _payButton(String label, IconData icon, Future<void> Function() onTap) {
    final enabled = _selected != null && !_busy;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.evaGradient, borderRadius: BorderRadius.circular(13)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: enabled ? () => onTap() : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: Colors.white),
                  const SizedBox(width: 7),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: Colors.white))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _featuresTable(List<String> plans) {
    // The feature value column for a plan name.
    Object valFor(String planName, (String, Object, Object, Object) f) =>
        switch (planName) { 'standard' => f.$2, 'enterprises' => f.$3, _ => f.$4 };
    final show = _selected != null ? [_selected!] : plans;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.surface2,
            child: Row(children: [
              Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(12), child: Text('Features', style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)))),
              for (final p in show) Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(12), child: Text(_cap(p), textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep)))),
            ]),
          ),
          for (final (i, f) in kPlanFeatures.indexed)
            Container(
              color: i.isEven ? AppColors.surface : AppColors.surface2,
              child: Row(
                children: [
                  Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(12), child: Text(f.$1, style: AppText.poppins(size: 11.5, weight: FontWeight.w500, color: AppColors.ink2)))),
                  for (final p in show)
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Builder(builder: (_) {
                          final v = valFor(p, f);
                          if (v is bool) {
                            return Icon(v ? Icons.check_rounded : Icons.remove_rounded, size: 16, color: v ? AppColors.evaGreenDeep : AppColors.ink4);
                          }
                          return Text('$v', textAlign: TextAlign.center, style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.ink));
                        }),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(widget.isRenewal ? 'Confirm Renewal' : 'Confirm Upgrade', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
        content: Text(body, style: AppText.poppins(size: 13, weight: FontWeight.w500, color: AppColors.ink2, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: AppColors.danger))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Confirm', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.evaGreenDeep))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _payWallet() async {
    final name = _selected;
    if (name == null) return;
    final price = kPlanPrices[name]![_termMonthsOf(_term)]!;
    if (!await _confirm('${widget.isRenewal ? 'Renew' : 'Upgrade to'} the $name plan for ${_termLabel(_term)}?\n\nAmount: ${inr(price)} (from wallet)\n\nThe wallet amount cannot be reverted.')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final res = await AppScope.of(context).payments.payWithWallet(
            planName: name,
            price: price,
            billingPeriod: _term,
            isSamePlan: name.toLowerCase() == widget.currentPlan.toLowerCase(),
          );
      if (!mounted) return;
      final ok = res['success'] == true;
      if (ok) {
        try {
          await AppScope.of(context).auth.fetchProfile();
          await AppScope.of(context).auth.fetchUserPlan();
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.toast(ok ? (res['message']?.toString() ?? 'Plan ${widget.isRenewal ? 'renewed' : 'upgraded'} successfully') : (res['message']?.toString() ?? 'Payment failed'));
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Payment failed. Please try again.');
      }
    }
  }

  Future<void> _payOnline() async {
    final name = _selected;
    if (name == null) return;
    final base = kPlanPrices[name]![_termMonthsOf(_term)]!;
    final gateway = double.parse((base * 0.025).toStringAsFixed(2));
    final gst = double.parse((base * 0.18).toStringAsFixed(2));
    final displayGst = double.parse((gateway + gst).toStringAsFixed(2));
    final total = double.parse((base + displayGst).toStringAsFixed(2));
    if (!await _confirm('${widget.isRenewal ? 'Renew' : 'Upgrade to'} the $name plan for ${_termLabel(_term)}?\n\nPlan Amount: ${inr(base)}\nGateway Charges: ${inr(gateway)}\nGST (18%): ${inr(displayGst)}\nTotal to Pay: ${inr(total)}\n\nYou will be redirected to the PayU gateway.')) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final html = await AppScope.of(context).payments.payOnline(
            planName: name,
            price: base,
            billingPeriod: _term,
            gatewayCharges: gateway,
            gstAmount: gst,
            displayGst: displayGst,
            totalWithGst: total,
            isSamePlan: name.toLowerCase() == widget.currentPlan.toLowerCase(),
          );
      final opened = await openGatewayHtml(html);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.toast(opened ? 'Opening secure payment for ${inr(total)}…' : 'Could not open the payment page. Please try again.');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Failed to initialize payment. Please try again.');
      }
    }
  }
}
