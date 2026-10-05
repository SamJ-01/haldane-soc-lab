# Installs Sysmon (Microsoft Sysinternals System Monitor) with Olaf Hartong's
# community "sysmon-modular" configuration.
#
# Sysmon records detailed activity that Windows doesn't log by default:
# every process started (with its full command line), network connections,
# file creation, registry changes and more, in the
# "Microsoft-Windows-Sysmon/Operational" event log.
#
# Run on each VM as Administrator, or from the Mac with scripts/install-sysmon.sh.

$dir = "C:\Sysmon"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

# Download Sysmon and the configuration file.
Invoke-WebRequest "https://download.sysinternals.com/files/Sysmon.zip" -OutFile "$dir\Sysmon.zip" -UseBasicParsing
Expand-Archive "$dir\Sysmon.zip" -DestinationPath $dir -Force
Invoke-WebRequest "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" -OutFile "$dir\sysmonconfig.xml" -UseBasicParsing

# Install (or, if already installed, update the configuration).
if (Get-Service Sysmon64 -ErrorAction SilentlyContinue) {
    & "$dir\Sysmon64.exe" -c "$dir\sysmonconfig.xml"
} else {
    & "$dir\Sysmon64.exe" -accepteula -i "$dir\sysmonconfig.xml"
}

# Show that it's running and already logging.
Get-Service Sysmon64 | Select-Object Name, Status
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5 |
    Select-Object TimeCreated, Id
