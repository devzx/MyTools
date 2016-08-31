Function Get-MTSystemInfo
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Position=0,
                   Mandatory=$true,
                   ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$ComputerName,


        [Switch]$LogErrors
    )
    BEGIN
    {
        if ($LogErrors)
        {
            $LogName = ErrorLog
        }

    }
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            try
            {
                $Worked = $True
                $BIOS = Get-WmiObject -Class Win32_BIOS `
                                      -ComputerName $Computer `
                                      -ErrorAction Stop
            }
            catch
            {
                
                $Worked = $false
                Write-Warning "Failed to contact $Computer"
                Write-Warning "$_"
                if ($LogErrors)
                {
                    if (-not (Test-Path (Split-Path -Parent $LogName)))
                    {
                        Write-Verbose "Parent folder not found. Creating..."
                        New-Item -ItemType Directory -Path (Split-Path -Parent $LogName) | Out-Null
                    }
                Write-Warning "Error log written to $LogName"
                $LogTimeStamp = 'dd/MM/yyyy HH\:mm\:ss'
                "$((Get-Date).ToString($LogTimeStamp)) Failed to contact $($Computer.Toupper())" | Out-File -FilePath $LogName -Append
                }
            }
            if ($Worked)
            {
                $OS = Get-WmiObject -Class Win32_OperatingSystem `
                                    -ComputerName $Computer
                $CS = Get-WmiObject -Class Win32_ComputerSystem `
                                    -ComputerName $Computer
                $Domain = Switch ($CS.PartOfDomain)
                                 {
                                 $true {'Yes'}
                                 $false{'No'}
                                 }
                 $AdminStatus = switch($CS.AdminPasswordStatus)
                            {
                                0 {'Disabled'}
                                1 {'Enabled'}
                                2 {'Not Implemented'}
                                3 {'Unknown'}
                            }
                $Props = @{
                            'ComputerName'=$CS.__Server;
                            'Manufacturer'=$CS.Manufacturer;
                            'ModelNumber'=$CS.Model;
                            'DomainMember'=$Domain;
                            'Domain'=$CS.Workgroup
                            'SerialNumber'=$BIOS.SerialNumber;
                            'OSInstallDate'=($OS.ConvertToDateTime($OS.InstallDate));
                            'Version'=$OS.Version;
                            'SPMajorVersion'=$OS.ServicePackMajorVersion;
                            'SPMinorVersion'=$OS.ServicePackMinorVersion;
                            'AdminPassword'=$AdminStatus
                          }
                $Obj = New-Object -TypeName PSObject -Property $Props
                $Obj.PSObject.TypeNames.Insert(0, 'MyTools.SystemInfo')
                Write-Output $Obj
            }
        }
    }
    END
    {
    }
}
Function Set-MTLyncOnline
{
<#
.SYNOPSIS
The 'I'm at my workstation and haven't left the building 20 minutes before my shift is supposed to end' cmdlet.
.DESCRIPTION
The purpose of this cmdlet is to close Lync when your shift ends and then re-open Lync to show you as Online and not as Away.
Hopefully this will dispel any doubts your superiors may have as to your whereabouts ;)
.PARAMETER SHIFT
Enter the shift you are working on: 'Early' 'Mid' 'Late'.
.EXAMPLE
Set-MTLyncOnline -Shift Late
#>
    [Cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   HelpMessage='Enter a shift')]
        [ValidateSet('Early','Mid','Late','Test')]
        [String]$Shift
    )

    try
    {
        $Worked = $true
        $Lync = Get-Process -Name Lync -ErrorAction Stop | Select-Object -ExpandProperty Path
        


    }
    catch
    {
        $Worked = $false
        Write-Warning $_.Exception.Message
        Write-Warning 'Lync not running. Please start Lync and run the script again.'

    }
    
    if ($Worked)
    {
        
        $Username = Read-Host -Prompt 'Enter your user name'
        $Domain = $env:USERDNSDOMAIN
        $UserPC = Join-Path -Path $Domain -ChildPath $Username
        $Password = Read-Host -Prompt 'Enter your password' -AsSecureString
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential `
                                 -ArgumentList $UserPC,$Password
        
        $CurrentTime = Get-Date

        Write-Verbose "$Shift shift was selected"
        $ShiftEnd = switch ($Shift)
                    {
                        'Early' { Get-Date -Hour 16 -Minute 30 -Second 0 }
                        'Mid'   { Get-Date -Hour 17 -Minute 30 -Second 0 }
                        'Late'  { Get-Date -Hour 19 -Minute 0  -Second 0 } 
                        'Test'  { (Get-Date).AddSeconds(5) }
                    }
        Write-Verbose "Shift ends at $($ShiftEnd.ToString('dd/MM/yyyy HH\:mm\:ss'))"

        
        while ($CurrentTime -le $ShiftEnd)
        {
            $Remaining = "{0:hh\:mm\:ss}" -f ($ShiftEnd - $CurrentTime) #Formats the time in hours minutes and seconds
            $Time = @{
                        'Time remaining'=$Remaining
                      }
            
            $Obj = New-Object -TypeName PSObject -Property $Time
            $Obj.PSObject.TypeNames.Insert(0, 'MyTools.LyncOnline')
            Write-Output $Obj
            
            Remove-Variable -Name CurrentTime
            $CurrentTime = Get-Date
            Start-Sleep -Seconds 1
        }

        Write-Verbose 'Stopping Lync'
        Get-Process -Name Lync | Stop-Process -Force
        Start-Sleep -Seconds 5
        try
        {
            Write-Verbose 'Starting Lync'
            Start-Process -FilePath $Lync -Credential $Credential
        }
        catch
        {
            Write-Warning "$_"
            Write-Warning 'Invalid credentials entered. Unable to restart Lync'
        }
    }
}
Function Get-MTVolumeInfo
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName,

        [switch]$LogErrors

        
    
    )
    BEGIN
    {
        if ($LogErrors)
        {
            $LogName = ErrorLog
        }
    }
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            $Volumes = Get-WmiObject -Class Win32_Volume `
                                     -Filter 'DriveType = 3' `
                                     -ComputerName $Computer
            foreach ($Volume in $Volumes)
            {
                $Props = @{
                           'ComputerName'=$Volume.__Server;
                           'Drive'=$Volume.Name;
                           'FreeSpace'=$Volume.FreeSpace;
                           'Size'=$Volume.Capacity
                          }
                $Obj = New-Object -TypeName PSObject -Property $Props
                $Obj.PSObject.TypeNames.Insert(0,'MyTools.VolumeInfo')
                Write-Output $Obj
            }
        }   
    }
    END
    {}



}
Function Get-MTServiceProcessInfo
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Position=0,
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [string[]]$ComputerName
    )
    BEGIN{}
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            $Services = Get-WmiObject -Class Win32_Service `
                                       -Filter 'State = "Running"'
            foreach ($Service in $Services)
            {
                $Process = Get-WmiObject -Class Win32_Process `
                                         -Filter "ProcessID = '$($Service.ProcessId)'"
                $Props = @{
                            'ComputerName'=$Service.__Server;
                            'ThreadCount'=$Process.ThreadCount;
                            'VMSize'=$Process.VM;
                            'ProcessName'=$Process.ProcessName;
                            'Name'=$Service.Name;
                            'PeakPageFile'=$Process.PeakPageFileUsage;
                            'DisplayName'=$Service.DisplayName
                            }
                $Obj = New-Object -TypeName PSObject -Property $Props
                $Obj.PSObject.TypeNames.Insert(0,'MyTools.ServiceProcessInfo')
                Write-Output $Obj
            }
        }
    }
    END{}
}

Function ErrorLog
{
    $Path = Join-Path -Path $env:TEMP -ChildPath "MTLog" | Join-Path -ChildPath "$((Get-Date).ToString('HHmmss')).txt"
    return $Path
}

Export-ModuleMember -Function Get-MTServiceProcessInfo, Get-MTSystemInfo, Get-MTVolumeInfo, Set-MTLyncOnline