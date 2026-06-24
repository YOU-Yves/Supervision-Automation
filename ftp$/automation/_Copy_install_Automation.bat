@echo off

md C:\windows\Tools\Automation\Config
md C:\windows\Tools\Automation\Output

c:\windows\curl\curl.exe -k "sftp://supervision.youtell.cloud:8072/automation/Config/SCCM_Defender.json" -u sftpyoutell:Youtell974 -o "C:\windows\Tools\Automation\Config\SCCM_Defender.json" --ftp-create-dirs
c:\windows\curl\curl.exe -k "sftp://supervision.youtell.cloud:8072/automation/Config/SCCM_Production.json" -u sftpyoutell:Youtell974 -o "C:\windows\Tools\Automation\Config\SCCM_Production.json" --ftp-create-dirs
c:\windows\curl\curl.exe -k "sftp://supervision.youtell.cloud:8072/automation/Config/SCCM_Reboot_ByFolder.json" -u sftpyoutell:Youtell974 -o "C:\windows\Tools\Automation\Config\SCCM_Reboot_ByFolder.json" --ftp-create-dirs

exit