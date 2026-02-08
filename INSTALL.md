# Installation Guide

Complete installation instructions for XFS Resize Tool on Arch Linux with Hyprland.

## Table of Contents

- [Quick Start](#quick-start)
- [Detailed Installation](#detailed-installation)
- [Dependencies](#dependencies)
- [Installation Methods](#installation-methods)
- [Post-Installation Setup](#post-installation-setup)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

## Quick Start

For experienced users who just want to get started:

```bash
# Install dependencies
sudo pacman -S xfsprogs parted util-linux jq pv zenity

# Clone and run
git clone https://github.com/yourusername/xfs-resize-tool.git
cd xfs-resize-tool
chmod +x xfs-resize-tool.sh
./xfs-resize-tool.sh
```

## Detailed Installation

### Step 1: Check System Requirements

**Verify your system:**

```bash
# Check if you're on Arch Linux
cat /etc/os-release | grep "Arch Linux"

# Check if Hyprland is running (optional - works on X11 too)
echo $WAYLAND_DISPLAY

# Check if you have XFS partitions
lsblk -f | grep xfs
```

**Expected output:**
```
NAME        FSTYPE   LABEL  UUID                                 MOUNTPOINT
nvme0n1p2   xfs             a1b2c3d4-e5f6-7890-abcd-ef1234567890 /home
```

### Step 2: Install Dependencies

**Core dependencies:**

```bash
sudo pacman -S xfsprogs parted util-linux jq pv zenity
```

**Verification:**

```bash
# Check if all tools are installed
command -v xfsdump && echo "✅ xfsdump installed"
command -v xfsrestore && echo "✅ xfsrestore installed"
command -v parted && echo "✅ parted installed"
command -v lsblk && echo "✅ lsblk installed"
command -v jq && echo "✅ jq installed"
command -v pv && echo "✅ pv installed"
command -v zenity && echo "✅ zenity installed"
```

**All commands should show "✅ [tool] installed"**

### Step 3: Download XFS Resize Tool

**Method A: Using git (recommended)**

```bash
# Clone the repository
git clone https://github.com/yourusername/xfs-resize-tool.git

# Navigate to directory
cd xfs-resize-tool

# Check files
ls -la
```

**Method B: Download ZIP**

```bash
# Download from GitHub
wget https://github.com/yourusername/xfs-resize-tool/archive/refs/heads/main.zip

# Extract
unzip main.zip
cd xfs-resize-tool-main

# Check files
ls -la
```

**Expected files:**
```
-rwxr-xr-x  xfs-resize-tool.sh
-rw-r--r--  README.md
-rw-r--r--  IMPROVEMENTS.md
-rw-r--r--  COMPARISON.md
-rw-r--r--  LICENSE
drwxr-xr-x  screenshots/
```

### Step 4: Make Executable

```bash
chmod +x xfs-resize-tool.sh
```

**Verify permissions:**
```bash
ls -l xfs-resize-tool.sh
```

**Expected:** `-rwxr-xr-x` (executable flag set)

### Step 5: Test Run

```bash
./xfs-resize-tool.sh
```

**You should see the main menu GUI appear!**

<p align="center">
  <img src="screenshots/main-menu.png" alt="Main Menu" width="600"/>
</p>

## Dependencies

### Required Packages

| Package | Purpose | Installation |
|---------|---------|--------------|
| **xfsprogs** | XFS filesystem tools (xfsdump, xfsrestore, mkfs.xfs) | `sudo pacman -S xfsprogs` |
| **parted** | Partition manipulation | `sudo pacman -S parted` |
| **util-linux** | System utilities (lsblk) | Usually pre-installed |
| **jq** | JSON processor | `sudo pacman -S jq` |
| **pv** | Progress viewer | `sudo pacman -S pv` |
| **zenity** | GUI dialog toolkit | `sudo pacman -S zenity` |

### Optional Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **cfdisk** | User-friendly partition editor | Usually pre-installed |
| **gparted** | Alternative GUI partition editor | `sudo pacman -S gparted` |

### Checking Installed Packages

```bash
# List all required packages
pacman -Q xfsprogs parted util-linux jq pv zenity

# Check if cfdisk is available
command -v cfdisk && echo "✅ cfdisk available"
```

## Installation Methods

### Method 1: Local Directory (Quick Testing)

**Best for:** Testing, development, one-time use

```bash
# Navigate to your projects directory
cd ~/Projects

# Clone repository
git clone https://github.com/yourusername/xfs-resize-tool.git
cd xfs-resize-tool

# Make executable
chmod +x xfs-resize-tool.sh

# Run from current directory
./xfs-resize-tool.sh
```

**Pros:**
- Easy to update (`git pull`)
- No system changes
- Easy to remove

**Cons:**
- Must navigate to directory to run
- Not available system-wide

---

### Method 2: User Binary Directory (Single User)

**Best for:** Personal use on your own system

```bash
# Create user bin directory if it doesn't exist
mkdir -p ~/.local/bin

# Clone to projects directory
cd ~/Projects
git clone https://github.com/yourusername/xfs-resize-tool.git

# Create symlink to user bin
ln -s ~/Projects/xfs-resize-tool/xfs-resize-tool.sh ~/.local/bin/xfs-resize

# Ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Run from anywhere
xfs-resize
```

**Pros:**
- Available from anywhere (in your PATH)
- No sudo required for installation
- Easy to update with git pull

**Cons:**
- Only available to your user account

---

### Method 3: System-Wide Installation (All Users)

**Best for:** Multi-user systems, production use

```bash
# Clone repository
cd ~/Projects
git clone https://github.com/yourusername/xfs-resize-tool.git

# Copy to system binary directory
sudo cp ~/Projects/xfs-resize-tool/xfs-resize-tool.sh /usr/local/bin/xfs-resize

# Make executable
sudo chmod +x /usr/local/bin/xfs-resize

# Run from anywhere
xfs-resize
```

**Pros:**
- Available to all users
- In standard system PATH
- Professional installation

**Cons:**
- Requires sudo to update
- Manual updates (no git pull)

---

### Method 4: AUR Package (Coming Soon)

**Best for:** Arch Linux users who prefer pacman

```bash
# Install AUR helper if needed
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install xfs-resize-tool
yay -S xfs-resize-tool-git
```

**Pros:**
- Managed by pacman
- Automatic updates
- Dependency handling

**Cons:**
- Not yet available (coming soon)

## Post-Installation Setup

### 1. Environment Configuration

**For Wayland/Hyprland users:**

The script auto-detects Wayland, but you can verify:

```bash
echo $WAYLAND_DISPLAY
echo $XDG_RUNTIME_DIR
```

**For X11 users:**

```bash
echo $DISPLAY
```

Should show `:0` or similar.

### 2. Create Backup Directory (Recommended)

```bash
# Create a dedicated backup directory
mkdir -p ~/xfs-backups

# Or on external drive
mkdir -p /mnt/external/xfs-backups

# Set appropriate permissions
chmod 700 ~/xfs-backups
```

### 3. Add Desktop Entry (Optional)

Create a `.desktop` file for GUI launchers:

```bash
cat > ~/.local/share/applications/xfs-resize-tool.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=XFS Resize Tool
Comment=Resize XFS partitions with guided workflow
Exec=xfs-resize
Icon=drive-harddisk
Terminal=false
Categories=System;Filesystem;
Keywords=xfs;resize;partition;backup;
EOF

# Update desktop database
update-desktop-database ~/.local/share/applications
```

Now you can find "XFS Resize Tool" in your application launcher!

### 4. Configure sudo (Optional - Advanced)

To avoid entering password for each operation:

```bash
# Edit sudoers (use visudo!)
sudo visudo

# Add this line (replace USERNAME with your username):
USERNAME ALL=(ALL) NOPASSWD: /usr/bin/xfsdump, /usr/bin/xfsrestore, /usr/bin/mkfs.xfs, /usr/bin/mount, /usr/bin/umount, /usr/bin/parted, /usr/sbin/cfdisk
```

⚠️ **Warning:** This reduces security. Only do this if you understand the risks.

## Verification

### Test All Features

**1. Check main menu appears:**
```bash
./xfs-resize-tool.sh
```

Should show GUI with three options.

**2. Test dependency checker:**

The script will automatically check for missing tools on first run.

**3. Test partition detection:**

Select "Backup Only" and verify your XFS partitions appear in the list.

**4. Test backup creation (dry run):**

- Select "Backup Only"
- Choose a small XFS partition
- Cancel before final confirmation

**5. Verify state file creation:**
```bash
ls -la /tmp/xfs-resize-state.json
```

This file may not exist until you run a resize operation.

## Troubleshooting

### Issue: "Command not found"

**Problem:** Script not in PATH or not executable

**Solution:**
```bash
# Make executable
chmod +x xfs-resize-tool.sh

# Run with explicit path
./xfs-resize-tool.sh

# Or add to PATH (see installation methods)
```

---

### Issue: "Missing required tools"

**Problem:** Dependencies not installed

**Solution:**
```bash
# Install all dependencies
sudo pacman -S xfsprogs parted util-linux jq pv zenity

# Verify installation
pacman -Q xfsprogs parted util-linux jq pv zenity
```

---

### Issue: "Permission denied"

**Problem 1:** Script not executable

**Solution:**
```bash
chmod +x xfs-resize-tool.sh
```

**Problem 2:** Not running with sudo for partition operations

**Solution:**
- The script will prompt for sudo password when needed
- Ensure your user is in the `wheel` group: `groups | grep wheel`

---

### Issue: Zenity windows not appearing

**Problem:** Display variables not set

**Solution:**
```bash
# For Wayland
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# For X11
export DISPLAY=:0

# Then run
./xfs-resize-tool.sh
```

---

### Issue: "lsblk: command not found"

**Problem:** util-linux not installed

**Solution:**
```bash
sudo pacman -S util-linux
```

---

### Issue: "jq: command not found"

**Problem:** jq package not installed

**Solution:**
```bash
sudo pacman -S jq
```

---

### Issue: Git clone fails

**Problem:** git not installed or network issues

**Solution:**
```bash
# Install git
sudo pacman -S git

# If network blocked, download ZIP instead
wget https://github.com/yourusername/xfs-resize-tool/archive/refs/heads/main.zip
unzip main.zip
```

## Uninstallation

### Remove Local Installation

```bash
# If installed in local directory
cd ~/Projects
rm -rf xfs-resize-tool

# Remove user binary symlink
rm ~/.local/bin/xfs-resize
```

### Remove System-Wide Installation

```bash
# Remove from system binary directory
sudo rm /usr/local/bin/xfs-resize

# Remove desktop entry
rm ~/.local/share/applications/xfs-resize-tool.desktop
update-desktop-database ~/.local/share/applications
```

### Clean Up State Files

```bash
# Remove temporary state files
rm -f /tmp/xfs-resize-state.json
```

### Keep or Remove Backups

```bash
# List backups
ls -lh ~/xfs-backups/

# Remove backups (careful!)
# rm -rf ~/xfs-backups/
```

⚠️ **Warning:** Only remove backups if you're absolutely certain you don't need them!

## Next Steps

After installation:

1. **Read the [README.md](README.md)** for usage instructions
2. **Test on non-critical data first**
3. **Create a test partition** to practice resizing
4. **Review [IMPROVEMENTS.md](IMPROVEMENTS.md)** to understand features
5. **Check [COMPARISON.md](COMPARISON.md)** to see workflow improvements

## Getting Help

- **GitHub Issues:** [Report bugs or request features](https://github.com/yourusername/xfs-resize-tool/issues)
- **GitHub Discussions:** [Ask questions or share tips](https://github.com/yourusername/xfs-resize-tool/discussions)
- **Arch Linux Forums:** [https://bbs.archlinux.org/](https://bbs.archlinux.org/)
- **Hyprland Discord:** [https://discord.gg/hyprland](https://discord.gg/hyprland)

## Advanced Configuration

### Custom Installation Paths

```bash
# Install to custom location
INSTALL_DIR="/opt/xfs-resize-tool"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r ~/Projects/xfs-resize-tool/* "$INSTALL_DIR/"
sudo ln -s "$INSTALL_DIR/xfs-resize-tool.sh" /usr/local/bin/xfs-resize
```

### Multiple Versions

```bash
# Install stable version
git clone -b stable https://github.com/yourusername/xfs-resize-tool.git xfs-resize-stable

# Install development version
git clone -b develop https://github.com/yourusername/xfs-resize-tool.git xfs-resize-dev

# Use specific version
cd xfs-resize-stable && ./xfs-resize-tool.sh
```

### Network Installation (for remote systems)

```bash
# SSH into remote system
ssh user@remote-server

# Install on remote system
sudo pacman -S xfsprogs parted util-linux jq pv zenity
git clone https://github.com/yourusername/xfs-resize-tool.git
cd xfs-resize-tool
chmod +x xfs-resize-tool.sh

# Note: X11 forwarding or VNC needed for GUI
```

---

**Installation complete!** 🎉 You're ready to resize XFS partitions safely.
