import 'package:flutter/material.dart';
import '../../services/leads_service.dart';
import '../../widgets/app_drawer.dart';

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;
  const CustomerDetailsPage({super.key, required this.customerId});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = LeadsService.getCustomer(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Customer Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final customer = snap.data ?? {};
          final name = customer['name'] ?? 'Customer';
          final company = customer['company'] as Map<String, dynamic>?;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Company: ${company?['name'] ?? 'No Company'}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Email', customer['email']),
                    _buildInfoRow('Mobile', customer['mobile']),
                    _buildInfoRow('Source', customer['source']),
                    _buildInfoRow('Status', customer['status']),
                    _buildInfoRow(
                      'Conversion Date',
                      customer['conversionDate'],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Tickets'),
                          Tab(text: 'Appointments'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _TicketsTab(customerId: widget.customerId),
                            _AppointmentsTab(customerId: widget.customerId),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
          Text(value ?? '-', style: TextStyle(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  final String customerId;
  const _TicketsTab({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: LeadsService.getCustomerTickets(customerId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No tickets'));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ticket ID')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Priority')),
              DataColumn(label: Text('Created')),
            ],
            rows: items.map((t) {
              return DataRow(
                cells: [
                  DataCell(Text(t['ticketId'] ?? t['_id'] ?? '')),
                  DataCell(Text(t['status'] ?? '')),
                  DataCell(Text(t['priority'] ?? '')),
                  DataCell(Text(t['createdAt'] ?? '')),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _AppointmentsTab extends StatelessWidget {
  final String customerId;
  const _AppointmentsTab({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: LeadsService.getCustomerAppointments(customerId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No appointments'));
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, idx) {
            final it = items[idx];
            return ListTile(
              title: Text(it['title'] ?? 'Appointment'),
              subtitle: Text(it['date'] ?? ''),
              trailing: Text(it['status'] ?? ''),
            );
          },
        );
      },
    );
  }
}
