import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/drawer_menu_icon.dart';
import '../settings/agents/tabs/agents_list_tab.dart';
import '../../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  final String? email;
  final String? name;
  const ProfilePage({super.key, this.email, this.name});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _transactions = [];
  bool _loadingTransactions = true;

  String _selectedCountry = 'Holy See (Vatican City State)';
  final Map<String, Map<String, String>> _pricingData = {
    'Holy See (Vatican City State)': {
      'Service Area': 'Holy See (Vatican City State)',
      'Authentication cost': '2.75',
      'Marketing cost': '5.45836216379454',
      'Utility cost': '3.06',
      'Session cost': '1.31',
    },
    'India ( Home Town )': {
      'Service Area': 'India ( Home Town )',
      'Authentication cost': '0.2',
      'Marketing cost': '0.962836026',
      'Utility cost': '0.2',
      'Session cost': '0',
    },
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final data = await AuthService.getInvoices();
      if (mounted) {
        setState(() {
          _transactions = data;
          _loadingTransactions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingTransactions = false);
        // Optional: show snackbar
      }
    }
  }

  Future<void> _downloadInvoice(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch invoice URL')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: AppDrawer(email: widget.email, name: widget.name),
      appBar: AppBar(
        leading: const DrawerMenuIcon(),
        title: const Text('Profile'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        color: AppColors.primary,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(child: _buildBasicDetails(context)),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline), text: 'Account'),
                    Tab(icon: Icon(Icons.people_outline), text: 'Team Members'),
                    Tab(
                      icon: Icon(Icons.lock_outline),
                      text: 'Change Password',
                    ),
                    Tab(
                      icon: Icon(Icons.credit_card_outlined),
                      text: 'Pricing',
                    ),
                    Tab(icon: Icon(Icons.receipt_long), text: 'Transactions'),
                    Tab(icon: Icon(Icons.history), text: 'Login Activity'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAccountTab(),
            const AgentsListTab(),
            _buildChangePasswordTab(),
            _buildPricingTab(),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTransactionsTable(context),
              ),
            ),
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLoginActivityList(context),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBasicDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Whatsapp Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _showEditProfileDialog(context),
                  icon: Icon(Icons.edit, size: 20, color: cs.onSurfaceVariant),
                  tooltip: 'Edit Details',
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildProfileHeaderCard(),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildWebsiteCard()),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildBusinessCard()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: _buildDescriptionCard()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildProfileHeaderCard(),
                          const SizedBox(height: 16),
                          _buildDescriptionCard(),
                          const SizedBox(height: 16),
                          _buildWebsiteCard(),
                          const SizedBox(height: 16),
                          _buildBusinessCard(),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50], // Very light grey/white background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ASK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'EVA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Eshan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'eshan@tunepath.com',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      height: 140, // Match height roughly
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Chatbot is the best solution for everything !',
            style: TextStyle(color: cs.onSurface, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            Icons.language,
            'Website',
            'https://app.askeva.io/',
            isLink: true,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.info_outline, 'About', 'Hi Hello !!!'),
        ],
      ),
    );
  }

  Widget _buildBusinessCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(
            Icons.business,
            'Business Vertical',
            'Hotel and Lodging',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            Icons.location_on_outlined,
            'Address',
            'Madurai, Hosur, Chennai...',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Align icon with the first line of text
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isLink ? Colors.blue : Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAccountDetailsCard(context)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCompanyDetailsCard(context)),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAccountDetailsCard(context),
                    const SizedBox(height: 20),
                    _buildCompanyDetailsCard(context),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          _buildTermsCard(context),
        ],
      ),
    );
  }

  Widget _buildChangePasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: Colors.transparent, // Or white if inside card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField('Old Password', 'Old Password'),
            const SizedBox(height: 20),
            _buildPasswordField('New Password', 'New Password'),
            const SizedBox(height: 20),
            _buildPasswordField('Retype New Password', 'Retype New Password'),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('* ', style: TextStyle(color: Colors.red)),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: true,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: const Icon(
              Icons.visibility_off_outlined,
              color: Colors.grey,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPricingTab() {
    final currentData = _pricingData[_selectedCountry]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF535370),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCountry,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                items: _pricingData.keys.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCountry = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildPricingRow('Service Area:', currentData['Service Area']!),
          _buildPricingRow(
            'Authentication cost:',
            currentData['Authentication cost']!,
          ),
          _buildPricingRow('Marketing cost:', currentData['Marketing cost']!),
          _buildPricingRow('Utility cost:', currentData['Utility cost']!),
          _buildPricingRow('Session cost:', currentData['Session cost']!),
        ],
      ),
    );
  }

  Widget _buildPricingRow(String label, String value) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            '$label ',
            style: TextStyle(fontSize: 16, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard(BuildContext context) {
    final details = [
      {
        'label': 'Account Status',
        'value': 'active',
        'icon': Icons.person_outline,
      },
      {
        'label': 'Creation Date',
        'value': '25/02/2025',
        'icon': Icons.calendar_today,
      },
      {
        'label': 'Activation Date',
        'value': '25/02/2025',
        'icon': Icons.check_circle_outline,
      },
      {'label': 'Reseller ID', 'value': 'N/A', 'icon': Icons.shield_outlined},
      {
        'label': 'Primary Contact Name',
        'value': 'Eshan',
        'icon': Icons.badge_outlined,
      },
      {
        'label': 'Whatsapp API No',
        'value': '917200440497',
        'icon': Icons.phone_android,
      },
      {
        'label': 'Primary Contact Mobile No',
        'value': '919042999328',
        'icon': Icons.phone,
      },
      {
        'label': 'Primary Contact Email ID',
        'value': 'eshan@tunepath.com',
        'icon': Icons.email_outlined,
      },
    ];
    return _buildDetailsCard('Account Details', details);
  }

  Widget _buildCompanyDetailsCard(BuildContext context) {
    final details = [
      {'label': 'Company Name', 'value': 'Askeva API', 'icon': Icons.business},
      {'label': 'Address', 'value': 'test', 'icon': Icons.location_on_outlined},
      {'label': 'City', 'value': 'Mdu', 'icon': Icons.location_city},
      {
        'label': 'Company Website',
        'value': 'https://www.google.com/',
        'icon': Icons.language,
      },
      {'label': 'GST No', 'value': '6372', 'icon': Icons.receipt_long},
      {'label': 'Legal Business Name', 'value': 'Askeva', 'icon': Icons.gavel},
      {'label': 'State', 'value': 'Tamil Nadu', 'icon': Icons.map},
      {'label': 'Zip', 'value': '123654', 'icon': Icons.pin_drop_outlined},
      {'label': 'Country', 'value': 'India', 'icon': Icons.flag_outlined},
    ];
    return _buildDetailsCard('Company Details', details);
  }

  Widget _buildDetailsCard(String title, List<Map<String, dynamic>> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['value'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Terms and conditions accepted.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: Icon(Icons.circle, size: 8, color: Colors.grey),
              title: Text('Important Billing Changes - Effective July 1, 2025'),
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
            ListTile(
              leading: Icon(Icons.circle, size: 8, color: Colors.grey),
              title: Text('Pricing Update - Effective January 1, 2026'),
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
            ListTile(
              leading: Icon(Icons.circle, size: 8, color: Colors.grey),
              title: Text('mmlite update'),
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTable(BuildContext context) {
    if (_loadingTransactions) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('No transactions found')),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
          columns: const [
            DataColumn(label: Text('S.No.')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Date & Time')),
            DataColumn(label: Text('Reason')),
            DataColumn(label: Text('Prev Bal')),
            DataColumn(label: Text('Curr Bal')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Invoice')),
            DataColumn(label: Text('Action')),
          ],
          rows: _transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            // Map backend fields roughly. Adjust keys if needed after testing.
            // Expected keys: amount, date/created_at, reason/description, prevBal/previous_balance, currBal/current_balance, status, invoice_url/url/file
            final amount = row['amount']?.toString() ?? '0.00';
            final date =
                row['created_at']?.toString() ?? row['date']?.toString() ?? '-';
            final reason =
                row['description']?.toString() ??
                row['reason']?.toString() ??
                '-';
            final prevBal =
                row['previous_balance']?.toString() ??
                row['prevBal']?.toString() ??
                '0.00';
            final currBal =
                row['current_balance']?.toString() ??
                row['currBal']?.toString() ??
                '0.00';
            final status = row['status']?.toString() ?? 'Success';
            final invoiceUrl =
                row['invoice_url']?.toString() ??
                row['url']?.toString() ??
                row['file']?.toString();
            final invoiceLabel =
                row['invoice_number']?.toString() ?? 'Download';

            return DataRow(
              cells: [
                DataCell(Text((index + 1).toString())),
                DataCell(
                  Text(
                    amount,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(Text(date)),
                DataCell(Text(reason)),
                DataCell(Text(prevBal)),
                DataCell(Text(currBal)),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  invoiceUrl != null &&
                          invoiceUrl.isNotEmpty &&
                          invoiceUrl != '-'
                      ? ElevatedButton.icon(
                          icon: const Icon(
                            Icons.download,
                            size: 14,
                            color: Colors.white,
                          ),
                          label: Text(
                            invoiceLabel,
                            style: const TextStyle(fontSize: 10),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 24),
                          ),
                          onPressed: () => _downloadInvoice(invoiceUrl),
                        )
                      : const SizedBox(),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoginActivityList(BuildContext context) {
    final activity = [
      {
        'date': '12/01/2026, 02:31:33 pm',
        'ip': '49.204.147.5',
        'device': 'Desktop, Unknown, Unknown',
      },
      {
        'date': '12/01/2026, 02:20:16 pm',
        'ip': '49.204.147.5',
        'device': 'Desktop, Unknown, Unknown',
      },
      {
        'date': '12/01/2026, 01:54:25 pm',
        'ip': '49.204.147.5',
        'device': 'Desktop, Windows, Chrome',
      },
      {
        'date': '12/01/2026, 12:48:16 pm',
        'ip': '49.204.147.5',
        'device': 'Desktop, Windows, Chrome',
      },
      {
        'date': '12/01/2026, 12:47:52 pm',
        'ip': '49.204.147.5',
        'device': 'Desktop, Windows, Chrome',
      },
      {
        'date': '12/01/2026, 11:29:22 am',
        'ip': '49.204.136.212',
        'device': 'Desktop, Windows, Chrome',
      },
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: activity.map((log) {
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: const Icon(Icons.devices, color: AppColors.primary),
                ),
                title: Text(
                  log['date']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('IP Address: ${log['ip']}'),
                    Text('Device: ${log['device']}'),
                  ],
                ),
                isThreeLine: true,
              ),
              const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EditProfileDialog(),
    );
  }
}

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _whatsappAboutController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _websiteController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _businessVertical;
  bool _isLoading = false;
  final List<String> _verticals = [
    'Hotel and Lodging',
    'Retail Service',
    'E-commerce',
    'Education',
    'Healthcare',
    'Real Estate',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _whatsappAboutController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await AuthService.getProfile();
      if (mounted) {
        setState(() {
          _whatsappAboutController.text = data['whatsAppAbout'] ?? '';
          _emailController.text = data['email'] ?? '';
          _addressController.text = data['address'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          if (_verticals.contains(data['businessVertical'])) {
            _businessVertical = data['businessVertical'];
          } else if (data['businessVertical'] != null &&
              data['businessVertical'].toString().isNotEmpty) {
            String val = data['businessVertical'].toString();
            if (!_verticals.contains(val)) {
              _verticals.add(val);
            }
            _businessVertical = val;
          } else {
            _businessVertical = _verticals.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final data = {
        'whatsAppAbout': _whatsappAboutController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'website': _websiteController.text,
        'description': _descriptionController.text,
        'businessVertical': _businessVertical,
      };
      await AuthService.updateProfile(data);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 800, // Max width for large screens
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAvatarSection(),
                              const SizedBox(width: 32),
                              Expanded(child: _buildFormSection()),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildAvatarSection(),
                              const SizedBox(height: 24),
                              _buildFormSection(),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: BorderSide(color: Colors.grey[300]!),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.primary,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ASK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'EVA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Upload'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            side: BorderSide(color: Colors.grey[300]!),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'WhatsApp About',
                  controller: _whatsappAboutController,
                  required: false,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildTextField(
                  label: 'Email',
                  controller: _emailController,
                  required: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Address',
                  controller: _addressController,
                  required: true,
                  maxLines: 3,
                  maxLength: 256,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _buildDropdownField(
                      label: 'Business Vertical',
                      value: _businessVertical,
                      items: _verticals,
                      onChanged: (val) =>
                          setState(() => _businessVertical = val),
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Website',
                      controller: _websiteController,
                      required: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Description',
            controller: _descriptionController,
            required: true,
            maxLines: 3,
            maxLength: 512,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: required ? '* ' : '',
            style: const TextStyle(color: Colors.red),
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: required
              ? (val) => val == null || val.isEmpty ? 'Required' : null
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: required ? '* ' : '',
            style: const TextStyle(color: Colors.red),
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: onChanged,
          validator: required ? (val) => val == null ? 'Required' : null : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
