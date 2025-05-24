# vhd-tools

```powershell
PS C:\> & 'J:\vhd-tools\iso2vhd.ps1' -IsoFilePath 'D:\Temp\Win11_24H2_English_x64.iso' -ImageIndex 6 -VhdFilePath 'D:\Temp\w11-pro-24h2-x64-en.vhdx'
ISO file: Win11_24H2_English_x64.iso
VHD file: w11-pro-24h2-x64-en.vhdx
Mounted ISO file: "D:\Temp\Win11_24H2_English_x64.iso".
  DriveLetter: G
  FileSystemLabel: CCCOMA_X64FRE_EN-US_DV9
  Size: 5819484160
Test the WIM file.
Create a new VHD file.

Name             : w11-pro-24h2-x64-en.vhdx
FullName         : D:\Temp\w11-pro-24h2-x64-en.vhdx
Length           : 4194304
LastWriteTimeUtc : 5/24/2025 3:25:04 PM

Mount the VHD file.
Initialize the VHD.
Create the partitions.
  EFI system partition
  Microsoft reserved partition
  Windows partition
Format the partitions.
  EFI system partition
  Windows partition
Assign a drive letter to the partitions.
  EFI system partition: H
  Windows partition: I
Expand the Windows image to the Windows partition.

LogPath : D:\Temp\w11-pro-24h2-x64-en.vhdx.expand-image.log

The new VHD to bootable.
Dismount the VHD.
The created VHD file:

Name             : w11-pro-24h2-x64-en.vhdx
FullName         : D:\Temp\w11-pro-24h2-x64-en.vhdx
Length           : 11010048000
LastWriteTimeUtc : 5/24/2025 3:27:23 PM


Number                  :
ComputerName            : TAKATANO0
Path                    : D:\Temp\w11-pro-24h2-x64-en.vhdx
VhdFormat               : VHDX
VhdType                 : Dynamic
FileSize                : 11010048000
Size                    : 137438953472
MinimumSize             : 137437921792
LogicalSectorSize       : 512
PhysicalSectorSize      : 4096
BlockSize               : 33554432
ParentPath              :
DiskIdentifier          : EC2424CC-FD06-48D3-9C18-CB442638DF68
FragmentationPercentage : 13
Alignment               : 1
Attached                : False
DiskNumber              :
IsPMEMCompatible        : False
AddressAbstractionType  : None

Dismount the ISO file.
Elapsed Time: 00:02:21
PS C:\>
```
