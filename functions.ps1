function NewVm{

    param(
        [parameter(Mandatory=$true)]
        [string]$name,
        [int64]$memory,
        $path,
        $switchName
    )
   
   try{
        $vm =  new-vm -Name $name -Prerelease 2 -MemoryStartupBytes $memory -NoVHD -Path $path -Confirm:$false -Force -SwitchName $switchName
        return $vm
   }catch{
        return "Can't create VM."
   }
}

function DiskPath{
    
    param(
       [parameter(Mandatory=$true)]
       [string]$diskPath,
       [parameter(Mandatory=$true)]
       [string]$diskName 
    )

    $diskPath = $diskPath + $diskName + ".vhdx"
    return $diskPath
}

function NewDisk{
    
    param(
       [parameter(Mandatory=$true)]
       [string]$Path,
       [parameter(Mandatory=$true)]
       [int64]$diskSize,
       [parameter(Mandatory=$true)]
       [string]$diskName 
    )

    $diskPath = DiskPath $Path $diskName 
    $disk = New-VHD -Path $diskPath -SizeBytes $diskSize -Dynamic
    return $disk
}

function AttacheDiskToVm{
    
    param(
      $diskPath,
      $vmName 
    )

    $vmDisks = Get-VMHardDiskDrive -VMName $vmName   
    Add-VMHardDiskDrive -VMName $vmName -ControllerType SCSI -ControllerLocation $vmDisks.ControllerLocation[-1]+1 -Path $diskPath     
}
    
function SelectVMSwitch{
   
    #Create switch list
    $Script:switch = Get-VMSwitch
    $Script:SelectSwitch=@{}
    $i=0
    
    $switch.Name | % {
       
        "{0} - {1}" -f $i, $_ 
        $SelectSwitch.$i = $_
        $i++
    } 

    Write-Host "" 
 } 
    
function VMSwitch{
    
    param(
      $vmName,
      $create = $false
    )

    $swithNumber = Read-Host "Select switch number"
    Write-Host "________________________________" -ForegroundColor Green

    $SelectSwitch.Keys | % {
        if($swithNumber -eq $_){
            if($create -eq $true){
                Add-VMNetworkAdapter -VMName $vmName -SwitchName $switch[$swithNumber].Name
            }else{
                return $switch[$swithNumber].Name
            }
        }
    }  
}
 