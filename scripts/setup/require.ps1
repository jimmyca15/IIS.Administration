﻿# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.


Param(
    [parameter(Mandatory=$true , Position=0)]
    [ValidateSet("Is-Administrator",
                 "Dotnet")]
    [string]
    $Command
)

# Throws if the caller is not an Administrator
function Is-Administrator {
    Write-Verbose "Verifying user is an Administrator"
    if (-not(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        throw "User must be an Administrator to continue."
    }
    Write-Verbose "Ok"
}

# Throws if .NET Core has not been installed.
function Dotnet {
    Write-Verbose "Verifying .NET Core shared framework installed"
    if($(Get-Command "dotnet.exe" -ErrorAction SilentlyContinue) -eq $null) {
        Write-Warning ".NET Core Shared Framework not installed"
        Write-Warning "Download the .NET Core Runtime (LTS) 'https://www.microsoft.com/net/download/core#/runtime'"
        throw ".NET Core required to continue"
    }
    Write-Verbose "Ok"
}

switch($Command)
{
    "Is-Administrator"
    {
        Is-Administrator
    }
    "Dotnet"
    {
        Dotnet
    }
    default
    {
        throw "Unknown command"
    }
}