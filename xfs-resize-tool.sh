#!/bin/bash
# XFS Resize Tool - Integrated Backup, Resize, Restore Workflow
# For Arch Linux / Hyprland with Zenity GUI

set -euo pipefail

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
export DISPLAY=${DISPLAY:-:0}

# State file to track multi-step operations
STATE_FILE="/tmp/xfs-resize-state.json"

# -------------------------
# Helper Functions
# -------------------------
error_dialog() { 
    zenity --error --text="$1" --width=400
    exit 1
}

info_dialog() { 
    zenity --info --text="$1" --width=400
}

warning_dialog() {
    zenity --warning --text="$1" --width=400
}

question_dialog() {
    zenity --question --text="$1" --width=400
}

# Save state for multi-step operations
save_state() {
    local step="$1"
    local data="$2"
    echo "{\"step\":\"$step\",\"data\":$data,\"timestamp\":\"$(date -Iseconds)\"}" > "$STATE_FILE"
}

# Load state
load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo ""
    fi
}

# Clear state
clear_state() {
    rm -f "$STATE_FILE"
}

# Check if required tools are installed
check_dependencies() {
    local missing=()
    for cmd in xfsdump xfsrestore parted lsblk jq pv; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error_dialog "Missing required tools: ${missing[*]}\n\nInstall with: sudo pacman -S xfsprogs parted jq pv"
    fi
}

# Get partition list for selection
get_partition_list() {
    mapfile -t PARTITIONS < <(lsblk -nlpo NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT | awk '$4=="part"{print $1","$2","$3","$5}')
    PART_LIST=()
    for part in "${PARTITIONS[@]}"; do
        IFS=',' read -r NAME SIZE FSTYPE MOUNT <<< "$part"
        MOUNT=${MOUNT:-"<not mounted>"}
        PART_LIST+=("$NAME" "$SIZE" "${FSTYPE:-<none>}" "$MOUNT")
    done
    echo "${PART_LIST[@]}"
}

# Get current partition size in sectors
get_partition_size() {
    local device="$1"
    parted -s "$device" unit s print | grep "^ [0-9]" | awk '{print $4}' | sed 's/s$//'
}

# Get parent disk of partition
get_parent_disk() {
    local partition="$1"
    lsblk -no PKNAME "$partition" | head -n1
}

# Unmount partition if mounted
unmount_partition() {
    local device="$1"
    local mounted_points=$(lsblk -no MOUNTPOINT "$device" | grep -v '^$' || true)
    
    if [ -n "$mounted_points" ]; then
        warning_dialog "Partition $device is currently mounted at:\n$mounted_points\n\nIt will be unmounted automatically."
        while read -r mp; do 
            sudo umount "$mp" || error_dialog "Failed to unmount $mp"
        done <<< "$mounted_points"
    fi
}

