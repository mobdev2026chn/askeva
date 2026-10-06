import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/detail_screens.dart';
import '../screens/lead_detail_screen.dart';
import '../screens/catalog_orders_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../shell/app_nav.dart';

import '../api/app_scope.dart';
import '../api/dto.dart';
import '../api/payment_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'date_range_sheet.dart';

/// Shared rounded modal bottom-sheet shell with a grab handle.
Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
      final navBarPadding = MediaQuery.of(sheetContext).padding.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, navBarPadding > 0 ? 12.0 : 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 12),
                  Flexible(child: child),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

final ValueNotifier<int> kNotificationUnreadCount = ValueNotifier<int>(0);

/// Shows a top-sliding white card notification banner (matches the reference design).
/// [icon] defaults to info. Pass [isError]=true for red tint, [isSuccess]=true for green.
void appToast(BuildContext context, String msg, {
  IconData? icon,
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(milliseconds: 3000),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopBanner(
      message: msg,
      icon: icon ?? (isError ? Icons.error_outline_rounded : isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded),
      iconColor: isError ? const Color(0xFFEF5350) : isSuccess ? AppColors.evaGreenDeep : AppColors.info,
      iconBg: isError ? const Color(0xFFEF5350) : isSuccess ? AppColors.evaGreen : AppColors.info,
      duration: duration,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// Self-animating top banner widget used by [appToast].
class _TopBanner extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 8,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.4), end: Offset.zero).animate(_anim),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.iconBg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 22, color: widget.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _dismiss,
                  child: const Icon(Icons.close_rounded, size: 20, color: AppColors.ink3),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}


Widget _sheetHeader(BuildContext context, {required IconData icon, required String title, Widget? leading}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
    child: Row(
      children: [
        ?leading,
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: AppColors.evaGreenDeep),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(title, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink))),
        _CloseButton(onTap: () => Navigator.of(context).maybePop()),
      ],
    ),
  );
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink2),
      ),
    );
  }
}

Widget _fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 7, top: 14),
      child: Text(text, style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
    );

Widget _boxInput({
  String? hint,
  Widget? trailing,
  TextEditingController? controller,
  TextInputType? keyboard,
  bool readOnly = false,
  VoidCallback? onTap,
  List<TextInputFormatter>? formatters,
  bool obscure = false,
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboard,
    readOnly: readOnly,
    onTap: onTap,
    obscureText: obscure,
    inputFormatters: formatters,
    onChanged: onChanged,
    style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: AppColors.ink),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: AppText.poppins(size: 14, weight: FontWeight.w500, color: AppColors.ink4),
      suffixIcon: trailing,
      filled: true,
      fillColor: AppColors.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.evaGreen, width: 1.5)),
    ),
  );
}

/// A tappable dropdown-style box backed by a popup menu of [options].
Widget _selectBox<T>({
  required T? value,
  required String placeholder,
  required List<(T, String)> options,
  required ValueChanged<T> onChanged,
}) {
  return Builder(builder: (context) {
    final label = value == null ? placeholder : options.firstWhere((o) => o.$1 == value).$2;
    return PopupMenuButton<T>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o.$1, child: Text(o.$2))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppText.poppins(size: 14.5, weight: FontWeight.w600, color: value == null ? AppColors.ink4 : AppColors.ink))),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.ink3),
          ],
        ),
      ),
    );
  });
}

Widget _primaryBar(BuildContext context, String label, {IconData? icon, VoidCallback? onTap}) {
  return Padding(
    padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
    child: SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.evaGradient,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Color(0x4D3DC838), blurRadius: 16, offset: Offset(0, 7))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap ?? () => Navigator.of(context).maybePop(),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19, color: Colors.white), const SizedBox(width: 8)],
                  Text(label, style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Formatting helpers (mirror home-dashboard.js `inr`)
// ---------------------------------------------------------------------------

String _grp(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  // Indian grouping (en-IN): last 3 then groups of 2.
  final rev = s.split('').reversed.toList();
  for (var i = 0; i < rev.length; i++) {
    if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) b.write(',');
    b.write(rev[i]);
  }
  return (n < 0 ? '-' : '') + b.toString().split('').reversed.join();
}

String _inr(num v, {bool dec = false}) => dec ? '₹ ${v.toStringAsFixed(2)}' : '₹ ${_grp(v)}';

const double _kMinRecharge = 3000;

// ---------------------------------------------------------------------------
// Processing -> success overlay (mirrors home-dashboard.js `runSuccess`)
// ---------------------------------------------------------------------------

Future<void> runPaymentSuccess(
  BuildContext context, {
  required String procT,
  required String procS,
  required String okT,
  required String okS,
  required String toastMsg,
  required void Function(String) toast,
  VoidCallback? onSucceed,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x99000000),
    builder: (_) => _SuccessOverlay(
      procT: procT, procS: procS, okT: okT, okS: okS, onSucceed: onSucceed,
    ),
  );
  toast(toastMsg);
}

