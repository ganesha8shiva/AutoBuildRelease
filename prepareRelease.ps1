#---
# 1. Checkout and pull masters
#---
$cmdOutput=""
$cmdOutput = git checkout master -f 2>&1
if($cmdOutput -match 'error|conflict') {
    $cmdOutput
    exit
}

$cmdOutput=""
$cmdOutput = git pull 2>&1
if($cmdOutput -match 'error|conflict') {
    $cmdOutput
    exit
}

#---
# Terminate Script If There is no arg
#---
if(!$args) {
    write-host "Please enter branch name" -foreground "red" 
    exit
}

#---
# SET Branch
#---
$branch = $args[0]


#---
# Terminate Script If branch is not existsls
#---
$cmdOutput=""
$cmdOutput = git checkout $args[0]  -f 2>&1
if($cmdOutput -match 'error|conflict') {
    $cmdOutput
    exit
}


#---
# 2. load setting file and ignore folder
#---
#$build_folders = ('XYZRootWebApp','XYZWebApp')
#$ignore_pattern = '.vb|.config|.vbproj|aspnet_client'

[xml]$ConfigFile = Get-Content ".\Settings.xml"

#NOTE: Build should have project folders having bin sub-folder and need to be given in release
$build_folders = @()  # NOTE: list of folder 
$build_folders = $build_folders + $ConfigFile.Settings.build.folders.folder | Foreach-Object { $_}
if([int]$build_folders.length -eq 0) 
{
    write-host "Enter Valid Build Folders"  -foreground "red" 
    exit
}

# Ignore file types while making release
$ignore_pattern = $ConfigFile.Settings.ignore
if($ignore_pattern -eq '') 
{
    write-host "Enter Valid Ignore File Pattern"  -foreground "red" 
    exit
}


$sql_folder = $ConfigFile.Settings.sql.folder
if($sql_folder -eq '') 
{
    write-host "Enter Valid SQL Folder Path"  -foreground "red" 
    exit
}


#---
# sprint name 
#---
$sprint = $branch

#---
# 3 checkout and pull development branch
#---
git checkout -f $sprint
#git pull
$cmdOutput=""
$cmdOutput = git pull 2>&1

if($cmdOutput -match 'error|conflict|fatal') {
    $cmdOutput
    exit
}



#---
# THINK & TODO: we could merge master in current barnch if there is big team and parallel sprints development
#---


#---
# collection projects that affected
# Purpose: move bin after build
#---
$projects = @()
$flag = 0
git diff --name-only master |  % {
    if($_.split('/')) {
       $_.split('/')[0]
    }
} | Sort-Object -Unique | %{ 
    
    $file_path = $_        
    $flag=0
    $build_folders | Foreach-Object {
        if($file_path -match  $_) {
            $flag=1
        }
    } 
    if($flag -eq 1 ) {
        $projects = $projects + $_ 
    }
    
}

#---
# 4. Build Projects and Solution
#---
msbuild ..\XYZSln.sln /t:Clean

$cmdOutput=""
$cmdOutput = msbuild ..\XYZSln.sln /t:Rebuild /p:WarningLevel=0 /p:Configuration=Release /clp:ErrorsOnly  2>&1
if($cmdOutput -match 'error') {    
    write-host $cmdOutput -foreground "red"     
    exit
}


#---
# build path
#---
$build_path = ".\" + $sprint


#---
# remove build folder if exists
#---
if(Test-Path -Path $build_path ) {
    Remove-Item $build_path -Force -Recurse
}


#---
# 5. git diff command to get change file list
# 6. copy paste change file list
#---
$flag = 0
git diff --name-only master | Foreach-Object {
    if($_ -notmatch $ignore_pattern) {
       
        $file_path = $_
        $flag=0
        $build_folders | Foreach-Object {
            if($file_path -match  $_) {                
                $flag=1
            }
        }
                
        if($flag -eq 1 ) {            
           $newfile=$build_path + "\" +  $_.replace("/","\") # OLD
           New-Item -ItemType File -Path  $newfile  -Force  # OLD           
        }
        
    }
}


$flag = 0
git diff --name-only master | Foreach-Object { 
    if($_ -notmatch $ignore_pattern) {
        
        $file_path = $_        
        $flag=0
        $build_folders | Foreach-Object {
            if($file_path -match  $_) {
                $flag=1
            }
        }  
        
        if($flag -eq 1 ) {
        
            $source =  "..\" + $_.replace("/","\") # OLD
            $destination =   $build_path + "\" +  $_.replace("/","\")   # OLD  
            Copy-Item $source $destination -Force  # OLD
            
        }
        
    }
}


#---
# 7. copy paste content of bin folder mentioned in setting file
#---
$projects | % {
    $destination =   $build_path + "\" +  $_.replace("/","\")   + "\bin"    
    if(Test-Path -Path $destination ) {
        Remove-Item $destination -Force -Recurse
    }
}


$projects | % {        
    $source =  "..\" + $_.replace("/","\") + "\bin\*"
    $destination =   $build_path + "\" +  $_.replace("/","\")   + "\bin"    
    if(Test-Path -Path $destination ) {
        Remove-Item $destination -Force -Recurse
    }
    
    if (!(Test-Path -Path $destination)) {
        New-Item $destination -Type Directory
    }
    Copy-Item $source -Destination $destination
                
}

#---
# 8.copy paste sql files
#---
# Source Location /SQL/sprint{N}/*.sql
$source =  "..\" + $sql_folder + "\$sprint\*"
$destination =   $build_path
if(Test-Path -Path $source) {
    Copy-Item $source -Destination $destination
}




write-host "`n`n--------------------------------------" -foreground "magenta" 
write-host ">> " $args[0] "is ready !!!" -foreground "magenta" 
write-host "--------------------------------------" -foreground "magenta" 


#---
# TODO ZIP of build
#---