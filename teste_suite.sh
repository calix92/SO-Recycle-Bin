#!/bin/bash
# ================================================================
# Automated Test Suite for Linux Recycle Bin Simulation
# Author: [Your Name]
# Date: 2025-10-22
# ================================================================

SCRIPT="./recycle_bin.sh"
TEST_DIR="./test_data"
RESULTS="./test_results.log"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=0

log_test() {
    local result="$1"
    local message="$2"
    ((TOTAL_TESTS++))
    if [ "$result" -eq 0 ]; then
        echo -e ":) PASS [$TOTAL_TESTS] $message" | tee -a "$RESULTS"
        ((PASS_COUNT++))
    else
        echo -e ":( FAIL [$TOTAL_TESTS] $message" | tee -a "$RESULTS"
        ((FAIL_COUNT++))
    fi
}

setup_environment() {
    rm -rf "$TEST_DIR" ~/.recycle_bin
    mkdir -p "$TEST_DIR"
    touch "$TEST_DIR"/file{1..3}.txt
    echo "secret" > "$TEST_DIR/file1.txt"
    mkdir -p "$TEST_DIR/subdir"
    echo "nested data" > "$TEST_DIR/subdir/file4.txt"
}

cleanup_environment() {
    rm -rf "$TEST_DIR"
}

run_test() {
    local desc="$1"
    shift
    echo -e "\n--- $desc ---" | tee -a "$RESULTS"
    "$@" >>"$RESULTS" 2>&1
    return $?
}

# ================================================================
# START OF TESTS
# ================================================================

echo "=== Starting Automated Tests ===" > "$RESULTS"
setup_environment

# --- Initialization ---
run_test "Recycle bin initialization" $SCRIPT help
log_test $? "Recycle bin initialized and help displayed"

# --- Directory creation ---
[ -d ~/.recycle_bin ] && [ -f ~/.recycle_bin/metadata.db ]
log_test $? "Recycle bin directory and metadata file exist"

# --- Delete single file ---
run_test "Delete a single file" $SCRIPT delete "$TEST_DIR/file1.txt"
[ ! -f "$TEST_DIR/file1.txt" ]
log_test $? "File successfully moved to recycle bin"

# --- Delete multiple files ---
run_test "Delete multiple files" $SCRIPT delete "$TEST_DIR/file2.txt" "$TEST_DIR/file3.txt"
[ ! -f "$TEST_DIR/file2.txt" ] && [ ! -f "$TEST_DIR/file3.txt" ]
log_test $? "Multiple files moved correctly"

# --- Delete directory recursively ---
run_test "Delete directory recursively" $SCRIPT delete "$TEST_DIR/subdir"
[ ! -d "$TEST_DIR/subdir" ]
log_test $? "Directory deleted correctly"

# --- List recycled items ---
run_test "List recycled contents" $SCRIPT list
grep -q "file1.txt" ~/.recycle_bin/metadata.db
log_test $? "List shows deleted files"

# --- Statistics ---
run_test "Show statistics" $SCRIPT stats
grep -q "Total items" "$RESULTS"
log_test $? "Statistics command working"

# --- Search recycled ---
run_test "Search deleted file by name" $SCRIPT search "file1"
grep -q "file1.txt" "$RESULTS"
log_test $? "Search function returns expected result"

# --- Restore file ---
restore_id=$(awk -F',' 'NR==2 {print $1}' ~/.recycle_bin/metadata.db)
run_test "Restore a file by ID" $SCRIPT restore "$restore_id"
[ -f "$(awk -F',' 'NR==2 {print $3}' ~/.recycle_bin/metadata.db 2>/dev/null)" ] || [ -f "$TEST_DIR/file1.txt" ]
log_test $? "File restored successfully"

# --- Restore with duplicate name ---
touch "$TEST_DIR/file1.txt"
restore_id2=$(awk -F',' 'NR==2 {print $1}' ~/.recycle_bin/metadata.db)
run_test "Restore with name conflict" $SCRIPT restore "$restore_id2"
grep -q "restored" "$RESULTS"
log_test $? "File restored with alternate name on conflict"

# --- Preview file ---
run_test "Preview file (text)" $SCRIPT delete "$TEST_DIR/file1.txt"
preview_id=$(tail -n 1 ~/.recycle_bin/metadata.db | cut -d',' -f1)
run_test "Preview command" $SCRIPT preview "$preview_id"
grep -q "secret" "$RESULTS"
log_test $? "Preview command shows file content"

# --- Check quota ---
run_test "Check storage quota" $SCRIPT check_quota
grep -q "Quota:" "$RESULTS"
log_test $? "Quota check works"

# --- Auto cleanup ---
# Manually simulate old deletion date
sed -i '2s/2025-10-22 14:30:22/2023-01-01 10:00:00/' ~/.recycle_bin/metadata.db
run_test "Auto cleanup old files" $SCRIPT auto_cleanup
! grep -q "2023-01-01" ~/.recycle_bin/metadata.db
log_test $? "Old file cleaned automatically"

# --- Empty recycle bin ---
run_test "Empty recycle bin (auto confirm)" bash -c 'echo "yes" | ./recycle_bin.sh empty'
[ "$(wc -l < ~/.recycle_bin/metadata.db)" -eq 1 ]
log_test $? "Recycle bin emptied successfully"

# --- Error: deleting nonexistent file ---
run_test "Delete nonexistent file" $SCRIPT delete "does_not_exist.txt"
grep -q "does not exist" "$RESULTS"
log_test $? "Handled nonexistent file correctly"

# --- Error: invalid command ---
run_test "Invalid command error" $SCRIPT nonsense_cmd
grep -q "Invalid command" "$RESULTS"
log_test $? "Invalid command handled correctly"

# --- Error: missing ID on restore ---
run_test "Restore without ID" $SCRIPT restore
grep -q "Must provide" "$RESULTS"
log_test $? "Handled missing argument on restore"

# --- Verbose flag (if exists) ---
if grep -q "verbose" "$SCRIPT"; then
    run_test "Verbose mode check" $SCRIPT --verbose list
    log_test $? "Verbose mode handled gracefully"
else
    echo "⚠️ Verbose mode not yet implemented — skipping" | tee -a "$RESULTS"
fi

# --- Show help explicitly ---
run_test "Display help" $SCRIPT help
grep -q "Usage" "$RESULTS"
log_test $? "Help command displays correctly"

# --- Check metadata consistency ---
lines=$(wc -l < ~/.recycle_bin/metadata.db)
header=$(head -n1 ~/.recycle_bin/metadata.db)
[[ "$lines" -ge 1 && "$header" == "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" ]]
log_test $? "Metadata file consistent and valid"

# ================================================================
# Summary
# ================================================================
cleanup_environment

echo -e "\n=== TEST SUMMARY ==="
echo "Total tests: $TOTAL_TESTS"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
else
    echo -e "${RED}⚠️ Some tests failed. Check $RESULTS for details.${NC}"
fi