class _SuccessOverlay extends StatefulWidget {
  final String procT, procS, okT, okS;
  final VoidCallback? onSucceed;
  const _SuccessOverlay({required this.procT, required this.procS, required this.okT, required this.okS, this.onSucceed});
  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      setState(() => _done = true);
      widget.onSucceed?.call();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22), boxShadow: AppColors.shadowMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_done)
              const SizedBox(width: 52, height: 52, child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.evaGreen))
            else
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.evaGreen, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 32, color: Colors.white),
              ),
            const SizedBox(height: 18),
            Text(_done ? widget.okT : widget.procT,
                textAlign: TextAlign.center, style: AppText.poppins(size: 16.5, weight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(_done ? widget.okS : widget.procS,
                textAlign: TextAlign.center, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: AppColors.ink3, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Fund
// ---------------------------------------------------------------------------

enum _PayKind { online, bank }

/// [onCredit] is called with the amount credited to the wallet on success;
/// [toast] surfaces feedback that must outlive the sheet.
Future<void> showAddFundSheet(
  BuildContext context, {
  required void Function(double credited) onCredit,
  required void Function(String) toast,
}) =>
    showAppSheet(context, _AddFundSheet(onCredit: onCredit, toast: toast));

class _AddFundSheet extends StatefulWidget {
  final void Function(double) onCredit;
  final void Function(String) toast;
  const _AddFundSheet({required this.onCredit, required this.toast});
  @override
  State<_AddFundSheet> createState() => _AddFundSheetState();
}

class _AddFundSheetState extends State<_AddFundSheet> {
  _PayKind _kind = _PayKind.online;
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  String? _payMode;
  String? _account;
  DateTime? _challanDate;
  List<int>? _challanBytes;
  String? _challanName;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  double get _amt => double.tryParse(_amount.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(context, icon: Icons.account_balance_wallet_outlined, title: 'Add Fund'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Type of payment'),
                _selectBox<_PayKind>(
                  value: _kind,
                  placeholder: '',
                  options: const [
                    (_PayKind.online, 'Online Payment - UPI, Cards, NetBanking'),
                    (_PayKind.bank, 'Bank Transaction'),
                  ],
                  onChanged: (k) => setState(() => _kind = k),
                ),
                _fieldLabel('Amount'),
                _boxInput(
                  controller: _amount,
                  hint: 'Minimum Recharge value is 3000',
                  keyboard: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                if (_kind == _PayKind.online) ..._online() else ..._bank(),
              ],
            ),
          ),
        ),
        _primaryBar(context, _kind == _PayKind.online ? 'Proceed To Pay' : 'Upload Challan', onTap: _submit),
      ],
    );
  }

  Widget _row(String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(child: Text(k, style: AppText.poppins(size: 13.5, weight: strong ? FontWeight.w800 : FontWeight.w600, color: strong ? AppColors.ink : AppColors.ink2))),
            Text(v, style: AppText.poppins(size: strong ? 16 : 13.5, weight: FontWeight.w800, color: strong ? AppColors.evaGreenDeep : AppColors.ink)),
          ],
        ),
      );

  List<Widget> _online() {
    final a = _amt;
    // Web calculateCharges('online'): GST is 18% of (amount + gateway charge),
    // total charge = gateway + gst, total to pay = amount + total charge.
    final gw = a * 0.025;
    final gst = (a + gw) * 0.18;
    final tc = gw + gst;
    final pay = a + tc;
    return [
      const SizedBox(height: 8),
      _row('Gateway Charges (2.5%)', _inr(gw, dec: true)),
      const Divider(height: 1, color: AppColors.line),
      _row('GST (18% on Charges)', _inr(gst, dec: true)),
      const Divider(height: 1, color: AppColors.line),
      _row('Total charges', _inr(tc, dec: true)),
      const Divider(height: 1, color: AppColors.line),
      _row('Wallet amount', _inr(a)),
      const Divider(height: 1.5, color: AppColors.ink4),
      _row('Total amount to pay', _inr(pay, dec: true), strong: true),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _bank() {
    final a = _amt;
    // Web calculateCharges('bank'): reverse GST = amount * 18 / 118, no gateway
    // charge. Total deduction = GST; wallet credit = amount - GST.
    final g = a * 18 / 118;
    final td = g;
    final wal = (a - td).clamp(0, double.infinity);
    return [
      _fieldLabel('Challan Date'),
      InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: _pickChallanDate,
        child: IgnorePointer(
          child: _boxInput(
            controller: TextEditingController(text: _challanDate == null ? '' : _fmtDmy(_challanDate!)),
            hint: 'dd-mm-yyyy',
            readOnly: true,
            trailing: const Icon(Icons.calendar_today_rounded, size: 17, color: AppColors.ink3),
          ),
        ),
      ),
      _fieldLabel('Payment Mode'),
      _selectBox<String>(
        value: _payMode,
        placeholder: 'Select Payment Mode',
        options: const [('cheque', 'Cheque'), ('deposit', 'Bank deposit'), ('dd', 'DD'), ('online', 'Online')],
        onChanged: (v) => setState(() => _payMode = v),
      ),
      _fieldLabel('Reference Number'),
      _boxInput(controller: _ref, hint: 'Reference number'),
      _fieldLabel('Account Number'),
      _selectBox<String>(
        value: _account,
        placeholder: 'Select Account',
        options: const [('99944444444000', '99944444444000 · ASKEVA • IFSC: HDFC0009866')],
        onChanged: (v) => setState(() => _account = v),
      ),
      _fieldLabel('Upload Challan'),
      InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: _pickChallanFile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppColors.evaGreen50,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.evaGreen200),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_challanBytes != null ? Icons.description_rounded : Icons.file_upload_outlined, size: 18, color: AppColors.evaGreenDeep),
                const SizedBox(width: 8),
                Flexible(child: Text(_challanName ?? 'Upload', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.evaGreenDeep))),
              ],
            ),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Allowed jpg, png and pdf. Max size of 2 MB', style: TextStyle(fontSize: 11, color: AppColors.ink4)),
      ),
      const SizedBox(height: 10),
      _row('GST (18% on Charges)', _inr(g, dec: true)),
      const Divider(height: 1, color: AppColors.line),
      _row('Total Deduction', _inr(td, dec: true)),
      const Divider(height: 1.5, color: AppColors.ink4),
      _row('Wallet Amount', _inr(wal, dec: true), strong: true),
      const SizedBox(height: 8),
    ];
  }

  Future<void> _submit() async {
    if (_busy) return;
    final a = _amt;
    if (a < _kMinRecharge) {
      appToast(context, 'Minimum recharge value is ₹${_kMinRecharge.round()}');
      return;
    }
    final scope = AppScope.of(context);

    if (_kind == _PayKind.online) {
      // Grand total = amount + gateway (2.5%) + GST (18% of amount+gateway).
      final gw = a * 0.025;
      final pay = a + gw + (a + gw) * 0.18;
      setState(() => _busy = true);
      try {
        final html = await scope.payments.addWallet(pay);
        final opened = await openGatewayHtml(html);
        if (!mounted) return;
        Navigator.of(context).pop();
        widget.toast(opened
            ? 'Opening secure payment for ${_inr(pay, dec: true)}…'
            : 'Could not open the payment page. Please try again.');
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          appToast(context, 'Could not start payment. Please try again.');
        }
      }
      return;
    }

    // Bank transaction
    if (_challanDate == null) return appToast(context, 'Select the challan date');
    if (_payMode == null) return appToast(context, 'Select the payment mode');
    final ref = _ref.text.trim();
    if (ref.isEmpty || !RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(ref)) {
      return appToast(context, 'Reference number allows only letters and numbers');
    }
    if (_account == null) return appToast(context, 'Select the account number');
    if (_challanBytes == null) return appToast(context, 'Upload the challan (jpg, png or pdf)');

    final gst = a * 18 / 118;
    final added = a - gst;
    setState(() => _busy = true);
    try {
      final fileUrl = await scope.payments.uploadChallanFile(_challanBytes!, _challanName ?? 'challan');
      if (fileUrl == null || fileUrl.isEmpty) throw Exception('upload failed');
      await scope.payments.uploadChallan(
        paymentMode: _payMode!,
        challanDate: _fmtDmy(_challanDate!),
        challanFile: fileUrl,
        referenceNum: ref,
        accountNumber: _account!,
        gstAmount: double.parse(gst.toStringAsFixed(2)),
        totalAmountPaid: a,
        addedAmount: double.parse(added.toStringAsFixed(2)),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.toast('Payment requested — waiting for approval');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        appToast(context, 'Payment initialization failed. Please try again.');
      }
    }
  }

  Future<void> _pickChallanDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _challanDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _challanDate = d);
  }

  Future<void> _pickChallanFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.size > 2 * 1024 * 1024) {
      if (mounted) appToast(context, 'File size must be less than 2 MB');
      return;
    }
    if (f.bytes == null) return;
    setState(() {
      _challanBytes = f.bytes;
      _challanName = f.name;
    });
  }

  static String _fmtDmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
}

