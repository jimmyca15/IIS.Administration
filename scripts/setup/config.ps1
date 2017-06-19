﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param (
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("Get",
                 "Remove",
                 "Exists",
                 "Get-UserFileMap",
                 "Write-AppSettings",
                 "Migrate-AppSettings",
                 "Write-Config",
                 "Get-AppHostPort")]
    [string]
    $Command,
    
    [parameter()]
    [string]
    $Path,
    
    [parameter()]
    [object]
    $ConfigObject,
    
    [parameter()]
    [string]
    $AppHostPath,
    
    [parameter()]
    [string]
    $AppSettingsPath,
    
    [parameter()]
    [string]
    $ApplicationPath,
    
    [parameter()]
    [string]
    $Version,
    
    [parameter()]
    [int]
    $Port,
    
    [parameter()]
    [string]
    $Source,
    
    [parameter()]
    [string]
    $Destination
)

# Name of file we place installation data in
$INSTALL_FILE = "setup.config"
$IISAdminSiteName = "IISAdmin"

# Returns a map of the files that contain user configurable settings.
function Get-UserFileMap {
    return @{
        "modules.json" = "Microsoft.IIS.administration/config/modules.json"
        "appsettings.json" = "Microsoft.IIS.administration/config/appsettings.json"
        "api-keys.json" = "Microsoft.IIS.administration/config/api-keys.json"
    }
}

# Tests whether a setup configuration exists at the given path.
# Path: The path to test for existence of a setup configuration.
function Exists($_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }

    return Test-Path (Join-Path $_path $INSTALL_FILE)
}

# Returns an object representation of the setup configuration located at the specified path.
# Path: The parent directory of the setup configuration.
function Get($_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }
    
	if (-not(Exists $_path)) {
		return $null
	}

    [xml]$configXml = Get-Content (Join-Path $_path $INSTALL_FILE)
    $config = $configXml.Configuration

    $userFiles = Get-UserFileMap

    $installConfig = @{
        InstallPath = $config.InstallPath
        Port = $config.Port
        ServiceName = $config.ServiceName
        Version = $config.Version
        UserFiles = $userFiles
        Installer = $config.Installer
        Date = $config.Date
		CertificateThumbprint = $config.CertificateThumbprint
    }

    return $installConfig
}

# Removes the setup configuration located at the specified path.
# Path: The parent directory of the setup configuration.
function Remove($_path) {
    if ($(Test-Path $_path)) {
        .\files.ps1 Remove-ItemForced -Path $(Join-Path $_path $INSTALL_FILE)
    }
}

# Writes install time information into the appsettings.json file
# AppSettingsPath: The full path to the appsettings.json file
function Write-AppSettings($_appSettingsPath) {
    if ([string]::IsNullOrEmpty($_appSettingsPath)) {
        throw "AppSettingsPath required."
    }
    if (-not(Test-Path $_appSettingsPath)) {
        throw "appsettings.json not found at $_appsettingsPath"
    }

    $settings = .\json.ps1 Get-JsonContent -Path $_appSettingsPath

    $settings.security.users.administrators += $(.\security.ps1 CurrentAdUser)
    $settings.security.users.owners += $(.\security.ps1 CurrentAdUser)

    .\json.ps1 Set-JsonContent -Path $AppSettingsPath -JsonObject $settings
}

# Migrates the appsettings configuration from one installation to the other, performing any transforms if necessary
# Source: The source installation path, Ex: C:\Program Files\IIS Administration\1.1.1
# Destination: The destination installation path, Ex: C:\Program Files\IIS Administration\2.0.0
function Migrate-AppSettings($_source, $_destination) {
    $userFiles = .\config.ps1 Get-UserFileMap

    $oldAppSettings = .\json.ps1 Get-JsonContent -Path $(Join-Path $Source $userFiles["appsettings.json"])
    $newAppSettings = .\json.ps1 Get-JsonContent -Path $(Join-Path $Destination $userFiles["appsettings.json"])

    if ($oldAppSettings.security -eq $null) {
        $oldAppSettings = .\json.ps1 Add-Property -JsonObject $oldAppSettings -Name "security" -Value $newAppSettings.security
    }

    if ($oldAppSettings.administrators -ne $null) {
        $oldAppSettings = .\json.ps1 Remove-Property -JsonObject $oldAppSettings -Name "administrators"
    }

    .\json.ps1 Set-JsonContent -Path $(Join-Path $Destination $userFiles["appsettings.json"]) -JsonObject $oldAppSettings
}

# Writes the provided object into a setup configuration at the specified path.
# ConfigObject: The object to write into the setup configuration.
# Path: The path to a directory to hold the setup configuration.
function Write-Config($obj, $_path) {

    if ([string]::IsNullOrEmpty($_path)) {
        throw "Path required."
    }

    $xml = [xml]"<?xml version=`"1.0`" encoding=`"utf-8`"?><Configuration></Configuration>"
    $xConfig = $xml["Configuration"]

    foreach ($key in $obj.keys) {     
           
        $xElem = $xml.CreateElement($key)
        $xElem.InnerText = $obj[$key]
        $xConfig.AppendChild($xElem) | Out-Null
    }     
    $xml.AppendChild($xConfig) | Out-Null
    
    $ms = New-Object System.IO.MemoryStream
    $sw = New-Object System.IO.StreamWriter -ArgumentList $ms
    $xml.Save($sw) | Out-Null

    $position = $ms.Seek(0, [System.IO.SeekOrigin]::Begin)
    $sr = New-Object System.IO.StreamReader -ArgumentList $ms
    $content = $sr.ReadToEnd()

    $sr.Dispose()
    $sw.Dispose()
    $ms.Dispose()

    .\files.ps1 Write-FileForced -Path $(Join-Path $_path $INSTALL_FILE) -Content $content
}

# Gets the port that the IIS Administration site is configured to listen on in the applicationHost.config file.
# AppHostPath: The location of the applicationHost.config file.
function Get-AppHostPort($_appHostPath) {
    if ([string]::IsNullOrEmpty($_appHostPath)) {
        throw "AppHostPath required."
    }
    if (-not(Test-Path $_appHostPath)) {
        throw "applicationHost.config not found at $_appHostPath"
    }

    
    [xml]$xml = Get-Content -Path "$_appHostPath"
    $sites = $xml.GetElementsByTagName("site")

    $site = $null;
    foreach ($s in $sites) {
    if ($s.name -eq $IISAdminSiteName) { 
            $site = $s;
        } 
    }

    if ($site -eq $null) {
        throw "Installation applicationHost.config does not contain IISAdmin site"
    }

    $info = $site.bindings.binding.GetAttribute("bindingInformation")

    $parts = $info.Split(':')
    $test = $null
    if ($parts.Length -ne 3) {
        throw "Unsupported binding information format"
    }
    if (-not([uint16]::TryParse($parts[1], [ref]$test))) {
        throw "Unsupported binding information format"
    }
    return $parts[1]
}

switch ($Command)
{
    "Get"
    {
        return Get $Path
    }
    "Remove"
    {
        Remove $Path
    }
    "Exists"
    {
        return Exists $Path
    }
    "Get-UserFileMap"
    {
        return Get-UserFileMap
    }
    "Write-AppSettings"
    {
        Write-AppSettings $AppSettingsPath
    }
    "Migrate-AppSettings"
    {
        Migrate-AppSettings $Source $Destination
    }
    "Write-Config"
    {
        Write-Config $ConfigObject $Path
    }
    "Get-AppHostPort"
    {
        return Get-AppHostPort $AppHostPath
    }
    default
    {
        throw "Unknown command"
    }
}