#Requires -Version 7
#Requires -RunAsAdministrator

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string] $IsoFilePath,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 20)]
    [int] $ImageIndex,

    [Parameter(Mandatory=$true)]
    [string] $VhdFilePath
)

$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
$WarningPreference = [Management.Automation.ActionPreference]::Continue
$VerbosePreference = [Management.Automation.ActionPreference]::Continue
$ProgressPreference = [Management.Automation.ActionPreference]::SilentlyContinue

function Mount-IsoFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $IsoFilePath
    )

    if (-not (Test-Path -PathType Leaf -LiteralPath $IsoFilePath)) {
        throw 'Cannot find the specified ISO file "{0}".' -f $IsoFilePath
    }
    $isoVolume = Mount-DiskImage -StorageType ISO -Access ReadOnly -ImagePath $IsoFilePath -PassThru | Get-Volume
    Write-Host ('Mounted ISO file: "{0}".' -f $IsoFilePath) -ForegroundColor Cyan
    Write-Host ('  DriveLetter: {0}' -f $isoVolume.DriveLetter)
    Write-Host ('  FileSystemLabel: {0}' -f $isoVolume.FileSystemLabel)
    Write-Host ('  Size: {0}' -f $isoVolume.Size)
    return $isoVolume.DriveLetter
}

function Dismount-IsoFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $IsoFilePath
    )

    if (-not (Test-Path -PathType Leaf -LiteralPath $IsoFilePath)) {
        throw 'Cannot find the specified ISO file "{0}".' -f $IsoFilePath
    }
    Dismount-DiskImage -StorageType ISO -ImagePath $IsoFilePath | Out-Null
}

function Resolve-WindowsImageFilePath
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $DriveLetter
    )

    $wimFilePath = '{0}:\sources\install.wim' -f $DriveLetter
    if (-not (Test-Path -PathType Leaf -LiteralPath $wimFilePath)) {
        throw 'The specified ISO volume does not have "{0}".' -f $wimFilePath
    }
    return $wimFilePath
}

function Test-WimFile
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $WimFilePath,

        [Parameter(Mandatory = $true)][ValidateRange(1, 20)]
        [int] $ImageIndex
    )

    if (-not (Test-Path -PathType Leaf -LiteralPath $WimFilePath)) {
        throw 'Cannot find the specified file "{0}".' -f $WimFilePath
    }
    
    $windowsImage = Get-WindowsImage -ImagePath $WimFilePath -Index $ImageIndex
    return $windowsImage -ne $null
}

function Add-DriveLetterToPartition
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Management.Infrastructure.CimInstance] $Partition
    )

    $isDriveLetterAssigned = $false
    $attempts = 0
    $workingPartition = $Partition
    do {
        $workingPartition | Add-PartitionAccessPath -AssignDriveLetter
        $workingPartition = $workingPartition | Get-Partition
        if($workingPartition.DriveLetter -ne 0)
        {
            $isDriveLetterAssigned = $true
            break
        }

        #'Could not assigna a drive letter. Try again.'
        Get-Random -Minimum 1 -Maximum 5 | Start-Sleep
        $attempts++
    } while ($attempts -lt 20)

    if (-not $isDriveLetterAssigned) {
        throw 'Could not assign a drive letter to the partition (Type:{0}, DiskNumber:{1}, PartitionNumber:{2}, Size:{3}).' -f $Partition.Type, $Partition.DiskNumber, $Partition.PartitionNumber, $Partition.Size
    }

    return $workingPartition
}

function Set-VhdToBootable
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [char] $SystemVolumeDriveLetter,

        [Parameter(Mandatory = $true)]
        [char] $WindowsVolumeDriveLetter,

        [Parameter(Mandatory = $true)]
        [string] $LogFilePathForStandardOutput,

        [Parameter(Mandatory = $true)]
        [string] $LogFilePathForStandardError
    )

    $params = @{
        FilePath     = 'C:\Windows\System32\bcdboot.exe'
        ArgumentList = @(
            ('{0}:\Windows' -f $WindowsVolumeDriveLetter), # Specifies the location of the windows system root.
            ('/s {0}:' -f $SystemVolumeDriveLetter),       # Specifies an optional volume letter parameter to designate the target system partition where boot environment files are copied.
            '/f UEFI',                                     # Specifies the firmware type of the target system partition.
            '/v'                                           # Enables verbose mode.
        )
        RedirectStandardOutput = $LogFilePathForStandardOutput
        RedirectStandardError  = $LogFilePathForStandardError
        NoNewWindow            = $true
        Wait                   = $true
        Passthru               = $true
    }
    $result = Start-Process @params

    if ($result.ExitCode -ne 0) {
        throw 'The bcdboot.exe failed with exit code {0}.' -f $result.ExitCode
    }
}