// ---------------------------------------------------------------------------
// Payment gateway
// ---------------------------------------------------------------------------

const _upiApps = [('gpay', 'GPay', Color(0xFF4285F4)), ('phonepe', 'PhonePe', Color(0xFF5F259F)), ('paytm', 'Paytm', Color(0xFF012E58)), ('bhim', 'BHIM', Color(0xFFE2761B))];
const _netBanks = [('hdfc', 'HDFC', Color(0xFF004C8F)), ('icici', 'ICICI', Color(0xFFAE282E)), ('sbi', 'SBI', Color(0xFF22409A)), ('axis', 'Axis', Color(0xFF97144D)), ('kotak', 'Kotak', Color(0xFFED1C24)), ('yes', 'Yes Bank', Color(0xFF00518F))];

bool _luhn(String s) {
  int sum = 0;
  bool alt = false;
  for (var i = s.length - 1; i >= 0; i--) {
    var d = int.tryParse(s[i]) ?? -1;
    if (d < 0) return false;
    if (alt) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
    alt = !alt;
  }
  return s.length >= 12 && sum % 10 == 0;
}

String _cardBrand(String n) {
  if (RegExp(r'^4').hasMatch(n)) return 'VISA';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(n)) return 'Mastercard';
  if (RegExp(r'^3[47]').hasMatch(n)) return 'Amex';
  if (RegExp(r'^(60|65|81|82|508)').hasMatch(n)) return 'RuPay';
  return '';
}

Future<void> showPaymentSheet(
  BuildContext context,
  double amount, {
  required void Function(double credited) onCredit,
  required void Function(String) toast,
  bool charge = true,
  String headNm = 'AskEva Technologies',
  String headSub = 'Wallet recharge',
  String totalLabel = 'Total payable',
}) =>
    showAppSheet(context, _PaymentSheet(amount: amount, onCredit: onCredit, toast: toast, charge: charge, headNm: headNm, headSub: headSub, totalLabel: totalLabel));

class _PaymentSheet extends StatefulWidget {
  final double amount;
  final bool charge;
  final String headNm, headSub, totalLabel;
  final void Function(double) onCredit;
  final void Function(String) toast;
  const _PaymentSheet({
    required this.amount,
    required this.onCredit,
    required this.toast,
    required this.charge,
    required this.headNm,
    required this.headSub,
    required this.totalLabel,
  });
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _open = 'upi'; // upi | card | bank
  String _upiApp = '';
  String _bankSel = '';
  final _vpa = TextEditingController();
  final _cardNum = TextEditingController();
  final _exp = TextEditingController();
  final _cvv = TextEditingController();
  final _name = TextEditingController();
  String _brand = '';

  double get _total => widget.charge ? widget.amount + widget.amount * 0.025 * 1.18 : widget.amount;

