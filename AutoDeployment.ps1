<#
.SYNOPSIS
    .
.DESCRIPTION
    .
.PARAMETER env
 Accepted values prod,qa,stage

.PARAMETER tp
Optional parameter. path to nifi toolkit

.PARAMETER flow
Name of the data flow (same as the one in the registry)
   
.PARAMETER fv
Optional parameter. Version number to be deployed. If not provided it will deploy latest version

.PARAMETER r
Optional parameter. Path to nifi registry
   
.PARAMETER u
Optional parameter. Path to nifi nifi environment
   
.PARAMETER fp
Optional parameter. Path to nifi variable properties json file based on environment
  
.EXAMPLE
    C:\PS> .\AutoDeployment.ps1 -env prod -flow DataTransform 
    
.NOTES
    Author: Ankita PAtel
    Date:   Sept 17, 2018    
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Accepted values prod,qa,stage")]
    [string]$env,
    [Parameter(HelpMessage="Optional parameter. path to nifi toolkit")]
    [string]$tp = "C:\automateDeployment\nifi-toolkit-1.7.1\bin",
    [Parameter(Mandatory=$true,HelpMessage="Name of the data flow (same as the one in the registry)")]
    [string]$flow,
    [Parameter(HelpMessage="Optional parameter. Version number to be deployed. If not provided it will deploy latest version")]
    [int]$fv,
    [Parameter(HelpMessage="Optional parameter. Path to nifi registry")]
    [string]$r = "http://localhost:18080/",
    [Parameter(HelpMessage="Optional parameter. Path to nifi nifi environment")]
    [string]$u,
    [Parameter(HelpMessage="Optional parameter. Path to nifi variable properties json file based on environment")]
    [string]$fp = "C:\automateDeployment\NifiEnvironmentProperties"
 )

If ($StartUpVariables) { Try {Remove-Variable -Name StartUpVariables -Scope Global -ErrorAction SilentlyContinue } catch { } }
New-Variable -force -name StartUpVariables -value ( Get-Variable | ForEach-Object { $_.Name } );

if([string]::IsNullOrEmpty($env)){
    throw "No environment specified";
}
if([string]::IsNullOrEmpty($flow)){
    throw "No flow specified";
}

[string]$toBi = ""; # destination Bucket Identifier for flow import
[string]$fromBi = ""; # source Bucket Identifier for flow export
[string]$toFi = ""; # destination flow identifier to be pushed to registry
[string]$fromFi = ""; # source flow identifier to be pulled from registry
[string]$toFv = 1; # destination flow version to update flow variables
[string]$pgId = ""; # process group identifier
[string]$fromEnv = ""; # Source Environment to pull flow from

 switch ( $env )
 {
     Production {
         $fromEnv = 'Staging' ;
         if([string]::IsNullOrEmpty($u)) {
            $u = "http://localhost:8080";
         }
              
     }
     Staging {
         $fromEnv = 'QA'  ;
         if([string]::IsNullOrEmpty($u)) {
            $u = "http://localhost:8080";
         }   
     }
     QA {
         $fromEnv = 'DEV'  ;
         if([string]::IsNullOrEmpty($u)) {
            $u = "http://localhost:8080";
         }
     }
 }

