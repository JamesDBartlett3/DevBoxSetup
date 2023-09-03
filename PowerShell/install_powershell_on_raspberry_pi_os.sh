# Title: install_powershell_on_raspberry_pi_os.sh
# Author: @JamesDBartlett3@techhub.social (James D. Bartlett III)
# Version: 0.0.1
# Synopsis: Installs Microsoft PowerShell Core on Raspberry Pi OS (formerly Raspbian) Linux.
# Usage: ./install_powershell_on_raspberry_pi_os.sh

# Notes: 
# This is based on a PR I submitted (https://github.com/MicrosoftDocs/PowerShell-Docs/pull/10378) to the official Microsoft docs
# for installing PowerShell on Raspberry Pi OS (https://learn.microsoft.com/en-us/powershell/scripting/install/install-raspbian),
# after discovering that those instructions did NOT work on my Raspberry Pi 4 running Raspberry Pi OS 64-bit. Sadly, my PR was 
# rejected in order to "keep it simple." Silly me for thinking that broken code is the exact opposite of "simple." I have run this 
# script successfully on a Raspberry Pi 4 Model B running Raspberry Pi OS in 64-bit kernel mode, and it should also work in 32-bit 
# mode, but I do not have a 32-bit Raspberry Pi OS installation to test it on. If you have a 32-bit Raspberry Pi OS installation, 
# please test this script and let me know if it works for you.


###################################
# Prerequisites

# Update package lists
sudo apt update

# Install dependencies
sudo apt install libssl1.1 libunwind8 -y

# Detect Raspberry Pi OS kernel mode
uname_string=$(uname -m | tail -c 3)

# 64-bit RPi OS kernel identifies as "aarch64" and 32-bit RPi OS kernel identifies as "armv7l", so...
# Take the last two characters of uname_string, replace "7l" (if it exists) with "32", and then
# assign the result (either "32" or "64") to the kernel_mode variable.
kernel_mode="${uname_string/7l/32}"

# Print detected kernel mode to the console and ask user if they wish to continue installation. If not, terminate script.
read -p "Detected kernel mode: ${kernel_mode}-bit. Do you wish to continue with the installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
	echo "PowerShell installation cancelled by user."
	exit 1
fi

###################################
# Download and extract PowerShell

# Query GitHub Releases API to get the download links for latest released version of PowerShell,
# find the link to the specific file which will be compatible with the detected Raspberry Pi OS kernel mode, 
# and assign that link to the latest_build variable
echo "Querying GitHub Releases API to get the download links for latest released version of PowerShell..."
latest_build=$(curl -sL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | jq -r ".assets[].browser_download_url" | grep "linux-arm${kernel_mode}.tar.gz")

# Download the PowerShell tar.gz file
echo "Downloading ${latest_build} file..."
wget $latest_build

# Make a folder to extract the PowerShell tar.gz file into
echo "Creating ~/powershell folder..."
mkdir ~/powershell

# Extract the PowerShell tar.gz file into the new folder
echo "Extracting ${latest_build##*/} file into ~/powershell folder..."
tar -xvf "./${latest_build##*/}" -C ~/powershell

# Use freshly installed PowerShell to create a symbolic link back to itself in /usr/bin, so user can run 'pwsh' from anywhere
echo "Creating symbolic link to PowerShell in /usr/bin..."
sudo ~/powershell/pwsh -command 'New-Item -ItemType SymbolicLink -Path "/usr/bin/pwsh" -Target "$PSHOME/pwsh" -Force'
echo $'Symbolic link created. You can now run "pwsh" to start PowerShell anywhere on this system.\nPowerShell installation complete! 😊'