# -------------------------
# GUIDED RESIZE WORKFLOW
# -------------------------
guided_resize_workflow() {
    info_dialog "🔄 XFS Resize Wizard\n\nThis wizard will guide you through:\n1. Selecting the partition to resize\n2. Backing up your data\n3. Resizing the partition\n4. Restoring your data\n\nLet's begin!"
    
    # Step 1: Select source partition
    zenity --info --text="Step 1/5: Select Source Partition" --width=300
    
    PART_ARRAY=($(get_partition_list))
    SOURCE_DEV=$(zenity --list --title="Select Partition to Resize" \
        --column="Partition" --column="Size" --column="Filesystem" --column="Mount Point" \
        "${PART_ARRAY[@]}" \
        --text="Select the XFS partition you want to resize:" \
        --width=700 --height=400)
    
    [[ -z "$SOURCE_DEV" ]] && exit 0
    
    # Verify it's XFS
    FSTYPE=$(lsblk -no FSTYPE "$SOURCE_DEV")
    if [[ "$FSTYPE" != "xfs" ]]; then
        error_dialog "Selected partition is $FSTYPE, not XFS.\n\nThis tool only works with XFS filesystems."
    fi
    
    # Get current size info
    PARENT_DISK="/dev/$(get_parent_disk "$SOURCE_DEV")"
    CURRENT_SIZE=$(lsblk -no SIZE "$SOURCE_DEV")
    
    info_dialog "Selected: $SOURCE_DEV\nCurrent size: $CURRENT_SIZE\nParent disk: $PARENT_DISK"
    
    # Step 2: Create backup
    zenity --info --text="Step 2/5: Create Backup" --width=300
    
    # Check if partition is mounted
    MOUNTPOINT=$(lsblk -no MOUNTPOINT "$SOURCE_DEV")
    TEMP_MOUNT=""
    if [ -z "$MOUNTPOINT" ]; then
        TEMP_MOUNT="/mnt/xfs_temp_backup"
        sudo mkdir -p "$TEMP_MOUNT"
        sudo mount "$SOURCE_DEV" "$TEMP_MOUNT" || error_dialog "Failed to mount $SOURCE_DEV"
        MOUNTPOINT="$TEMP_MOUNT"
        info_dialog "Partition mounted temporarily at $MOUNTPOINT"
    fi
    
    # Select backup location
    BACKUP_FILE=$(zenity --file-selection --save --confirm-overwrite \
        --title="Select Backup File Location" \
        --filename="xfs-backup-$(date +%Y%m%d-%H%M%S).dump")
    
    [[ -z "$BACKUP_FILE" ]] && { 
        [ -n "$TEMP_MOUNT" ] && sudo umount "$TEMP_MOUNT" && sudo rmdir "$TEMP_MOUNT"
        exit 0
    }
    
    # Compression choice
    COMP_CHOICE=$(zenity --list \
        --title="Backup Compression" \
        --text="Choose backup mode:" \
        --column="Option" \
        --column="Description" \
        "Compressed" "Smaller file, slower (recommended)" \
        "Uncompressed" "Larger file, faster" \
        --width=500 --height=250)
    
    [[ -z "$COMP_CHOICE" ]] && exit 0
    
    # Confirm backup
    question_dialog "Ready to backup:\n\nSource: $SOURCE_DEV ($CURRENT_SIZE)\nDestination: $BACKUP_FILE\nMode: $COMP_CHOICE\n\nProceed?" || exit 0
    
    # Perform backup with progress
    (
        echo "10"; echo "# Creating backup..."
        if [[ "$COMP_CHOICE" == "Compressed" ]]; then
            sudo xfsdump -M media -L backup -l 0 -C -f "$BACKUP_FILE" "$MOUNTPOINT" 2>&1 | \
                while read line; do echo "50"; done
        else
            sudo xfsdump -M media -L backup -l 0 -f "$BACKUP_FILE" "$MOUNTPOINT" 2>&1 | \
                while read line; do echo "50"; done
        fi
        echo "100"; echo "# Backup complete"
    ) | zenity --progress --title="Creating Backup" --percentage=0 --auto-close --width=400
    
    # Cleanup temp mount
    if [ -n "$TEMP_MOUNT" ]; then
        sudo umount "$TEMP_MOUNT"
        sudo rmdir "$TEMP_MOUNT"
    fi
    
    # Verify backup was created
    if [ ! -f "$BACKUP_FILE" ]; then
        error_dialog "Backup file was not created successfully!"
    fi
    
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    info_dialog "✅ Backup created successfully!\n\nFile: $BACKUP_FILE\nSize: $BACKUP_SIZE"
    
    # Save state
    save_state "backup_complete" "{\"source\":\"$SOURCE_DEV\",\"backup\":\"$BACKUP_FILE\",\"parent_disk\":\"$PARENT_DISK\"}"
    
    # Step 3: Resize partition
    zenity --info --text="Step 3/5: Resize Partition" --width=300
    
    warning_dialog "⚠️  IMPORTANT:\n\nYou will now use a partitioning tool to resize $SOURCE_DEV.\n\nNOTES:\n• The partition will be unmounted\n• You can shrink or grow the partition\n• After resizing, you MUST format it as XFS\n• Your data is safe in the backup\n\nClick OK to open the partitioning tool."
    
    # Unmount the partition
    unmount_partition "$SOURCE_DEV"
    
    # Launch interactive partitioning tool
    PART_TOOL=$(zenity --list \
        --title="Choose Partitioning Tool" \
        --text="Select your preferred tool:" \
        --column="Tool" --column="Description" \
        "cfdisk" "Interactive, user-friendly (recommended)" \
        "parted" "Command-line, advanced" \
        --width=500 --height=250)
    
    if [[ "$PART_TOOL" == "cfdisk" ]]; then
        sudo cfdisk "$PARENT_DISK"
    else
        info_dialog "Opening parted for $PARENT_DISK\n\nCommands:\n• print - show partitions\n• resizepart NUMBER END - resize partition\n• quit - exit when done"
        sudo parted "$PARENT_DISK"
    fi
    
    # Verify partition still exists
    if ! lsblk "$SOURCE_DEV" &>/dev/null; then
        error_dialog "Partition $SOURCE_DEV no longer exists!\n\nResize operation may have failed or partition was deleted."
    fi
    
    NEW_SIZE=$(lsblk -no SIZE "$SOURCE_DEV")
    info_dialog "Partition resized!\n\nNew size: $NEW_SIZE\n(Was: $CURRENT_SIZE)"
    
    # Step 4: Format as XFS
    zenity --info --text="Step 4/5: Format as XFS" --width=300
    
    RESPONSE=$(zenity --entry --title="FINAL CONFIRMATION" \
        --text="⚠️  DESTROYING DATA ON $SOURCE_DEV\n\nThe partition will now be formatted as XFS.\nYour data is safely backed up at:\n$BACKUP_FILE\n\nType YES to format:" \
        --width=500)
    
    if [[ "${RESPONSE^^}" != "YES" ]]; then
        warning_dialog "Format cancelled.\n\nYour backup is at: $BACKUP_FILE\n\nYou can manually format and restore later."
        exit 0
    fi
    
    # Format the partition
    (
        echo "30"; echo "# Formatting partition as XFS..."
        sudo mkfs.xfs -f "$SOURCE_DEV" 2>&1 | while read line; do echo "70"; done
        echo "100"; echo "# Format complete"
    ) | zenity --progress --title="Formatting Partition" --percentage=0 --auto-close --width=400
    
    info_dialog "✅ Partition formatted as XFS!"
    
    # Step 5: Restore backup
    zenity --info --text="Step 5/5: Restore Backup" --width=300
    
    question_dialog "Ready to restore your data to the resized partition?\n\nSource: $BACKUP_FILE\nTarget: $SOURCE_DEV (New size: $NEW_SIZE)" || {
        info_dialog "Restore skipped.\n\nYou can restore manually later using:\nsudo xfsrestore -f \"$BACKUP_FILE\" <mount_point>"
        exit 0
    }
    
    # Mount and restore
    RESTORE_MOUNT="/mnt/xfs_restore"
    sudo mkdir -p "$RESTORE_MOUNT"
    sudo mount "$SOURCE_DEV" "$RESTORE_MOUNT" || error_dialog "Failed to mount $SOURCE_DEV"
    
    (
        echo "20"; echo "# Restoring data..."
        sudo xfsrestore -f "$BACKUP_FILE" "$RESTORE_MOUNT" 2>&1 | while read line; do echo "80"; done
        echo "100"; echo "# Restore complete"
    ) | zenity --progress --title="Restoring Data" --percentage=0 --auto-close --width=400
    
    sudo umount "$RESTORE_MOUNT"
    sudo rmdir "$RESTORE_MOUNT"
    
    clear_state
    
    info_dialog "🎉 SUCCESS!\n\nYour XFS partition has been resized!\n\nOld size: $CURRENT_SIZE\nNew size: $NEW_SIZE\nPartition: $SOURCE_DEV\n\nBackup saved at:\n$BACKUP_FILE\n\n(You can delete the backup once you verify everything works)"
}