  @override
  void dispose() {
    _vpa.dispose();
    _cardNum.dispose();
    _exp.dispose();
    _cvv.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amt = _inr(_total, dec: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(
          context,
          icon: Icons.payment_rounded,
          title: 'Payment',
          leading: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 32, height: 32, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chevron_left_rounded, size: 22, color: AppColors.ink2),
              ),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.evaGreen200)),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38, alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.account_balance_wallet_rounded, size: 19, color: AppColors.evaGreenDeep),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.headNm, style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(widget.headSub, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(amt, style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                          const SizedBox(height: 2),
                          Text(widget.totalLabel, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Choose payment method', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
                const SizedBox(height: 10),
                _method(id: 'upi', icon: Icons.smartphone_rounded, title: 'UPI', subtitle: 'GPay, PhonePe, Paytm, BHIM', body: _upiBody()),
                const SizedBox(height: 10),
                _method(id: 'card', icon: Icons.credit_card_rounded, title: 'Credit / Debit Card', subtitle: 'Visa, Mastercard, RuPay, Amex', body: _cardBody()),
                const SizedBox(height: 10),
                _method(id: 'bank', icon: Icons.account_balance_rounded, title: 'Net Banking', subtitle: 'All major banks supported', body: _bankBody()),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.ink4),
                      const SizedBox(width: 6),
                      Text('256-bit secured payment', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _primaryBar(context, 'Pay $amt', icon: Icons.lock_outline_rounded, onTap: _pay),
      ],
    );
  }

  Widget _method({required String id, required IconData icon, required String title, required String subtitle, required Widget body}) {
    final active = _open == id;
    return GestureDetector(
      onTap: () => setState(() {
        _open = active ? '' : id;
        _upiApp = '';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: active ? AppColors.evaGreen : AppColors.line, width: active ? 1.6 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36, alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 18, color: AppColors.ink2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 1),
                      Text(subtitle, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                    ],
                  ),
                ),
                Icon(active ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 22, color: AppColors.ink3),
              ],
            ),
            if (active) ...[const SizedBox(height: 14), body],
          ],
        ),
      ),
    );
  }

  Widget _upiBody() {
    Widget app(String id, String name, Color c) {
      final sel = _upiApp == id;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _upiApp = id;
            _vpa.clear();
          }),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: sel ? 1.6 : 1),
            ),
            child: Column(
              children: [
                Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)), child: Text(name[0], style: AppText.poppins(size: 14, weight: FontWeight.w800, color: Colors.white))),
                const SizedBox(height: 6),
                Text(name, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink2)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [for (final a in _upiApps) app(a.$1, a.$2, a.$3)]),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.line)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('OR PAY USING UPI ID', style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.ink4, letterSpacing: 0.5))),
            const Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 12),
        _boxInput(controller: _vpa, hint: 'yourname@bank', onChanged: (v) {
          if (v.isNotEmpty && _upiApp.isNotEmpty) setState(() => _upiApp = '');
        }),
      ],
    );
  }

  Widget _cardBody() => Column(
        children: [
          _boxInput(
            controller: _cardNum,
            hint: '1234 5678 9012 3456',
            keyboard: TextInputType.number,
            trailing: _brand.isEmpty ? null : Padding(padding: const EdgeInsets.only(right: 12), child: Center(widthFactor: 1, child: Text(_brand, style: AppText.poppins(size: 11, weight: FontWeight.w800, color: AppColors.ink3)))),
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(19), _CardNumberFormatter()],
            onChanged: (v) {
              final raw = v.replaceAll(' ', '');
              final b = _cardBrand(raw);
              if (b != _brand) setState(() => _brand = b);
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _boxInput(controller: _exp, hint: 'MM / YY', keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryFormatter()])),
            const SizedBox(width: 10),
            Expanded(child: _boxInput(controller: _cvv, hint: 'CVV', obscure: true, keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
          ]),
          const SizedBox(height: 10),
          _boxInput(controller: _name, hint: 'Name on card'),
        ],
      );

  Widget _bankBody() {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
          children: [
            for (final b in _netBanks)
              GestureDetector(
                onTap: () => setState(() => _bankSel = b.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _bankSel == b.$1 ? AppColors.evaGreen : AppColors.line, width: _bankSel == b.$1 ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: b.$3, borderRadius: BorderRadius.circular(6)), child: Text(b.$2[0], style: AppText.poppins(size: 12, weight: FontWeight.w800, color: Colors.white))),
                      const SizedBox(width: 7),
                      Expanded(child: Text(b.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2))),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _selectBox<String>(
          value: null,
          placeholder: 'Select another bank…',
          options: const [('bob', 'Bank of Baroda'), ('pnb', 'Punjab National Bank'), ('idfc', 'IDFC First Bank'), ('indus', 'IndusInd Bank'), ('federal', 'Federal Bank'), ('rbl', 'RBL Bank')],
          onChanged: (v) => setState(() => _bankSel = v),
        ),
      ],
    );
  }

  bool _validate() {
    if (_open == 'upi') {
      if (_upiApp.isNotEmpty) return true;
      if (RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(_vpa.text.trim())) return true;
      appToast(context, 'Select a UPI app or enter a valid UPI ID');
      return false;
    }
    if (_open == 'card') {
      final num = _cardNum.text.replaceAll(' ', '');
      final exp = _exp.text.replaceAll(' ', '').replaceAll('/', '');
      if (!_luhn(num)) {
        appToast(context, 'Enter a valid card number');
        return false;
      }
      final mm = int.tryParse(exp.length >= 2 ? exp.substring(0, 2) : '') ?? 0;
      final yy = int.tryParse(exp.length >= 4 ? exp.substring(2, 4) : '') ?? -1;
      if (mm < 1 || mm > 12 || exp.length < 4) {
        appToast(context, 'Enter a valid expiry date');
        return false;
      }
      final now = DateTime.now();
      final curY = now.year % 100, curM = now.month;
      if (yy < curY || (yy == curY && mm < curM)) {
        appToast(context, 'Card has expired');
        return false;
      }
      if (_cvv.text.length < 3) {
        appToast(context, 'Enter a valid CVV');
        return false;
      }
      if (_name.text.trim().length < 2) {
        appToast(context, 'Enter the name on card');
        return false;
      }
      return true;
    }
    if (_open == 'bank') {
      if (_bankSel.isNotEmpty) return true;
      appToast(context, 'Select your bank to continue');
      return false;
    }
    appToast(context, 'Choose a payment method');
    return false;
  }

  void _pay() {
    if (!_validate()) return;
    final credited = widget.amount; // wallet credited with the base amount (charges are the fee)
    Navigator.of(context).pop();
    runPaymentSuccess(
      context,
      procT: 'Processing payment…',
      procS: 'Please don’t press back or close',
      okT: 'Payment Successful',
      okS: '${_inr(credited)} added to your wallet',
      toastMsg: '${_inr(credited)} added to wallet successfully',
      toast: widget.toast,
      onSucceed: () => widget.onCredit(credited),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(digits[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final d = newValue.text.replaceAll(RegExp(r'\D'), '');
    final t = d.length > 2 ? '${d.substring(0, 2)} / ${d.substring(2)}' : d;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ---------------------------------------------------------------------------
// Subscription: plan catalog + Renew / Upgrade flows (ports subscription.js)
// ---------------------------------------------------------------------------

class PlanInfo {
  final String id, name, tagline;
  final int monthly, tier;
  const PlanInfo(this.id, this.name, this.monthly, this.tier, this.tagline);
}

const Map<String, PlanInfo> kCatalog = {
  'ecommerce': PlanInfo('ecommerce', 'Ecommerce', 1999, 2, 'Our most complete plan — unlimited agents, every feature and priority support for serious online stores.'),
  'enterprise': PlanInfo('enterprise', 'Enterprise', 1199, 1, 'Core automation, APIs and catalog messaging for growing teams. Upgrade to Ecommerce for unlimited scale.'),
};
const List<String> _planOrder = ['ecommerce', 'enterprise'];

const List<(String, Object, Object)> _features = [
  ('Broadcast & Analytics', true, true),
  ('Live Chat + History', true, true),
  ('Chatbot Nodes', 'Unlimited', '7'),
  ('Team Agents', 'Unlimited', '5'),
  ('APIs & Webhooks', true, true),
  ('Catalog / Product Messages', true, true),
  ('Carousel & WA Forms', true, true),
  ('Role-based Access', true, false),
  ('Dedicated Success Manager', true, false),
  ('Priority Support (24×7)', true, false),
];

// term -> discount
const List<(int, String, double)> _terms = [(3, '3 Months', 0.0), (6, '6 Months', 0.08), (12, '12 Months', 0.17)];

int _maxTier() => kCatalog.values.fold(0, (m, p) => p.tier > m ? p.tier : m);
PlanInfo planByName(String name) => kCatalog[name.toLowerCase()] ?? kCatalog['ecommerce']!;
bool isTopTierPlan(String name) => planByName(name).tier >= _maxTier();
int _priceFor(PlanInfo p, int months, double discount) => (p.monthly * months * (1 - discount)).round();

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Renew the CURRENT plan — 3/6/12 month terms with savings + payment method.
Future<void> showRenewSheet(BuildContext context, {required String planName, required void Function(String) toast}) =>
    showAppSheet(context, _RenewSheet(plan: planByName(planName), toast: toast));

class _RenewSheet extends StatefulWidget {
  final PlanInfo plan;
  final void Function(String) toast;
  const _RenewSheet({required this.plan, required this.toast});
  @override
  State<_RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<_RenewSheet> {
  int _months = 12;
  String _method = 'online';

  @override
  Widget build(BuildContext context) {
    final term = _terms.firstWhere((t) => t.$1 == _months);
    final total = _priceFor(widget.plan, _months, term.$3);
    final newExp = DateTime(DateTime.now().year, DateTime.now().month + _months, DateTime.now().day);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(context, icon: Icons.autorenew_rounded, title: 'Renew Plan'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _renewHead('Renew ${widget.plan.name}', 'Extend your current plan — your tier and features stay the same.'),
                const SizedBox(height: 12),
                for (final t in _terms) _termRow(t),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total payable', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                            const SizedBox(height: 3),
                            Text('New expiry · ${_fmtDate(newExp)}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                          ],
                        ),
                      ),
                      Text(_inr(total), style: AppText.poppins(size: 19, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                    ],
                  ),
                ),
                _fieldLabel('Payment Method'),
                Row(children: [
                  Expanded(child: _payMethod('wallet', Icons.account_balance_wallet_rounded, 'Wallet', 'Use AskEva balance')),
                  const SizedBox(width: 10),
                  Expanded(child: _payMethod('online', Icons.credit_card_rounded, 'Online Payment', 'Card / Netbanking')),
                ]),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        _primaryBar(context, 'Pay ${_inr(total)} & Renew', icon: Icons.lock_outline_rounded, onTap: () async {
          try {
            await AppScope.of(context).auth.fetchProfile();
            await AppScope.of(context).auth.fetchUserPlan();
          } catch (_) {}
          if (!context.mounted) return;
          Navigator.of(context).pop();
          widget.toast('${widget.plan.name} renewed · $_months months');
        }),
      ],
    );
  }

  Widget _renewHead(String t, String s) => Row(
        children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.autorenew_rounded, size: 19, color: AppColors.evaGreenDeep)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(s, style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3, height: 1.35)),
              ],
            ),
          ),
        ],
      );

  Widget _termRow((int, String, double) t) {
    final sel = _months == t.$1;
    final price = _priceFor(widget.plan, t.$1, t.$3);
    final per = (price / t.$1).round();
    final save = widget.plan.monthly * t.$1 - price;
    return GestureDetector(
      onTap: () => setState(() => _months = t.$1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: sel ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? AppColors.evaGreen : AppColors.ink4, width: 2)),
              child: sel ? const Center(child: CircleAvatar(radius: 5, backgroundColor: AppColors.evaGreen)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.$2, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('${_inr(per)}/mo${t.$3 > 0 ? ' · save ${(t.$3 * 100).round()}%' : ''}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_inr(price), style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
                if (save > 0) Text('save ${_inr(save)}', style: AppText.poppins(size: 10.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _payMethod(String id, IconData icon, String title, String sub) {
    final sel = _method == id;
    return GestureDetector(
      onTap: () => setState(() => _method = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.evaGreenDeep),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.poppins(size: 12.5, weight: FontWeight.w800, color: AppColors.ink)),
                  Text(sub, style: AppText.poppins(size: 10, weight: FontWeight.w600, color: AppColors.ink3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compare plans (Upgrade). Shown when the current plan is NOT the top tier.
Future<void> showUpgradeSheet(BuildContext context, {required String planName, required void Function(String) toast}) {
  if (isTopTierPlan(planName)) {
    toast('You’re already on the best plan');
    return Future.value();
  }
  return showAppSheet(context, _UpgradeSheet(current: planByName(planName), toast: toast));
}

class _UpgradeSheet extends StatelessWidget {
  final PlanInfo current;
  final void Function(String) toast;
  const _UpgradeSheet({required this.current, required this.toast});

  @override
  Widget build(BuildContext context) {
    final target = _planOrder.firstWhere((id) => id != current.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(context, icon: Icons.rocket_launch_rounded, title: 'Compare Plans'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final id in _planOrder) ...[
                      Expanded(child: _planCard(context, kCatalog[id]!, isCur: id == current.id, isTgt: id == target)),
                      if (id != _planOrder.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Text('Full feature comparison', style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 10),
                _cmpHeader(),
                for (final f in _features) _cmpRow(f),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _planCard(BuildContext context, PlanInfo p, {required bool isCur, required bool isTgt}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTgt ? AppColors.evaGreen50 : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTgt ? AppColors.evaGreen : AppColors.line, width: isTgt ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCur)
            _ribbon('Current Plan', AppColors.ink3)
          else if (isTgt)
            _ribbon('Switch to', AppColors.evaGreenDeep),
          const SizedBox(height: 8),
          Text(p.name, style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_inr(p.monthly), style: AppText.poppins(size: 18, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
            Text('/mo', style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink4)),
          ]),
          const SizedBox(height: 6),
          Text(p.tagline, style: AppText.poppins(size: 11, weight: FontWeight.w500, color: AppColors.ink3, height: 1.35)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isCur
                ? OutlinedButton(onPressed: null, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))), child: const Text('Your plan'))
                : FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      final up = p.tier > current.tier;
                      showAppSheet(context, _SwitchSheet(from: current, to: p, isUpgrade: up, toast: toast));
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.evaGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                    child: Text('${p.tier > current.tier ? 'Upgrade' : 'Switch'} to ${p.name}', style: AppText.poppins(size: 12, weight: FontWeight.w700, color: Colors.white)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ribbon(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: AppText.poppins(size: 10, weight: FontWeight.w800, color: c)),
      );

  Widget _cmpHeader() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Expanded(flex: 4, child: Text('Feature', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink3, fontSize: 11))),
          for (final id in _planOrder)
            Expanded(flex: 2, child: Text(kCatalog[id]!.name, textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w800, color: id == current.id ? AppColors.ink3 : AppColors.evaGreenDeep))),
        ]),
      );

  Widget _cmpRow((String, Object, Object) f) {
    Widget cell(Object v) {
      if (v is bool) {
        return Icon(v ? Icons.check_rounded : Icons.close_rounded, size: 16, color: v ? AppColors.evaGreenDeep : AppColors.ink4);
      }
      return Text('$v', textAlign: TextAlign.center, style: AppText.poppins(size: 11, weight: FontWeight.w700, color: AppColors.ink2));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(children: [
        Expanded(flex: 4, child: Text(f.$1, style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink))),
        Expanded(flex: 2, child: Center(child: cell(f.$2))),
        Expanded(flex: 2, child: Center(child: cell(f.$3))),
      ]),
    );
  }
}

/// Switch / upgrade with proration credit.
class _SwitchSheet extends StatefulWidget {
  final PlanInfo from, to;
  final bool isUpgrade;
  final void Function(String) toast;
  const _SwitchSheet({required this.from, required this.to, required this.isUpgrade, required this.toast});
  @override
  State<_SwitchSheet> createState() => _SwitchSheetState();
}

class _SwitchSheetState extends State<_SwitchSheet> {
  int _months = 12;
  // Notional unused-time credit on the current plan (30 days assumed remaining).
  late final int _credit = ((widget.from.monthly / 30) * 30).round();

  @override
  Widget build(BuildContext context) {
    final term = _terms.firstWhere((t) => t.$1 == _months);
    final total = _priceFor(widget.to, _months, term.$3);
    final applied = _credit < total ? _credit : total;
    final payable = (total - applied).clamp(0, total);
    final newExp = DateTime(DateTime.now().year, DateTime.now().month + _months, DateTime.now().day);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sheetHeader(context, icon: Icons.rocket_launch_rounded, title: 'Change Plan'),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.from.name} → ${widget.to.name}', style: AppText.poppins(size: 15, weight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text('Pick a term for ${widget.to.name}. Unused time on your ${widget.from.name} plan is adjusted automatically.',
                    style: AppText.poppins(size: 12, weight: FontWeight.w600, color: AppColors.ink3, height: 1.35)),
                const SizedBox(height: 12),
                for (final t in _terms) _termPick(t),
                const SizedBox(height: 8),
                _adjRow('${widget.to.name} · $_months months', _inr(total), false),
                if (applied > 0) _adjRow('Adjustment · unused ${widget.from.name}', '− ${_inr(applied)}', true),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Amount payable', style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 3),
                        Text('New expiry · ${_fmtDate(newExp)}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
                      ]),
                    ),
                    Text(_inr(payable), style: AppText.poppins(size: 19, weight: FontWeight.w800, color: AppColors.evaGreenDeep)),
                  ]),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        _primaryBar(context, 'Pay ${_inr(payable)} & ${widget.isUpgrade ? 'Upgrade' : 'Switch'}', icon: Icons.lock_outline_rounded, onTap: () {
          Navigator.of(context).pop();
          widget.toast('Switched to ${widget.to.name} · paid ${_inr(payable)}');
        }),
      ],
    );
  }

  Widget _termPick((int, String, double) t) {
    final sel = _months == t.$1;
    final price = _priceFor(widget.to, t.$1, t.$3);
    final per = (price / t.$1).round();
    return GestureDetector(
      onTap: () => setState(() => _months = t.$1),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: sel ? AppColors.evaGreen50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AppColors.evaGreen : AppColors.line, width: sel ? 1.6 : 1),
        ),
        child: Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel ? AppColors.evaGreen : AppColors.ink4, width: 2)),
            child: sel ? const Center(child: CircleAvatar(radius: 5, backgroundColor: AppColors.evaGreen)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2, style: AppText.poppins(size: 14, weight: FontWeight.w800, color: AppColors.ink)),
              Text('${_inr(per)}/mo${t.$3 > 0 ? ' · save ${(t.$3 * 100).round()}%' : ''}', style: AppText.poppins(size: 11.5, weight: FontWeight.w600, color: AppColors.ink3)),
            ]),
          ),
          Text(_inr(price), style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: AppColors.ink)),
        ]),
      ),
    );
  }

  Widget _adjRow(String l, String v, bool credit) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(l, style: AppText.poppins(size: 12.5, weight: FontWeight.w600, color: credit ? AppColors.evaGreenDeep : AppColors.ink2))),
          Text(v, style: AppText.poppins(size: 13, weight: FontWeight.w800, color: credit ? AppColors.evaGreenDeep : AppColors.ink)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Notifications panel (drops from the top)
// ---------------------------------------------------------------------------

Future<void> showNotificationsPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -0.1), end: Offset.zero).animate(curved),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, MediaQuery.of(ctx).padding.top + 56, 12, 0),
              child: const _NotificationsCard(),
            ),
          ),
        ),
      );
    },
  );
}

