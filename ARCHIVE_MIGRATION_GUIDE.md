# Archive Migration Guide

This guide explains how to implement the archive functionality in your AquaSync database and application.

## 🗄️ Database Changes Required

### 1. Run the Migration Scripts

Execute these SQL scripts in order:

```bash
# Step 1: Add archive columns to all tables
psql -h your_host -U your_username -d your_database -f add_archive_columns.sql

# Step 2: Create views for active records
psql -h your_host -U your_username -d your_database -f update_queries_for_archive.sql
```

### 2. Database Schema Changes

The following columns will be added to each table:

- `archived` (BOOLEAN, DEFAULT FALSE) - Indicates if the record has been archived
- `archived_at` (TIMESTAMP WITH TIME ZONE) - When the record was archived

**Tables affected:**
- `fish_predictions`
- `water_calculations`
- `fish_calculations`
- `compatibility_results`
- `diet_calculations`
- `fish_volume_calculations`
- `tanks`

## 🔧 Application Changes Made

### 1. Provider Updates

**LogBookProvider** (`lib/screens/logbook_provider.dart`):
- ✅ All archive methods now remove items from local list first (fixes Dismissible error)
- ✅ Database queries now filter out archived records
- ✅ Error handling restores items if database update fails

**TankProvider** (`lib/providers/tank_provider.dart`):
- ✅ `archiveTank()` method implemented
- ✅ Database queries now filter out archived records

### 2. UI Updates

**LogBook Screen** (`lib/screens/logbook.dart`):
- ✅ Delete icons changed to archive icons
- ✅ Colors changed from red to orange
- ✅ Text updated from "remove" to "archive"

**Tank Management** (`lib/screens/tank_management.dart`):
- ✅ "Delete Tank" changed to "Archive Tank"
- ✅ Dialog text updated for archiving

**Fish Selection Widget** (`lib/widgets/fish_selection_widget.dart`):
- ✅ Delete functionality changed to archive

## 📱 How It Works

### Archive Process:
1. User swipes or taps archive button
2. Item is immediately removed from UI (local list)
3. Database is updated with `archived: true` and `archived_at: timestamp`
4. If database update fails, item is restored to UI

### Data Filtering:
- All queries now include: `.or('archived.is.null,archived.eq.false')`
- This ensures only non-archived records are loaded
- Existing records (before migration) will have `archived = NULL`, which is treated as active

## 🚀 Testing the Migration

### Before Running Migration:
1. Take a database backup
2. Test the archive functionality in a development environment

### After Running Migration:
1. Verify archive columns exist: `\d fish_predictions`
2. Test archiving items in the app
3. Verify items disappear from UI but remain in database
4. Check database: `SELECT * FROM fish_predictions WHERE archived = true;`

## 🔍 Verification Queries

```sql
-- Check if archive columns exist
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'fish_predictions' 
AND column_name IN ('archived', 'archived_at');

-- Check for archived records
SELECT COUNT(*) as archived_count 
FROM fish_predictions 
WHERE archived = true;

-- Check active records
SELECT COUNT(*) as active_count 
FROM fish_predictions 
WHERE archived IS NULL OR archived = false;
```

## ⚠️ Important Notes

1. **Backup First**: Always backup your database before running migrations
2. **Existing Data**: All existing records will remain active (archived = NULL)
3. **Performance**: Indexes are created for better query performance
4. **Recovery**: Archived records can be restored by setting `archived = false`

## 🛠️ Troubleshooting

### Common Issues:

1. **Migration Fails**: Check database permissions and connection
2. **Archive Not Working**: Verify archive columns exist in database
3. **Items Still Showing**: Check if queries include archive filter
4. **Performance Issues**: Verify indexes were created properly

### Rollback (if needed):
```sql
-- Remove archive columns (CAUTION: This will lose archive data)
ALTER TABLE fish_predictions DROP COLUMN IF EXISTS archived, DROP COLUMN IF EXISTS archived_at;
-- Repeat for other tables...
```

## 📊 Benefits

1. **Data Safety**: No permanent data loss
2. **User Experience**: Smooth archiving without errors
3. **Recovery**: Ability to restore archived items
4. **Performance**: Optimized queries with proper indexing
5. **Audit Trail**: Track when items were archived
