# Title: install_powershell_on_raspberry_pi_os.sh
# Author: @JamesDBartlett3@techhub.social (James D. Bartlett III)
# Version: 0.0.1
# Synopsis: Installs Microsoft PowerShell Core on Raspberry Pi OS (formerly Raspbian) Linux.
# Usage: ./install_powershell_on_raspberry_pi_os.sh

# Notes: 
# This is based on a PR I submitted (https://github.com/MicrosoftDocs/PowerShell-Docs/pull/10378) to the official Microsoft docs
#	for installing PowerShell on Raspberry Pi OS (https://learn.microsoft.com/en-us/powershell/scripting/install/install-raspbian),
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
kernel_mode="${uname_string/71/32}"
echo "Detected kernel mode: ${kernel_mode}-bit"

###################################
# Download and extract PowerShell

# Query GitHub Releases API to get the download links for the latest PowerShell release
# and find the specific file which will be compatible with the detected Raspberry Pi OS kernel mode
latest_build=$(curl -sL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | jq -r ".assets[].browser_download_url" | grep "linux-arm${kernel_mode}.tar.gz")

# Download the PowerShell tar.gz file
wget $latest_build

# Make a folder to extract the PowerShell tar.gz file into
mkdir ~/powershell

# Extract the PowerShell tar.gz file
tar -xvf "./${latest_build##*/}" -C ~/powershell

# Use freshly installed PowerShell to create a symbolic link back to itself in /usr/bin, so user can run 'pwsh' from anywhere
sudo ~/powershell/pwsh -command 'New-Item -ItemType SymbolicLink -Path "/usr/bin/pwsh" -Target "$PSHOME/pwsh" -Force'