﻿Function Get-NSSessionCookie
{
    <#
    .SYNOPSIS
        Create a session on a NetScaler

    .DESCRIPTION
        Create a session on a NetScaler

    .PARAMETER Address
        Hostname for the NetScaler

    .PARAMETER Credential
        PSCredential object to authenticate with NetScaler.  Prompts if you don't provide one.

    .PARAMETER Timeout
        Timeout for session in seconds

    .PARAMETER AllowHTTPAuth
        Allow HTTP.  Don't specify this uless you want authentication data to potentially be sent in clear text

    .PARAMETER TrustAllCertsPolicy
        Sets your [System.Net.ServicePointManager]::CertificatePolicy to trust all certificates.  Remains in effect for the rest of the session.  See .\Functions\Set-TrustAllCertsPolicy.ps1 for details.  On by default

    .FUNCTIONALITY
        NetScaler
    #>
    [cmdletbinding()]
    param
    (
    
        [validateset("CTX-NS-01","CTX-NS-02","CTX-NS-03","CTX-NS-04","CTX-NS-TST-01","CTX-NS-TST-02")]
        [string]$Address = "CTX-NS-TST-01",

        [System.Management.Automation.PSCredential]$Credential = $( Get-Credential -Message "Provide credentials for $Address" ),

        [int]$Timeout = 3600,

        [switch]$AllowHTTPAuth,

        [bool]$TrustAllCertsPolicy = $true

    )

    if( $TrustAllCertsPolicy )
    {
        Set-TrustAllCertsPolicy
    }

    #Define the URI
    $uri = "https://$address/nitro/v1/config/login/"
    
    #Extract the username, take into account domain names
    If($Credential -match "\\")
    {
        $user = $Credential.username.split("\")[1]
    }
    Else
    {
        $user = $Credential.username.split("\")[0]
    }

    #Build the login json
    $jsonCred = @"
{
    "login":  {
                  "username":  "$user",
                  "password":  "$($Credential.GetNetworkCredential().password)",
                  "timeout": $timeout
              }
}
"@

    #Invoke the REST Method to get a cookie using 'SessionVariable'
    $cookie = $(
        Try
        {
            Invoke-RestMethod -Uri $uri -ErrorAction stop -Method Post -Body $jsonCred -ContentType application/json -SessionVariable sess
        }
        Catch
        {
            write-warning "Error: $_"
            if($AllowHTTPAuth)
            {
                Write-Verbose "Reverting to HTTP"
                Invoke-RestMethod -Uri ( $uri -replace "^https","http") -ErrorAction stop -Method Post -Body $jsonCred -ContentType application/json -SessionVariable sess
            }
        }
    )

    #If we got a session variable, return it.  Otherwise, display the results in a warning
    if($sess)
    {
        #Provide feedback on expiration
        $date = ( get-date ).AddSeconds($Timeout)
        Write-Verbose "Cookie set to expire in '$Timeout' seconds, at $date"
        $sess
    }
    else
    {
        Write-Warning "No session created: $( $cookie | Out-String )"
    }
}