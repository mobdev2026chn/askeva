with open('lib/screens/leads_screen.dart', 'rb') as f:
    raw = f.read()

content = raw.decode('utf-8').replace('\r\n', '\n')

# ── Fix 1: Replace _bulkUpdate implementation in leads_screen.dart ──
old_bulk_update_fn = """  void _bulkUpdate(List<LeadDto> all) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Update ${_selected.length} leads', style: AppText.poppins(size: 16, weight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 14),
          Text('Set status', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in kLeadStatuses)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    for (final id in _selected) {
                      _statusOverride[id] = s;
                    }
                    _selectMode = false;
                    _selected.clear();
                  });
                  AppNav.of(context).toast('Updated status to $s');
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: AppColors.evaGreen50, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.evaGreen200)), child: Text(s, style: AppText.poppins(size: 13, weight: FontWeight.w700, color: AppColors.evaGreenDeep))),
              ),
          ]),
        ]),
      ),
    );
  }"""

new_bulk_update_fn = """  void _bulkUpdate(List<LeadDto> all) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _BulkUpdateSheet(
            selectedCount: _selected.length,
            agents: _agentNames(),
            onApply: (status, agent) async {
              String? backendStatus;
              if (status != null) {
                backendStatus = switch (status) {
                  'New' => 'New Lead',
                  'Customer' => 'Converted',
                  _ => status,
                };
              }
              
              setState(() => _selectMode = false);
              final repo = AppScope.of(context).leads;
              final idsToUpdate = List<String>.from(_selected);
              _selected.clear();
              
              _snack('Updating ${idsToUpdate.length} leads...');
              
              for (final id in idsToUpdate) {
                final Map<String, dynamic> body = {};
                if (backendStatus != null) body['status'] = backendStatus;
                if (agent != null) body['assignedTo'] = agent;
                try {
                  await repo.updateLead(id, body);
                } catch (_) {}
              }
              
              _snack('Bulk update complete');
              _reload();
            },
          ),
        ),
      ),
    );
  }"""

if old_bulk_update_fn in content:
    content = content.replace(old_bulk_update_fn, new_bulk_update_fn, 1)
    print("leads_screen.dart _bulkUpdate replaced: OK")
else:
    print("leads_screen.dart _bulkUpdate replaced: NOT FOUND")


# ── Fix 2: Append _BulkUpdateSheet definition to the end of leads_screen.dart ──
new_sheet_class = """

class _BulkUpdateSheet extends StatefulWidget {
  final int selectedCount;
  final List<String> agents;
  final Function(String? status, String? agent) onApply;

  const _BulkUpdateSheet({
    required this.selectedCount,
    required this.agents,
    required this.onApply,
  });

  @override
  State<_BulkUpdateSheet> createState() => _BulkUpdateSheetState();
}

class _BulkUpdateSheetState extends State<_BulkUpdateSheet> {
  String? _selectedStatus;
  String? _selectedAgent;
  
  bool _statusExpanded = false;
  bool _agentExpanded = false;
  
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF9E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: AppColors.evaGreenDeep, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Bulk Update · ${widget.selectedCount} selected',
                style: AppText.poppins(size: 15.5, weight: FontWeight.w800, color: AppColors.ink),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.surface2, shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.ink4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Text('Update Status', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _statusExpanded = !_statusExpanded;
                _agentExpanded = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusExpanded ? AppColors.evaGreen : AppColors.line),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedStatus ?? 'Select Status',
                    style: AppText.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _selectedStatus == null ? AppColors.ink4 : AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _statusExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (_statusExpanded) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              maxHeight: 200,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: ['New', 'Hot', 'Warm', 'Cold', 'Customer'].map((status) {
                  final isSel = _selectedStatus == status;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedStatus = status;
                        _statusExpanded = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                      child: Text(
                        status,
                        style: AppText.poppins(
                          size: 14,
                          weight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          Text('Change Assigned To', style: AppText.poppins(size: 12.5, weight: FontWeight.w700, color: AppColors.ink3)),
          const SizedBox(height: 6),
          
          GestureDetector(
            onTap: () {
              setState(() {
                _agentExpanded = !_agentExpanded;
                _statusExpanded = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _agentExpanded ? AppColors.evaGreen : AppColors.line),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedAgent ?? 'Select Agent',
                    style: AppText.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: _selectedAgent == null ? AppColors.ink4 : AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _agentExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.ink3,
                  ),
                ],
              ),
            ),
          ),
          if (_agentExpanded) ...[
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: AppText.poppins(size: 13, color: AppColors.ink4),
                        prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.ink4),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: widget.agents.where((agent) => agent.toLowerCase().contains(_searchQuery)).map((agent) {
                        final isSel = _selectedAgent == agent;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedAgent = agent;
                              _agentExpanded = false;
                              _searchCtrl.clear();
                              _searchQuery = '';
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFFEAF9E6) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              agent,
                              style: AppText.poppins(
                                size: 13.5,
                                weight: isSel ? FontWeight.w800 : FontWeight.w600,
                                color: isSel ? AppColors.evaGreenDeep : AppColors.ink,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: AppColors.ink)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: (_selectedStatus == null && _selectedAgent == null) 
                      ? null 
                      : () {
                          Navigator.pop(context);
                          widget.onApply(_selectedStatus, _selectedAgent);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.evaGreen,
                    disabledBackgroundColor: AppColors.line,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Apply Changes', style: AppText.poppins(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
"""

content = content + new_sheet_class

with open('lib/screens/leads_screen.dart', 'wb') as f:
    f.write(content.replace('\n', '\r\n').encode('utf-8'))
print("leads_screen.dart written.")
