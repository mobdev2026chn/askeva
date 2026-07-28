# Implementation Summary: Import & Bulk Actions

## Overview
Implemented a multi-step CSV Import Wizard and Bulk Action (Delete/Export) Selection Mode for Leads.

## Changes

### Backend (`backend/controller/leadsController.js`, `backend/routes/leads.js`)
- **Import API**: Updated `importLeads` to accept `checkMobile`, `checkEmail`, `checkName` flags for duplicate detection. Skips duplicates if found.
- **Export API**: Updated `exportLeads` to accept `ids` query parameter for filtering exports.
- **Bulk Delete API**: Added `POST /api/leads/bulk-delete` to delete multiple leads by ID.

### Frontend Service (`lead/lib/services/leads_service.dart`)
- **importLeads**: Updated to send duplicate detection flags.
- **getExportUrl**: Added method to generate export URL with optional ID list.
- **deleteLeads**: Added method to call bulk delete API.

### Frontend UI

#### `ImportLeadsModal` (`lead/lib/modules/leads/widgets/import_leads_modal.dart`)
- Created a 4-step wizard:
    1.  **Upload File**: File picker for CSV.
    2.  **Map Fields**: Information about automatic mapping.
    3.  **Preview & Handle Duplicates**: Checkboxes for Mobile, Email, Name.
    4.  **Import**: Progress and Result summary (Imported vs Skipped).

#### `LeadsPage` (`lead/lib/modules/leads/leads_page.dart`)
- **Selection Mode**: Added "Delete" and "Export" icons to toolbar.
    - Clicking them enters Selection Mode (Checkboxes appear).
    - User selects leads.
    - "Confirm" button in FAB performs the action.
- **Import**: "Import" icon opens the new `ImportLeadsModal`.
