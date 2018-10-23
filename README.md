# Nifi
AutoDeploymentScript

This powerShell script lets you deploy nifi data flows into various environment. It uses Nifi-Registry and Nifi-Toolkit to deploy the flows.

#SYNOPSIS
    
#DESCRIPTION ScriptParameters
    
#PARAMETER env
 Accepted values prod,qa,stage Environement where the flow is to be deployed

#PARAMETER tp
Optional parameter. path to nifi toolkit 

#PARAMETER flow
Name of the data flow (same as the one in the registry) to be deployed
   
#PARAMETER fv
Optional parameter. Version number to be deployed. If not provided it will deploy latest version 

#PARAMETER r
Optional parameter. Path to nifi registry instance
   
#PARAMETER u
Optional parameter. Path to nifi (link to nifi instance) where the flow is to be deployed
eg http://Prod-Nifi:8080 
   
#PARAMETER fp
Optional parameter. Path to nifi variable properties json file based on environment 
default path is NifiEnvironmentProperties directory 
  
#EXAMPLE
    C:\PS> .\AutoDeployment.ps1 -env prod -flow DataTransform 

Script is properly commented for better understanding.

One need to replicate properties file in NifiEnvironmentProperties directory for respective enviornment. The name should be int he customProperties_<env>.json format. (replace env with dev,prod,stage,qa etc). The sample file contains setup variables for SMTP processor, PutSNS processor and DBCPConnectionPool controller service . Each json key should exactly match the processor variable names in nifi flow. 
