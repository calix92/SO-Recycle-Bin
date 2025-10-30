# 🗑️ Linux Recycle Bin — Bash Script

**Authors:** Diogo Ruivo (126498), David Cálix (125043)
---

## Overview

This project implements a simulated **recycle bin system** for Linux using Bash scripting.  
Instead of permanently deleting files, they are moved to a hidden folder (`~/.recycle_bin/`), allowing users to restore them later.

The script mimics the real behavior of a recycle bin:  
you can delete, restore, list, preview, search, or empty files safely — all through the terminal.
---

## Installation Instructions

1. Clone or download this repository.
2. Make the main script executable:
   chmod +x recycle_bin.sh

## Usage Examples - Examples 
Below are screenshots demonstrating the main functionalities of the Linux Recycle Bin system.

### Delete operation
![Delete example](screenshots/screenhot1(delete_file).png)
File successfully moved to recycle bin with unique ID.

### List view (normal mode)
![List example](screenshots/screenshot_listview_normalmode.png)
Displays all recycled files in a simple table format.

### List view (detailed mode)
![Detailed list example](screenshots/screenshot_listview_detailedmode.png)
Shows extended metadata for each recycled file: ID, size, owner, permissions, and path.

### Restore operation
![Restore example](screenshots/screenshot_restore.png)
Restores the selected file to its original location (or creates a renamed copy if it already exists).

### Search results
![Search example](screenshots/screenshot_search.png)
Search function displaying all `.txt` files currently stored in the recycle bin.

### Main Menu
![Main menu example](screenshots/screenshot_mainmenu.png)
Interactive text-based interface showing all available options such as delete, restore, search, preview, statistics, and cleanup operations.

### Verbose Mode
![Verbose mode example](screenshots/screenshot_verbose.png)
Shows detailed real-time messages for each action, including file movement, metadata extraction, and logging — ideal for debugging and transparency.

### Logging System
![Logging system example](screenshots/screenshot_logging.png)
Every operation is recorded in `recyclebin.log` with timestamps, enabling traceability and error tracking.

### Full Metadata Database
![Metadata database example](screenshots/screenshot_metadata.png)
The `metadata.db` file stores full structured information: ID, original name, path, date, size, permissions, and owner for each recycled file.

### Automated Test Suite
![Automated tests example](screenshots/screenshot_tests.png)
36 automated tests covering all functionalities — from basic deletion and restore to stress, concurrency, and error-handling scenarios.

### Performance & Robustness
![Performance example](screenshots/screenshot_performance.png)
Demonstrates stability under load: handles hundreds of files, large-size simulations, and special character names without data loss or crashes.



## Troubleshooting Guide

| Problem | Cause | Solution |
|----------|--------|-----------|
| **Permission denied** | The script isn’t executable | Run `chmod +x recycle_bin.sh` |
| **Spaces in filenames cause errors** | Missing quotes around filenames | Always use quotes: `"file name.txt"` |
| **Metadata file corrupted** | Manual edits or interrupted process | Delete `metadata.db`; it will be rebuilt automatically |
| **Restore fails** | The original folder no longer exists | The script recreates missing folders automatically |
| **Recycle bin not found** | Not initialized yet | Run `./recycle_bin.sh help` to auto-create it |
| **Quota warning shown** | Recycle bin reached size limit | Run `./recycle_bin.sh auto_cleanup` to remove old files |
| **Strange characters in names** | Locale or encoding issue | Use `LC_ALL=C` when running the script if needed |
| **Test suite not running** | Missing execution rights | Run `chmod +x test_suite.sh` before executing it |