# -------------------------
# STANDALONE BACKUP
# -------------------------
standalone_backup() {
    PART_ARRAY=($(get_partition_list))
    SOURCE_DEV=$(zenity --list --title="Select Partition to Backup" \
        --column="Partition" --column="Size" --column="Filesystem" --column="Mount Point" \
        "${PART_ARRAY[@]}" \
        --text="Select the XFS partition to backup:" \
        --width=700 --height=400)
    
    [[ -z "$SOURCE_DEV" ]] && exit 0
    
    # Verify it's XFS
    FSTYPE=$(lsblk -no FSTYPE "$SOURCE_DEV")
    if [[ "$FSTYPE" != "xfs" ]]; then
        error_dialog "Selected partition is $FSTYPE, not XFS."
    fi
    
    # Check if mounted
    MOUNTPOINT=$(lsblk -no MOUNTPOINT "$SOURCE_DEV")
    TEMP_MOUNT=""
    if [ -z "$MOUNTPOINT" ]; then
        TEMP_MOUNT="/mnt/xfs_temp_backup"
        sudo mkdir -p "$TEMP_MOUNT"
        sudo mount "$SOURCE_DEV" "$TEMP_MOUNT" || error_dialog "Failed to mount $SOURCE_DEV"
        MOUNTPOINT="$TEMP_MOUNT"
    fi
    
    # Select backup location
    BACKUP_FILE=$(zenity --file-selection --save --confirm-overwrite \
        --title="Select Backup File Location" \
        --filename="xfs-backup-$(date +%Y%m%d-%H%M%S).dump")
    
    [[ -z "$BACKUP_FILE" ]] && exit 0
    
    # Compression
    COMP_CHOICE=$(zenity --list \
        --title="Backup Mode" \
        --column="Option" \
        "Compressed (recommended)" \
        "Uncompressed")
    
    [[ -z "$COMP_CHOICE" ]] && exit 0
    
    # Perform backup
    (
        echo "10"; echo "# Creating backup..."
        if [[ "$COMP_CHOICE" == "Compressed (recommended)" ]]; then
            sudo xfsdump -M media -L backup -l 0 -C -f "$BACKUP_FILE" "$MOUNTPOINT" 2>&1 | \
                while read line; do echo "80"; done
        else
            sudo xfsdump -M media -L backup -l 0 -f "$BACKUP_FILE" "$MOUNTPOINT" 2>&1 | \
                while read line; do echo "80"; done
        fi
        echo "100"
    ) | zenity --progress --title="Backing Up" --percentage=0 --auto-close --width=400
    
    [ -n "$TEMP_MOUNT" ] && sudo umount "$TEMP_MOUNT" && sudo rmdir "$TEMP_MOUNT"
    
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    info_dialog "✅ Backup complete!\n\nFile: $BACKUP_FILE\nSize: $BACKUP_SIZE"
}

