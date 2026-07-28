import 'package:flutter/material.dart';
import 'package:askeva/widgets/app_drawer.dart';
import '../leads/widgets/add_lead_modal.dart';


class LeadPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> parsedData;
  final String rawText;
  final String? userName;
  final VoidCallback onSuccess;

  const LeadPreviewScreen({
    super.key,
    required this.parsedData,
    required this.rawText,
    this.userName,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm Lead Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      drawer: AppDrawer(name: userName),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extracted Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (parsedData['confidence'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (parsedData['confidence'] as num) > 70
                            ? Colors.green.withAlpha(30)
                            : Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${parsedData['confidence']}% Match',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: (parsedData['confidence'] as num) > 70
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.person,
                        'Name',
                        parsedData['name'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.business,
                        'Company',
                        parsedData['companyName'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.phone,
                        'Mobile',
                        parsedData['mobile'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.email,
                        'Email',
                        parsedData['email'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.badge,
                        'Position/Title',
                        parsedData['position'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.location_on,
                        'Address',
                        parsedData['address'] ?? 'N/A',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        Icons.language,
                        'Website',
                        parsedData['website'] ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Raw Text (OCR)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rawText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 80), // Spacer for bottom bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddLeadModal(
                          isFromScan: true,
                          initialAgentName: userName,
                          onSuccess: () {
                            onSuccess();
                            Navigator.pop(context);
                          },
                          lead: {
                            'name': parsedData['name'],
                            'mobile': parsedData['mobile'],
                            'email': parsedData['email'],
                            'company': {'name': parsedData['companyName']},
                            'position': parsedData['position'],
                            'address': parsedData['address'],
                            'website': parsedData['website'],
                            'rawOcrText': rawText,
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Confirm & Save Lead'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retake Photo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
