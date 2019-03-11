#Path to config files and deployment folder
$ConfigPath = "C:\Users\otorma\Desktop\Folders\Scripts\VMD"
$GoldImage ="C:\Users\otorma\Documents\VM\GoldImages"
."$ConfigPath\functions.ps1"

$ConfigFiles = Get-ChildItem $configpath\Config
$Image = Get-ChildItem $GoldImage

Write-Host "------------------------------" -ForegroundColor Green
Write-Host "VM creation process started..." -ForegroundColor Green
Write-Host "------------------------------" -ForegroundColor Green

$ErrorActionPreference

$ConfigFiles | ForEach-Object{

#converts from json file and set to variables
$FileContent = get-content $_.FullName
$ConvectionFromJson = $FileContent | ConvertFrom-Json
$VmName = $ConvectionFromJson.VmName
$Disks = $ConvectionFromJson.Disk
$Path = [string]$ConvectionFromJson.Path -replace "/","\"
$Proc = $ConvectionFromJson.Processors
$Memory = [int64]$ConvectionFromJson.Memory*1gb

    $VmName | ForEach-Object {
        #Creats path for vms and vhds
        try{
            if(!(Get-ChildItem $Path -Name $_ -ErrorAction SilentlyContinue)){
                $DeploymentPath = New-Item $Path -Name $_ -ItemType Directory
                $VmsPath = $DeploymentPath.FullName + "\Virtual Machines\"
                $DiskPath = New-Item $DeploymentPath.FullName -Name "Virtual Hard Disks" -ItemType Directory
                $DiskPath = $DiskPath.FullName + "\"
            }else{
                Write-Host "Virtual Machine: $_ already exists! Stopping execution..." -ForegroundColor Yellow
                return
            }
        }catch{
            throw "Could not create folder..." + $_.Exception
        }
        
        #Get vm switch
        SelectVMSwitch
        $swn = VMSwitch -vmName $_
        
        #Create VM
        Write-Host "Creating VM..." -ForegroundColor Green
        Write-Host "________________________________" -ForegroundColor Green
        try{
            $VM = NewVm -name $_ -memory $Memory -path $VmsPath -switchName $swn
        }catch{
            throw "Could not create VM... " + $_.Exception
        }
        
        sleep 3
        
        #Copy gold image
        Write-Host "Copying gold image..." -ForegroundColor Green
        Write-Host "________________________________" -ForegroundColor Green
        try{
            if(Test-Path $Image.FullName){
                Copy-Item -Path $Image.FullName -Destination $DiskPath -Force
            }else{
                Write-Warning "Please check path $($Image.FullName)"
            }
            #System disk path
            $Script:SysDiskImagePath = Get-childItem -Path $DiskPath
               
            #Create disks
            $Disks | ForEach-Object{
                $diskName = $_.name | %{$_}
                $diskSize = $_.size | %{$_}
            }
            $i=0
            $diskName | % {
                [int64]$size = $diskSize[$i]*1Gb
                $HardDrives = NewDisk -Path $DiskPath -diskSize $size -diskName $_
                $i++
            }
            #Data disk path
            $Script:DataDiskImagePath = Get-childItem -Path $DiskPath | where name -ne $SysDiskImagePath.Name
    
        }catch{
            throw $_.Exception
        }
        
        #Attaching gold image
        Write-Host "Attaching gold image..." -ForegroundColor Green
        Write-Host "________________________________" -ForegroundColor Green
        try{
            #Add system disk to vm
            Add-VMHardDiskDrive -VMName $VM.Name -Path $SysDiskImagePath.FullName
            #Add data disk to vm
            $DataDiskImagePath | ForEach-Object{
                Add-VMHardDiskDrive -VMName $VM.Name -Path $_.FullName
            }
        }catch{
            throw "Could not attache IMG..." + $_.Exception
        }
        
        #Change boot order, set HD for boot
        $VmFirmware = Get-VMFirmware -VMName $VM.Name
        $Drive = $VmFirmware.BootOrder | ?{$_.BootType -eq "Drive"}
        Set-VMFirmware -VMName $VM.Name -BootOrder $Drive
        
        #Configure Vm processors
        Set-VMProcessor -VMName $VM.Name -Count $Proc
    
        Write-Host "Vm $($Vm.Name) is ready!" -ForegroundColor Green
        Write-Host "________________________________" -ForegroundColor Green
        
    }
}
