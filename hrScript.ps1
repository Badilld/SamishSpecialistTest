#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#
#
# Name: hrScript.ps1
# Date: 9/19/2024
# Author: Dakota Badillo-Cochran (github.com/badilld)
# Description:
#       System Specialist Skill Test - Powershell Script for Samish System Specialist Skills Test
#
# Use:
#       Extract data from Human Resources Management System using SQL commands and imports data into HRActions Database
#
# Assumptions: 
#       SqlServer Module is installed
#       Laserfiche Workflow device has permissions to request data from sql databases and permission to write to databases
#
# Attributions:
#       Utilizing code provided by Microsoft under the MIT License
#       Link: 
#            https://github.com/microsoft/m365-compliance-connector-sample-scripts/blob/main/sample_script.ps1
#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////#

#Important Database Info:
# [dbo].[SIP_HRActions_RMBS] <- HR Actions Database
# [dbo].[SIP_HRMS_RMBS] <- HR Employee Database

#Define parameters
param (
    [string]$employeeID #Possibly need employee look up but I assume that in this code the employee ID # is known
    [string]$sActionType #I would have a set list of commands that could be executed for a full build instead of as a parameter
)
$server = "serverName"
$hrSQLDatabase = "[dbo].[SIP_HRMS_RMBS]"
$Data = $null
$Query = "SELECT * FROM " + $hrSQLDatabase + " WHERE sEmployeeIDf = " + $employeeID
$Date = Get-Date -Format "MM/dd/yyyy" #for HR Actions change log


#Microsoft Code for Access Token
function Get-AccessToken () {
    # Token Authorization URI
    $uri = "$($oAuthTokenEndpoint)?api-version=1.0"

    # Access Token Body
    $formData = 
    @{
        client_id     = $appId;
        client_secret = $appSecret;
        grant_type    = 'client_credentials';
        resource      = $resource;
        tenant_id     = $tenantId;
    }

    # Parameters for Access Token call
    $params = 
    @{
        URI         = $uri
        Method      = 'Post'
        ContentType = 'application/x-www-form-urlencoded'
        Body        = $formData
    }

    $response = Invoke-RestMethod @params -ErrorAction Stop
    return $response.access_token
}

#SQL query used to gather information from HR Surver
try {
    $SqlConnectionString = "Server=$server;Database=$hrSQLDatabase;Integrated Security=True;"
    $Data = Invoke-Sqlcmd -ConnectionString $SqlConnectionString -Query $Query
}
catch{Write-ErrorMessage("Server Error: HR Database connection failed")}

#If data is null, something went wrong with the previous step
if $Data != $null {

    #Upload data to IRM
    try {
        #Get Token
        $AccessToken = Get-AccessToken
        $GraphApiUrl = "https://graph.microsoft.com/v1.0/security/insiderRisk/sqlAction"

        # Create the request body
        $Body = @{
            "@odata.type" = "#microsoft.graph.insiderRiskSqlAction"
            INSERT INTO [dbo].[SIP_HRActions_RMBS] (
                [sEmployeeIDf],
                [sActionType],
                [dtmActionDate],
                [dtmActionEndDate],
                [dtmActionDueDate],
                [sActionText],
                [dtmDateEntered],
                [sEnteredBy],
                [ysnCleared],
                [ysnReminder],
                [ysnScheduled],
                [ysnAllDayEvent],
                [nReminderInterval],
                [nReminderUnits],
                [bAllProperties],
                [sScheduledForID],
                [sChgField],
                [sChgBefore],
                [sChgAfter],
                [sStatus]
            ) VALUES (
                $data.sEmployeeIDf,
                $sActionType,
                $Date, 
                $Date,
                $Date,
                'ActionTaken',
                $Date,
                $Env:UserName,
                0,
                0,
                0,
                0,
                0,
                0,
                NULL,
                '',
                $Date + 'ActionTaken',
                '',
                $Date,
                ''
            );
            
        }
    
        # Send the request
        $Headers = @{
            Authorization = "Bearer $AccessToken"
            "Content-Type" = "text"
        }
    
        Invoke-RestMethod -Uri $GraphApiUrl -Method Post -Headers $Headers -Body $Body

        Write-Host "Action Complete."
    }
    catch {Write-ErrorMessage("Server Error: Microsoft Purview - IRM connection failed")}
}