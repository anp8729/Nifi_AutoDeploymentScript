# Nifi
AutoDeploymentScript:

This powerShell script lets you deploy nifi data flows into various environment. It uses Nifi-Registry and Nifi-Toolkit to deploy the flows.

    
<b>#DESCRIPTION :</b>
    
<b>#ScriptParameters: </b>

<b>#PARAMETER env:</b>

 Accepted values prod,qa,stage Environement where the flow is to be deployed

<b>#PARAMETER tp:</b>

Optional parameter. path to nifi toolkit 

<b>#PARAMETER flow:</b>

Name of the data flow (same as the one in the registry) to be deployed
   
<b>#PARAMETER fv:</b>

Optional parameter. Version number to be deployed. If not provided it will deploy latest version 

<b>#PARAMETER r:</b>

Optional parameter. Path to nifi registry instance
   
<b>#PARAMETER u:</b>

Optional parameter. Path to nifi (link to nifi instance) where the flow is to be deployed
eg http://Fake-Prod-Nifi:8080 
   
<b>#PARAMETER fp:</b>

Optional parameter. Path to nifi variable properties json file based on environment 
default path is NifiEnvironmentProperties directory 
  
<b>#EXAMPLE:</b>

    C:\PS> .\AutoDeployment.ps1 -env prod -flow DataTransform 

<b>#FurtherHelp:</b>

Script is properly commented for better understanding.

<b>#NifiEnvironmentProperties:</b>

One needs to replicate properties file in <b>NifiEnvironmentProperties</b> directory for respective enviornment. The name should be in the <b>customProperties_env.json </b> format. (replace env with dev,prod,stage,qa etc). The sample file <b>customProperties_dev.json</b> contains setup variables for SMTP processor, PutSNS processor and DBCPConnectionPool controller service . Each json key should exactly match the processor variable names in nifi flow. 
    
 <b>#Script:</b>
 
The script restricts deployment to various environment from the specific environment . Example dev will always be deployed to QA, QA will be deployed to stage and stage to prod resply.
 
<b>#Registry Bucket Names:</b>

The from environment variable <b>fromEnv</b> in script should match exactly with the bucket name in registry. (Update it as per ur bucket names)

Update NifiEnvironmentProperties <b>-fp</b> directory path inside script to the directory it is saved in or pass it as an argument.

<b>#Assumption:</b>

This script assumes you have Nifi Registry instance running and minimally the dev environment has the nifi-registry client setup. All the higher environments , if the client is not set up the script will try to set it up while trying to deploy.
    

