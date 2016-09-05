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
            $ErrorLog = ErrorLog
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
                    TestErrorLogParentExist($ErrorLog)

                    Write-Warning "Error log written to $ErrorLog"
                    $LogTimeStamp = 'dd/MM/yyyy HH\:mm\:ss'
                    "$((Get-Date).ToString($LogTimeStamp)) Failed to contact $($Computer.Toupper())" | Out-File -FilePath $ErrorLog -Append
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
                            $true  {'Yes'}
                            $false {'No'}
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
                            'Domain'=$CS.Domain;
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
    {}
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
            $ErrorLog = ErrorLog
        }
    }
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            try
            {
                $Worked = $true
                $Volumes = Get-WmiObject -Class Win32_Volume `
                                         -Filter 'DriveType = 3' `
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
                    TestErrorLogParentExist($ErrorLog)

                    Write-Warning "Error log written to $ErrorLog"
                    $LogTimeStamp = 'dd/MM/yyyy HH\:mm\:ss'
                    "$((Get-Date).ToString($LogTimeStamp)) Failed to contact $($Computer.Toupper())" | Out-File -FilePath $ErrorLog -Append
                }
            }
            if ($Worked)
            {
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
        [string[]]$ComputerName,

        [switch]$LogErros
    )
    BEGIN
    {
        if ($LogErros)
        {
            $ErrorLog = ErrorLog
        }
    }
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            try
            {
                $Worked = $true
                $Services = Get-WmiObject -Class Win32_Service `
                                           -Filter 'State = "Running"' `
                                           -ComputerName $Computer `
                                           -ErrorAction Stop
            }
            catch
            {
                $Worked = $false
                Write-Warning "Failed to contact $Computer"
                Write-Warning "$_"
                
                if ($ErrorLog)
                {
                    TestErrorLogParentExist($ErrorLog)
                    Write-Warning "Error log written to $ErrorLog"
                    $LogTimeStamp = 'dd/MM/yyyy HH\:mm\:ss'
                    "$((Get-Date).ToString($LogTimeStamp)) Failed to contact $($Computer.Toupper())" | Out-File -FilePath $ErrorLog -Append
                } 
            }

            if ($Worked)
            {
                foreach ($Service in $Services)
                {
                    $Process = Get-WmiObject -Class Win32_Process `
                                             -Filter "ProcessID = '$($Service.ProcessId)'" `
                                             -ComputerName $Computer
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
    }
    END{}
}
Function Get-MTRemoteSMBShare
{
    [Cmdletbinding()]
    Param
    (
        [Parameter(Mandatory=$True,
                   ValueFromPipeline=$True)]
        [Alias('HostName')]
        [ValidateCount(1,5)]
        [string[]]$ComputerName,

        [switch]$LogErrors
    )

    BEGIN
    {
        if ($LogErrors)
        {
            $ErrorLog = ErrorLog
        }
    }
    PROCESS
    {
        foreach ($Computer in $ComputerName)
        {
            try
            {
                $Worked = $True
                $Shares = Invoke-Command -ComputerName $Computer `
                                         -ScriptBlock `
                                          { 
                                              Get-SmbShare
                                          }`
                                         -ErrorAction Stop
            }
            catch
            {
                $Err = $_
                $Worked = $False
                Write-Warning "Failed to contact $Computer"
                Write-Warning $Err.Exception.Message
                if ($ErrorLog)
                {
                    TestErrorLogParentExist($ErrorLog)
                    Write-Warning "Error log written to $ErrorLog"
                    $LogTimeStamp = 'dd/MM/yyyy HH\:mm\:ss'
                    "$((Get-Date).ToString($LogTimeStamp)) Failed to contact $($Computer.Toupper())" | Out-File -FilePath $ErrorLog -Append
                }
            }
            if($Worked)
            {
                foreach ($Share in $Shares)
                {
                    $Props = @{
                                  'ComputerName'=$Share.PSComputerName;
                                  'Description'=$Share.Description;
                                  'Name'=$Share.Name;
                                  'Path'=$Share.Path
                              }
                    $Obj = New-Object -TypeName PSObject -Property $Props
                    $Obj.PSObject.Typenames.Insert(0, 'MyTools.RemoteSMBShare')
                    Write-Output $Obj
                }
            }
        }
    }
    END{}
}
##PRIVATE FUNCTIONS##
Function ErrorLog
{
    #Returns a path name to be used for an error logging file
    $Path = Join-Path -Path $env:TEMP -ChildPath "MTLog" | Join-Path -ChildPath "$((Get-Date).ToString('HHmmss')).txt"
    return $Path
}
Function TestErrorLogParentExist ($ErrorLog)
{
    #Checks to see if the parent folder of the error log exists and if it doesn't, creates it
    if (-not (Test-Path (Split-Path -Parent $ErrorLog)))
    {
        Write-Verbose 'Parent folder not found. Creating...'
        New-Item -ItemType Directory -Path (Split-Path -Parent $ErrorLog) | Out-Null
        Write-Verbose 'Parent folder created'
    }
    else
    {
        Write-Verbose "Found parent folder $(Split-Path -Parent $ErrorLog)"
    }
}
Export-ModuleMember -Function Get-MTServiceProcessInfo, Get-MTSystemInfo, Get-MTVolumeInfo, Set-MTLyncOnline, Get-MTRemoteSMBShare, Get-MTRemoteSMBShare
