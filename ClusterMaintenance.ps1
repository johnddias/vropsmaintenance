param(
    [Parameter(Mandatory=$true)][string]$vropshost,
    [Parameter(Mandatory=$true)][string]$username,
    [Parameter(Mandatory=$true)][string]$password,
    [Parameter(Mandatory=$true)][string]$authsource,
    [Parameter(Mandatory=$true)][string]$clustername,
    [Parameter(Mandatory=$true)][string]$file,
    [Parameter(Mandatory=$true)][bool]$maintained,
    [switch]$ignoreSSL
)

function trustAllCerts ()
{
if (!("trustallcertspolicy" -as [type])) {
    ### Ignore TLS/SSL errors    
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint srvPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
}



function getvropstoken ()
{
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/xml")
    $headers.Add("Content-Type", "application/xml")

$body = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?>
`n<ops:username-password xmlns:ops=`"http://webservice.vmware.com/vRealizeOpsMgr/1.0/`" xmlns:xs=`"http://www.w3.org/2001/XMLSchema`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">
`n    <ops:username>"+$username+"</ops:username>
`n    <ops:authSource>"+$authsource+"</ops:authSource>
`n    <ops:password>"+$password+"</ops:password>
`n</ops:username-password>"

    $response = Invoke-RestMethod 'https://vrops-fielddemo.cmbu.local/suite-api/api/auth/token/acquire' -Method 'POST' -Headers $headers -Body $body

    $token = "vRealizeOpsToken " + $response.'auth-token'.token
$token
}

function callvrops 
{
    Param ($uri, $method, $body)

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept", "application/xml")
    $headers.Add("Content-Type", "application/xml")
    $headers.Add("Authorization",$token)


    if ($body -eq $null)
    {
        $params = @{
            URI = 'https://'+$vropshost+'/suite-api/'+$uri
            Headers = $headers
            Method = $method
        }
    } else {
       $params = @{
            URI = 'https://'+$vropshost+'/suite-api/'+$uri
            Headers = $headers
            Method = $method
            Body = $body
        }
    }
    $response = Invoke-RestMethod @params
$response
}

#$secure_password = ConvertTo-SecureString -String $password -AsPlainText -Force
if ($ignoreSSL) {trustAllCerts}

$token = getvropstoken

#Grab the cluster resourceId based on cluster name input
$uri = "api/resources?resourceKind=clustercomputeresource&name="+$clustername
$clusterObj = callvrops $uri "Get"

if ($clusterObj.resources.pageInfo.totalCount -gt 1) {
    throw "More than one cluster has been found. Unable to continue."
} elseif($clusterObj.resources.pageInfo.totalCount -eq 0) {
    throw "No clusters have been found. Nothing done."
}

#Start or end maintenance based on $maintained
if($maintained -eq $True) {

    #Grab descendants of the cluster
    $uri = "api/resources/bulk/relationships"
    $body = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?>
    `n<ops:resource-relationships-query relationshipType=`"DESCENDANT`" xmlns:ops=`"http://webservice.vmware.com/vRealizeOpsMgr/1.0/`" xmlns:xs=`"http://www.w3.org/2001/XMLSchema`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`">
    `n    <ops:resourceIds>"+$clusterObj.resources.resource.identifier+"</ops:resourceIds>
    `n</ops:resource-relationships-query>"

    $clusterDescObj = callvrops $uri "Post" $body

    #Build list of resource IDs to be maintained

    foreach($resources in $clusterDescObj.'resources-relation'.resourcesRelations.resourceRelations)
    {
        $resIds = $resIds + "id=" + $resources.resource.identifier + "&"
    }

    #Tack on the cluster ID
    $resIds = $resIds + "id=" + $clusterObj.resources.resource.identifier

    #Save to a file
    New-Item -Path $file -ItemType File -Force
    Set-Content $file $resIds

    #Start maintenance
    $uri = "api/resources/maintained?"+$resIds
   
    $startMaintObj = callvrops $uri "Put"

} else {
    #Grab IDs of maintained resources from file
    #TODO - this really is basic, need to include more/better verification and validation

    $resIds = Get-Content $file

    #End maintenance
    $uri = "api/resources/maintained?"+$resIds

    $endMaintObj = callvrops $uri "Delete"
}