try {
    $stopWatch = [Diagnostics.Stopwatch]::StartNew()

    Write-Host 'ISO file: ' -ForegroundColor Cyan -NoNewline
    Write-Host ([IO.Path]::GetFileName($IsoFilePath))

    Write-Host 'VHD file: ' -ForegroundColor Cyan -NoNewline
    Write-Host ([IO.Path]::GetFileName($VhdFilePath))

    $isoMountedDriveLetter = Mount-IsoFile -IsoFilePath $IsoFilePath

    Write-Host 'Test the WIM file.' -ForegroundColor Cyan
    $wimFilePath = Resolve-WindowsImageFilePath -DriveLetter $isoMountedDriveLetter
    if (-not (Test-WimFile -WimFilePath $wimFilePath -ImageIndex $ImageIndex)) {
        throw 'The specified Windows image "{0}" has not the image index {1}.' -f $wimFilePath, $ImageIndex
    }
    
    Write-Host 'Create a new VHD file.' -ForegroundColor Cyan
    $params = @{
        Path                    = $VhdFilePath
        Dynamic                 = $true
        SizeBytes               = 128GB
        BlockSizeBytes          = 32MB
        PhysicalSectorSizeBytes = 4KB
        LogicalSectorSizeBytes  = 512
    }
    $vhd = New-VHD @params
    Get-Item -LiteralPath $vhd.Path | Format-List -Property 'Name','FullName','Length','LastWriteTimeUtc'

    Write-Host 'Mount the VHD file.' -ForegroundColor Cyan
    $disk = $vhd | Mount-VHD -PassThru | Get-Disk

    Write-Host 'Initialize the VHD.' -ForegroundColor Cyan
    $disk | Initialize-Disk -PartitionStyle GPT

    # The partition type GUIDs.
    $PARTITION_SYSTEM_GUID = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    $PARTITION_MSFT_RESERVED_GUID = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    $PARTITION_BASIC_DATA_GUID = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    Write-Host 'Create the partitions.' -ForegroundColor Cyan

    Write-Host '  EFI system partition'
    $systemPartition = $disk | New-Partition -GptType $PARTITION_SYSTEM_GUID -Size 200MB

    Write-Host '  Microsoft reserved partition'
    $disk | New-Partition -GptType $PARTITION_MSFT_RESERVED_GUID -Size 16MB | Out-Null

    Write-Host '  Windows partition'
    $windowsPartition = $disk | New-Partition -GptType $PARTITION_BASIC_DATA_GUID -UseMaximumSize

    Write-Host 'Format the partitions.' -ForegroundColor Cyan

    Write-Host '  EFI system partition'
    $systemVolume = $systemPartition | Format-Volume -FileSystem 'FAT32' -AllocationUnitSize 512 -Confirm:$false -Force

    Write-Host '  Windows partition'
    $windowsVolume = $windowsPartition | Format-Volume -FileSystem 'NTFS' -AllocationUnitSize 4KB -Confirm:$false -Force

    Write-Host 'Assign a drive letter to the partitions.' -ForegroundColor Cyan

    Write-Host '  EFI system partition: ' -NoNewline
    $systemPartition = Add-DriveLetterToPartition -Partition $systemPartition

    $systemVolumeDriveLetter = (Get-Partition -Volume $systemVolume | Get-Volume).DriveLetter
    Write-Host $systemVolumeDriveLetter

    Write-Host '  Windows partition: ' -NoNewline
    $windowsPartition = Add-DriveLetterToPartition -Partition $windowsPartition

    $windowsVolumeDriveLetter = (Get-Partition -Volume $windowsVolume | Get-Volume).DriveLetter
    Write-Host $windowsVolumeDriveLetter

    Write-Host 'Expand the Windows image to the Windows partition.' -ForegroundColor Cyan
    $params = @{
        ApplyPath        = ('{0}:' -f $windowsVolumeDriveLetter)
        ImagePath        = $WimFilePath
        Index            = $ImageIndex
        #ScratchDirectory = ''
        LogPath          = $VhdFilePath + '.expand-image.log'
        LogLevel         = 'Debug'
    }
    Expand-WindowsImage @params

    Write-Host 'The new VHD to bootable.' -ForegroundColor Cyan
    $params = @{
        SystemVolumeDriveLetter      = $systemVolumeDriveLetter
        WindowsVolumeDriveLetter     = $windowsVolumeDriveLetter
        LogFilePathForStandardOutput = $VhdFilePath + '.bcdboot-stdout.log'
        LogFilePathForStandardError  = $VhdFilePath + '.bcdboot-stderr.log'
    }
    Set-VhdToBootable @params
}
finally {
    if ($vhd -and ($vhd | Get-VHD).Attached) {
        Write-Host 'Dismount the VHD.' -ForegroundColor Cyan
        $vhd | Dismount-VHD

        Write-Host 'The created VHD file:' -ForegroundColor Cyan
        Get-Item -LiteralPath $vhd.Path | Format-List -Property 'Name','FullName','Length','LastWriteTimeUtc'
        Get-VHD -Path $vhd.Path | Format-List -Property '*'
    }

    Write-Host 'Dismount the ISO file.' -ForegroundColor Cyan
    Dismount-IsoFile -IsoFilePath $IsoFilePath

    $stopWatch.Stop()
    Write-Host ('Elapsed Time: {0}' -f $stopWatch.Elapsed.toString('hh\:mm\:ss')) -ForegroundColor Cyan
}