Function Clean-Memory {
Get-Variable |
 Where-Object { $startupVariables -notcontains $_.Name } |
 ForEach-Object {
  try { Remove-Variable -Name "$($_.Name)" -Force -Scope "global" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
  catch { }
 }
}
 function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
     try {$obj | Get-Member -MemberType NoteProperty | ForEach-Object {
            $key = $_.Name
            [PSCustomObject]@{Key = $key; Value = $obj."$key"}
        }}
  catch { }
}
Try
{

$bucketList = &  $tp\cli.bat registry list-buckets -u $r -ot json|Out-String; #Get all the bucket list from registry
"bucketList"
$bucketList

if ($LastExitCode -ne 0) {
    throw "Couldn't find bucketList: $bucketList";
}
<#
	Loop through all the bucketlist and identify the bucketlist which matches the fromEnv variable
#>
 if(-not [string]::IsNullOrEmpty($bucketList)){
  $bucketList = $bucketList| ConvertFrom-Json
    $bucketList | ForEach-Object{
        if($_.name.ToLower() -eq $env.ToLower()){
            $toBi = $_.identifier
            "toBi"
            $toBi
           
        }
        if($_.name.ToLower() -eq $fromEnv.ToLower()){
            $fromBi = $_.identifier
             "fromBi"
            $fromBi
        }
       
    }
  }
  
  
 if([string]::IsNullOrEmpty($fromBi)){
    throw "cannot find bucket Identifier for the flow $flow in the env $fromEnv"
 }
  if([string]::IsNullOrEmpty($toBi) ){
    throw "cannot find bucket Identifier for the flow $flow in the env $env"
 }
 #Get all the flows inside the bucket identified above $fromBi
$fromFlowList = &  $tp\cli.bat registry list-flows -u $r -b $fromBi -ot json|Out-String; 
"fromFlowList"
$fromFlowList

if ($LastExitCode -ne 0) {
        throw "Couldn't find fromFlowList: $fromFlowList";
}

<#
	Loop through the flowlist and identify the flow id which matches the required flow to be deployed.  $fromFi 
#>
  
if(-not [string]::IsNullOrEmpty($fromFlowList)){
 $fromFlowList =$fromFlowList |ConvertFrom-Json
    $fromFlowList | ForEach-Object{
        if($_.name.ToLower() -eq $flow.ToLower()){
            $fromFi = $_.identifier
            "fromFi"
             $fromFi
        }
    }
 }

 #Get all the flows inside the destination bucket
 $toFlowList = &  $tp\cli.bat registry list-flows -u $r -b $toBi -ot json|Out-String; 
"toFlowList"
$toFlowList

 if ($LastExitCode -ne 0) {
        throw "Couldn't find toFlowList:  $toFlowList";
 }
 
 <#
	Loop through the flowlist and identify the flow id which matches the required flow to be deployed.  $toFi 
#>

 if(-not [string]::IsNullOrEmpty($toFlowList)){
 $toFlowList = $toFlowList|ConvertFrom-Json
    $toFlowList | ForEach-Object{
        if($_.name.ToLower() -eq $flow.ToLower()){
            $toFi = $_.identifier
            $toFi
        }
    }
 }

 <# 
 If destination flow identifier is not found it indicated the flowis never deployed to this environment.
 Hence create the flow in the registry for the destination environment.
 #>
 
 if( [string]::IsNullOrEmpty($toFi)){
    $toFi = &  $tp\cli.bat registry create-flow -b $toBi -fn $flow -u $r|out-String; 
      if ($LastExitCode -ne 0) {
        throw "Couldn't create flow: $toFi";
      }
    $toFi = $toFi.Trim();
    "toFi"
    $toFi
  
 }

 if([string]::IsNullOrEmpty($fromFi)){
     throw "cannot find flow Identifier for the flow $flow bucket $fromBi in the env $env "
 }

 if(-not($fv)){
    $fv=1;
 }
 
#Get all the flow versions deployed so far in the source bucket.
 $fromFlowVersions = &  $tp\cli.bat registry list-flow-versions  -u $r -f  $fromFi -ot json|Out-String; 
"fromFlowVersions"
 $fromFlowVersions

 if ($LastExitCode -ne 0) {
        throw "Couldn't find fromFlowVersions: $fromFlowVersions";
    }

#Get the last flow version
if(-not [string]::IsNullOrEmpty($fromFlowVersions)){
$fromFlowVersions = $fromFlowVersions|ConvertFrom-Json
    $fromFlowVersions | ForEach-Object{
       if($fv -le $_.version)
        { 
            $fv = $_.version;
            "fv"
            $fv
        } 
    }
  }
 
#Export the latest flow version or the flow version specified in args (octopus parameter)
$exportFlow = &  $tp\cli.bat registry export-flow-version -f $fromFi -fv $fv -o temp-flow.json -ot json -u $r;
 if ($LastExitCode -ne 0) {
        throw "Couldn't export flow: $exportFlow";
 }

 #Import the flow exported in temp-flow to the destination bucket.
$toFv = &  $tp\cli.bat registry import-flow-version -f $toFi -i temp-flow.json -u $r|Out-String;
 if ($LastExitCode -ne 0) {
        throw "Couldn't import flow: $toFv";
}
$toFv = [int]$toFv.Trim();
"toFv"
$toFv
 
#Get process group lists from nifi (destination environment)
    $pgList = &  $tp\cli.bat nifi pg-list -u $u -ot json|Out-String;
    "pgList"
    $pgList

    if ($LastExitCode -ne 0) {
        throw "Couldn't find pgList: $pgList";
    }
      
	#Get the process group Id for the flow to be deployed
    if(-not [string]::IsNullOrEmpty($pgList)){
        $pgList  = $pgList |ConvertFrom-Json
        $pgList |   ForEach-Object{
            if($_.name.ToLower() -eq $flow.ToLower()){
                $pgId = $_.id;
                "pgid pglist"
                $pgid = $pgid.Trim();
            
            }
        }
    }
	
	#cget all nifi registry clients 
    $regCLients = &  $tp\cli.bat nifi list-reg-clients -u $u -ot json |Out-String 
    "regCLients";
    $regCLients;

    if ($LastExitCode -ne 0) {
        throw "Couldn't get regClients: $regCLients";
    }
    $isRegClientMatches = $FALSE;  
      
	#Check if the any registry client matches the registry we are trying to pull flow from
    if(-not [string]::IsNullOrEmpty($regCLients)){
        $regCLients  = $regCLients  | ConvertFrom-Json;
        $regCLients |   ForEach-Object{
            $_.registries|   ForEach-Object{
                if($_.component.uri.ToLower() -eq $ruri.ToLower()){
                    $isRegClientMatches = $TRUE;
                    "isRegClientMatches"
                    $isRegClientMatches;
                }
            }
        }
    }

	#If no matching registry client is found than create a new registry client
    if(-not($isRegClientMatches)){
        $createRegCLient = &  $tp\cli.bat nifi create-reg-client -u $u -rcn "RemoteRegistry" -rcu $ruri  |Out-String 
        "createRegCLient"
        $createRegCLient;
        if ($LastExitCode -ne 0) {
            throw "Couldn't create registry client: $createRegCLient";
        }
    }
 
    if([string]::IsNullOrEmpty($pgid)){
        #If the flow doesnot exist try to deploy the flow to Nifi from registry
        $pgid = &  $tp\cli.bat nifi pg-import -u $u -b $tobi -f $tofi -fv $toFv |Out-String ;
        if ($LastExitCode -ne 0) {
            throw "Couldn't import process group: $pgid";
        }
        "pgid"
        $pgid
        $pgid = $pgid.Trim();
    }
    else {
		#If flow already exist just update the flow version
        $updatedVersion = &  $tp\cli.bat nifi pg-change-version -u $u -fv $toFv -pgid $pgid|Out-String
        if ($LastExitCode -ne 0) {
            throw "Couldn't update process group version: $updatedVersion";
        }
        "updatedVersion"
        $updatedVersion
    }

	#Get NifiEnvironmentProperties and set the nifi variables
 $file_content |  Get-ObjectMembers | foreach {
        $setVariables = &  $tp\cli.bat nifi pg-set-var -u $u -var $_.Key -val $_.Value -pgid $pgid  ;
        if ($LastExitCode -ne 0) {
            throw "Couldn't set process group variables: $setVariables";
        }
    }

	#Get variables for debugging
    $vars = &  $tp\cli.bat nifi pg-get-vars -u $u -pgid $pgid | out-String;
    if ($LastExitCode -ne 0) {
            throw "Couldn't get process group variables: $vars";
        }
	#Start Nifi Controller services
    $ctrlServices = &  $tp\cli.bat nifi pg-enable-services -pgid $pgid -u $u;
    if ($LastExitCode -ne 0) {
            throw "Couldn't start controller services: $ctrlServices";
        }
	#start Nifi
    $strtPG = &  $tp\cli.bat nifi pg-start -pgid $pgid -u $u;
    if ($LastExitCode -ne 0) {
            throw "Couldn't start process group: $strtPG";
        }

Clean-Memory;
}
Catch
{
	#SMTP setup for deployment failure emails
    $Exception = $_.Exception;
    $ErrorMessage = $_.Exception.Message;
    $FailedItem = $_.Exception.ItemName;
    $SMTPServer = "" ;
    $subject = "Nifi deployment to env $env failed!!";
    $body = "Nifi deployment Failed $FailedItem. The error message was $ErrorMessage : $Exception";
        $SMTPMessage = New-Object System.Net.Mail.MailMessage("","",$subject,$body);
        $SMTPClient = New-Object Net.Mail.SmtpClient("", 587) ;
        $SMTPClient.EnableSsl = $true ;
		<# pass username and password resply #>
        $SMTPClient.Credentials = New-Object System.Net.NetworkCredential("", ""); 
        $SMTPClient.Send($SMTPMessage);
		throw $Exception
        Clean-Memory;
     Break;
}
