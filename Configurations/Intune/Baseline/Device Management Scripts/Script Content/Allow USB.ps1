# Enable USB Mass Storage
Set-ItemProperty -Path "HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 3