String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hrs ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
}

String _dayLabel(DateTime? dt) {
  if (dt == null) return 'Older';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateTime(dt.year, dt.month, dt.day);

  if (dateOnly == today) return 'Today';
  if (dateOnly == yesterday) return 'Yesterday';
  return '${dt.day.toString().padLeft(2, '0')} ${[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][dt.month - 1]} ${dt.year}';
}

class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard();

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  final ScrollController _scrollController = ScrollController();
  List<NotificationDto> _list = [];
  int _unreadCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final s = AppScope.of(context);
      final list = await s.notifications.fetchNotifications(limit: 20);
      final count = await s.notifications.fetchUnreadCount();
      if (mounted) {
        setState(() {
          _list = list;
          _unreadCount = count;
          _loading = false;
        });
        kNotificationUnreadCount.value = count;
      }
    } catch (e, stack) {
      debugPrint('[NotificationsCard] Error loading notifications: $e\n$stack');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final s = AppScope.of(context);
      if (mounted) {
        setState(() {
          _unreadCount = 0;
          _list = _list.map((n) => NotificationDto(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
            data: n.data,
          )).toList();
        });
      }
      kNotificationUnreadCount.value = 0;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('All notifications', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
                Text('marked read', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E2620),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            width: 200,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await s.notifications.markAllAsRead();
      _loadData();
    } catch (e) {
      appToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _onNotificationClick(NotificationDto n) async {
    try {
      if (!n.isRead) {
        final s = AppScope.of(context);
        await s.notifications.markAsRead(n.id);
        if (mounted) {
          final count = await s.notifications.fetchUnreadCount();
          kNotificationUnreadCount.value = count;
        }
      }
      appToast(context, 'Notification marked as read', isSuccess: true);
      _loadData();
      if (mounted) {
        _handleNotificationNavigation(context, n);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<NotificationDto>>{};
    for (final n in _list) {
      final label = _dayLabel(n.createdAt);
      grouped.putIfAbsent(label, () => []).add(n);
    }
    final days = grouped.keys.toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.shadowMd,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
              child: Row(
                children: [
                  Text('Notifications', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(width: 8),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.evaGreenDeep,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$_unreadCount', style: AppText.poppins(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  const Spacer(),
                  InkWell(
                    onTap: _markAllRead,
                    child: Text('Mark all read', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.close_rounded, size: 19, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.evaGreenDeep))),
              )
            else if (_unreadCount == 0 || _list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: AppColors.surface2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 24,
                        color: AppColors.ink3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "You’re all caught up",
                      style: AppText.poppins(size: 13.5, weight: FontWeight.w800, color: AppColors.ink2),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView(
                    controller: _scrollController,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      for (final day in days) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
                          child: Text(
                            day,
                            style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink3),
                          ),
                        ),
                        for (final n in grouped[day]!) _itemRow(n),
                      ],
                    ],
                  ),
                ),
              ),
            const Divider(height: 1, color: AppColors.line),
            InkWell(
              onTap: () {
                Navigator.of(context).maybePop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text('View all notifications', style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(NotificationDto n) {
    final type = n.type.toLowerCase();
    final isTicket = type.contains('ticket') || type == 'status_changed';
    final isLead = type.contains('lead') || type == 'lead_reminder';
    final isAppt = type.contains('appointment');

    final IconData icon;
    final Color iconColor;
    final Color iconBg;

    if (isTicket) {
      icon = Icons.receipt_long_rounded;
      iconColor = const Color(0xFF8B5CF6);
      iconBg = const Color(0xFFF3E8FF);
    } else if (isLead) {
      icon = Icons.person_outline_rounded;
      iconColor = AppColors.evaGreenDeep;
      iconBg = AppColors.evaGreen50;
    } else if (isAppt) {
      icon = Icons.event_outlined;
      iconColor = const Color(0xFF3B82F6);
      iconBg = const Color(0xFFDBEAFE);
    } else {
      icon = Icons.notifications_none_rounded;
      iconColor = const Color(0xFF4B5563);
      iconBg = const Color(0xFFF3F4F6);
    }

    final timeStr = _relativeTime(n.createdAt);

    return InkWell(
      onTap: () => _onNotificationClick(n),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: n.isRead ? AppColors.surface : AppColors.evaGreen50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: n.isRead ? AppColors.line : AppColors.evaGreen200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: AppText.poppins(size: 12, weight: FontWeight.w500, color: AppColors.ink2, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: AppText.poppins(size: 11, weight: FontWeight.w600, color: AppColors.ink3),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.evaGreenDeep, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _tab = 0;
  static const _tabs = ['All', 'Tickets', 'Leads', 'Appointments', 'Catalog Orders'];

  List<NotificationDto> _all = [];
  bool _loading = true;
  DateTimeRange? _selectedDateRange;
  bool _unreadFilter = false; // false = all status, true = unread only

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final s = AppScope.of(context);
      final list = await s.notifications.fetchNotifications(
        limit: 200,
        isRead: _unreadFilter ? false : null,
      );
      final count = await s.notifications.fetchUnreadCount();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
        });
        kNotificationUnreadCount.value = count;
      }
    } catch (e, stack) {
      debugPrint('[NotificationsScreen] Error loading notifications: $e\n$stack');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      final s = AppScope.of(context);
      if (mounted) {
        setState(() {
          _all = _all.map((n) => NotificationDto(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
            data: n.data,
          )).toList();
        });
      }
      kNotificationUnreadCount.value = 0;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('All notifications', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
                Text('marked read', style: AppText.poppins(size: 13.5, weight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E2620),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            width: 200,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await s.notifications.markAllAsRead();
      _loadNotifications();
    } catch (e) {
      appToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _onNotificationClick(NotificationDto n) async {
    try {
      if (!n.isRead) {
        final s = AppScope.of(context);
        await s.notifications.markAsRead(n.id);
        if (mounted) {
          final count = await s.notifications.fetchUnreadCount();
          kNotificationUnreadCount.value = count;
        }
      }
      appToast(context, 'Notification marked as read', isSuccess: true);
      _loadNotifications();
      if (mounted) {
        _handleNotificationNavigation(context, n);
      }
    } catch (_) {}
  }

  Future<void> _deleteNotification(NotificationDto n) async {
    try {
      final s = AppScope.of(context);
      await s.notifications.deleteNotification(n.id);
      appToast(context, 'Notification deleted', isSuccess: true);
      _loadNotifications();
    } catch (e) {
      appToast(context, e.toString(), isError: true);
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showAppDateRangePicker(
      context,
      initialRange: _selectedDateRange,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    // Apply Filters & Date Ranges
    final countAll = _all.where((n) {
      if (_unreadFilter && n.isRead) return false;
      if (_selectedDateRange != null && n.createdAt != null) {
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (n.createdAt!.isBefore(start) || n.createdAt!.isAfter(end)) return false;
      }
      return true;
    }).toList();

    final countTickets = countAll.where((n) => n.type.toLowerCase().contains('ticket') || n.type.toLowerCase() == 'status_changed').length;
    final countLeads = countAll.where((n) => n.type.toLowerCase().contains('lead') || n.type.toLowerCase() == 'lead_reminder').length;
    final countAppts = countAll.where((n) => n.type.toLowerCase().contains('appointment')).length;
    final countCatalog = countAll.where((n) => n.type.toLowerCase().contains('catalog') || n.type.toLowerCase().contains('order')).length;

    final filtered = countAll.where((n) {
      final typeLower = n.type.toLowerCase();
      if (_tab == 1 && !(typeLower.contains('ticket') || typeLower == 'status_changed')) return false;
      if (_tab == 2 && !(typeLower.contains('lead') || typeLower == 'lead_reminder')) return false;
      if (_tab == 3 && !typeLower.contains('appointment')) return false;
      if (_tab == 4 && !(typeLower.contains('catalog') || typeLower.contains('order'))) return false;
      return true;
    }).toList();

    // Group by Day Label
    final grouped = <String, List<NotificationDto>>{};
    for (final n in filtered) {
      final label = _dayLabel(n.createdAt);
      grouped.putIfAbsent(label, () => []).add(n);
    }
    final days = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.surface2,
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Icon(Icons.chevron_left_rounded, size: 24, color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.evaGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications', style: AppText.poppins(size: 17, weight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 1),
                      Text('See all updates at a glance', style: AppText.poppins(size: 10.5, weight: FontWeight.w600, color: AppColors.ink3)),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0x22000000),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  child: PopupMenuButton<bool>(
                    onSelected: (val) {
                      setState(() {
                        _unreadFilter = val;
                        _loading = true;
                      });
                      _loadNotifications();
                    },
                    offset: const Offset(0, 40),
                    itemBuilder: (context) => [
                      PopupMenuItem<bool>(
                        value: false,
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 3),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: !_unreadFilter ? const Color(0xFFE8F5E9) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'All status',
                            style: AppText.poppins(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: AppColors.evaGreen,
                            ),
                          ),
                        ),
                      ),
                      PopupMenuItem<bool>(
                        value: true,
                        padding: const EdgeInsets.fromLTRB(6, 3, 6, 6),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _unreadFilter ? const Color(0xFFE8F5E9) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Unread',
                            style: AppText.poppins(
                              size: 13.5,
                              weight: FontWeight.w700,
                              color: _unreadFilter ? AppColors.evaGreen : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _unreadFilter ? 'Unread' : 'All status',
                            style: AppText.poppins(size: 11.5, weight: FontWeight.w700, color: AppColors.ink2),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: AppColors.ink3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: _selectDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.evaGreen50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.evaGreen200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _selectedDateRange == null
                                    ? 'Start date → End date'
                                    : '${_selectedDateRange!.start.day.toString().padLeft(2, '0')}/${_selectedDateRange!.start.month.toString().padLeft(2, '0')} → ${_selectedDateRange!.end.day.toString().padLeft(2, '0')}/${_selectedDateRange!.end.month.toString().padLeft(2, '0')}',
                                style: AppText.poppins(size: 12, weight: FontWeight.w700, color: AppColors.evaGreenDeep),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedDateRange != null)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                },
                                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.evaGreenDeep),
                              )
                            else
                              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.evaGreenDeep),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _markAllRead,
                  child: Text('Mark all read', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.evaGreenDeep)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const SizedBox(width: 16),
                _tabChip(0, 'All Notifications', countAll.length),
                _tabChip(1, 'Tickets', countTickets),
                _tabChip(2, 'Leads', countLeads),
                _tabChip(3, 'Appointments', countAppts),
                _tabChip(4, 'Catalog Orders', countCatalog),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.evaGreenDeep))
                : filtered.isEmpty
                    ? Center(child: Text('No notifications', style: AppText.poppins(size: 14, weight: FontWeight.w600, color: AppColors.ink3)))
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            for (final day in days) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                                child: Text(
                                  day,
                                  style: AppText.poppins(size: 12, weight: FontWeight.w800, color: AppColors.ink3),
                                ),
                              ),
                              for (final n in grouped[day]!) _row(n),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(int index, String label, int count) {
    final active = _tab == index;
    final bg = active ? AppColors.evaGreen50 : const Color(0xFFF3F4F6);
    final fg = active ? AppColors.evaGreenDeep : AppColors.ink2;
    final badgeBg = active ? AppColors.evaGreenDeep : const Color(0xFFE5E7EB);
    final badgeFg = active ? Colors.white : AppColors.ink2;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: 12,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: AppText.poppins(
                      size: 10,
                      weight: FontWeight.w800,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(NotificationDto n) {
    final type = n.type.toLowerCase();
    final isTicket = type.contains('ticket') || type == 'status_changed';
    final isLead = type.contains('lead') || type == 'lead_reminder';
    final isAppt = type.contains('appointment');

    final IconData icon;
    final Color iconColor;
    final Color iconBg;

    if (isTicket) {
      icon = Icons.confirmation_num_outlined;
      iconColor = const Color(0xFF8B5CF6); // purple — no AppColors alias, keep
      iconBg = const Color(0xFFEEF2FF);
    } else if (isLead) {
      icon = Icons.person_outline_rounded;
      iconColor = AppColors.evaGreenDeep;
      iconBg = AppColors.evaGreen50;
    } else if (isAppt) {
      icon = Icons.calendar_today_outlined;
      iconColor = AppColors.warning;
      iconBg = const Color(0xFFFFF7ED);
    } else {
      icon = Icons.notifications_none_rounded;
      iconColor = AppColors.ink3;
      iconBg = AppColors.surface3;
    }

    final assignee = n.data['assignedTo'] ?? n.data['assigned'] ?? '';
    final timeStr = _relativeTime(n.createdAt);

    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(n),
      background: Container(
        color: Colors.red.shade400,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _onNotificationClick(n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${n.title.endsWith(':') ? n.title : '${n.title}:'} ',
                                style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.ink),
                              ),
                              TextSpan(
                                text: n.body,
                                style: AppText.poppins(size: 13, weight: FontWeight.w600, color: AppColors.ink2),
                              ),
                              if (assignee.toString().isNotEmpty && assignee.toString().toLowerCase() != 'unassigned') ...[
                                TextSpan(
                                  text: ' → ${assignee.toString().toLowerCase()}',
                                  style: AppText.poppins(size: 13, weight: FontWeight.w800, color: AppColors.evaGreenDeep),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    timeStr,
                    style: AppText.poppins(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: AppColors.ink4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _handleNotificationNavigation(BuildContext context, NotificationDto n) {
  final type = n.type.toLowerCase();
  final d = n.data;

  if (type.contains('appointment')) {
    final id = d['bookingId'] ?? d['appointmentId'] ?? d['id'] ?? d['_id'] ?? '';
    final code = d['appointmentNo'] ?? d['code'] ?? 'A0000038';
    final patient = d['name'] ?? d['patientName'] ?? d['customerName'] ?? 'Smile maker';
    final mobile = d['mobile'] ?? d['mobileNumber'] ?? d['contactNumber'] ?? '';

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AppointmentDetailScreen(
        id: id.toString(),
        code: code.toString(),
        patient: patient.toString(),
        mobile: mobile.toString(),
      ),
    ));
  } else if (type.contains('ticket') || type == 'status_changed') {
    final id = d['ticketId'] ?? d['id'] ?? d['_id'] ?? '';
    final subject = d['subject'] ?? d['ticketSubject'] ?? 'Ticket Notification';
    final status = d['status'] ?? d['newStatus'] ?? 'Pending';
    final priority = d['priority'] ?? 'Critical';
    final agent = d['agent'] ?? 'Unassigned';

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TicketDetailScreen(
        id: id.toString(),
        subject: subject.toString(),
        status: status.toString(),
        priority: priority.toString(),
        agent: agent.toString(),
      ),
    ));
  } else if (type.contains('lead')) {
    final leadId = d['leadId'] ?? d['id'] ?? d['_id'] ?? '';
    final leadName = d['leadName'] ?? d['name'] ?? 'Lead Details';
    final mobile = d['mobile'] ?? d['fullMobile'] ?? '';
    final email = d['email'] ?? '';
    final company = d['company'] ?? '';
    final status = d['status'] ?? 'New Lead';
    final source = d['source'] ?? 'Manual';

    final lead = LeadDto(
      id: leadId.toString(),
      name: leadName.toString(),
      email: email.toString(),
      mobile: mobile.toString(),
      company: company.toString(),
      statusRaw: status.toString(),
      source: source.toString(),
    );

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LeadDetailScreen(lead: lead),
    ));
  }
}

/// Displays the custom AskEva Log out confirmation dialog box matching the design.
Future<bool?> showLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFDE8E8),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.output_rounded,
                  size: 28,
                  color: Color(0xFFEF5350),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log out?',
              style: AppText.poppins(size: 20, weight: FontWeight.w800, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "You'll need to sign in again to access your AskEva workspace.",
              style: AppText.poppins(size: 13.5, weight: FontWeight.w500, color: AppColors.ink3, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F3EF),
                        foregroundColor: AppColors.ink,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppText.poppins(size: 14.5, weight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Log out',
                        style: AppText.poppins(size: 14.5, weight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