# -------------------------
# STANDALONE RESTORE
# -------------------------
standalone_restore() {
    # Select backup file
    BACKUP_FILE=$(zenity --file-selection --title="Select XFS Backup File")
    [[ -z "$BACKUP_FILE" ]] && exit 0
    [ -f "$BACKUP_FILE" ] || error_dialog "Selected file does not exist"
    
    # Select target partition
    PART_ARRAY=($(get_partition_list))
    TARGET_DEV=$(zenity --list --title="Select Target Partition" \
        --column="Partition" --column="Size" --column="Filesystem" --column="Mount Point" \
        "${PART_ARRAY[@]}" \
        --text="⚠️  Select target partition for restore:" \
        --width=700 --height=400)
    
    [[ -z "$TARGET_DEV" ]] && exit 0
    
    # Verify it's XFS
    FSTYPE=$(lsblk -no FSTYPE "$TARGET_DEV")
    if [[ "$FSTYPE" != "xfs" ]]; then
        warning_dialog "Target partition is $FSTYPE, not XFS.\n\nIt must be formatted as XFS first!"
        if question_dialog "Format $TARGET_DEV as XFS now?"; then
            unmount_partition "$TARGET_DEV"
            sudo mkfs.xfs -f "$TARGET_DEV" || error_dialog "Format failed"
            info_dialog "Partition formatted as XFS"
        else
            exit 0
        fi
    fi
    
    # Unmount if needed
    unmount_partition "$TARGET_DEV"
    
    # Final confirmation
    RESPONSE=$(zenity --entry --title="FINAL CONFIRMATION" \
        --text="⚠️  ALL DATA ON $TARGET_DEV WILL BE REPLACED\n\nBackup: $BACKUP_FILE\nTarget: $TARGET_DEV\n\nType YES to continue:" \
        --width=500)
    
    [[ "${RESPONSE^^}" != "YES" ]] && exit 0
    
    # Mount and restore
    RESTORE_MOUNT="/mnt/xfs_restore"
    sudo mkdir -p "$RESTORE_MOUNT"
    sudo mount "$TARGET_DEV" "$RESTORE_MOUNT" || error_dialog "Failed to mount $TARGET_DEV"
    
    (
        echo "20"; echo "# Restoring backup..."
        sudo xfsrestore -f "$BACKUP_FILE" "$RESTORE_MOUNT" 2>&1 | while read line; do echo "80"; done
        echo "100"
    ) | zenity --progress --title="Restoring Data" --percentage=0 --auto-close --width=400
    
    sudo umount "$RESTORE_MOUNT"
    sudo rmdir "$RESTORE_MOUNT"
    
    info_dialog "✅ Restore complete!\n\nData from $BACKUP_FILE\nhas been restored to $TARGET_DEV"
}

# -------------------------
# MAIN MENU
# -------------------------
check_dependencies

# Check for pending state
STATE=$(load_state)
if [ -n "$STATE" ]; then
    STEP=$(echo "$STATE" | jq -r '.step')
    if question_dialog "🔄 Incomplete Operation Detected\n\nA previous resize operation was not completed.\n\nStep: $STEP\n\nDo you want to continue where you left off?"; then
        # Could implement resume logic here
        clear_state
        info_dialog "State cleared. Starting fresh."
    else
        clear_state
    fi
fi

MODE=$(zenity --list \
    --title="XFS Tool" \
    --text="Select an operation:" \
    --column="Option" --column="Description" \
    "Resize XFS Partition" "Guided backup → resize → restore workflow" \
    "Backup Only" "Create a standalone backup" \
    "Restore Only" "Restore from existing backup" \
    --width=600 --height=350)

[[ -z "$MODE" ]] && exit 0

case "$MODE" in
    "Resize XFS Partition")
        guided_resize_workflow
        ;;
    "Backup Only")
        standalone_backup
        ;;
    "Restore Only")
        standalone_restore
        ;;
esac
