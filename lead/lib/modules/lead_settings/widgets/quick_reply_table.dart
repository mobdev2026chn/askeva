import 'package:flutter/material.dart';

class QuickReplyTable extends StatelessWidget {
  final List<dynamic> quickReplies;
  final Function(dynamic) onEdit;
  final Function(dynamic) onDelete;
  final VoidCallback onAdd;

  const QuickReplyTable({
    super.key,
    required this.quickReplies,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Reply Configuration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        if (quickReplies.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No quick replies configured yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else if (isMobile)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quickReplies.length,
            itemBuilder: (context, index) {
              final item = quickReplies[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: cs.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outline.withOpacity(0.5)),
                ),
                child: ListTile(
                  title: Text(
                    item['title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    item['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 22, color: cs.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    tooltip: 'Options',
                    onSelected: (value) {
                      if (value == 'edit') onEdit(item);
                      if (value == 'delete') onDelete(item);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                            SizedBox(width: 12),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outline.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
                columns: [
                  DataColumn(
                    label: Text(
                      'Title',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Message',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Actions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
                rows: quickReplies.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(
                        item['title'] ?? '',
                        style: TextStyle(color: cs.onSurface),
                      )),
                      DataCell(
                        Text(
                          item['message'] ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      DataCell(
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 22, color: cs.onSurfaceVariant),
                          padding: EdgeInsets.zero,
                          tooltip: 'Options',
                          onSelected: (value) {
                            if (value == 'edit') onEdit(item);
                            if (value == 'delete') onDelete(item);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                  SizedBox(width: 12),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outlined, size: 20, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
