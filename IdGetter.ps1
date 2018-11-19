#Params
$XRFKEY = 'somerandomstring'

#Logs
$vPathRepertoryScript = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
$currentScriptName = $MyInvocation.MyCommand.Name 
$currentScriptName = $currentScriptName.substring(0,$($currentScriptName.lastindexofany(".")))
$PathFile = "$vPathRepertoryScript\$($currentScriptName)_Log.txt"
$logFile = New-Item -type file $PathFile -Force

#Stop script when error
$ErrorActionPreference = "Stop"

[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore ssl warning
$cookiejar = New-Object System.Net.CookieContainer

#Create Table
$releaseTable = New-Object system.Data.DataTable “igGetter $ServerIdentification”


Function Main()
{
  
  WriteAndLog "Create technical table release"
  #creation of the table that will be exported
  $colContent = New-Object system.Data.DataColumn content,([string])
  $colId = New-Object system.Data.DataColumn id,([string])
  $colName = New-Object system.Data.DataColumn name,([string])
  
  $releaseTable.columns.add($colContent)
  $releaseTable.columns.add($colId)
  $releaseTable.columns.add($colName)
  
  #Cookie for using POST request
  GetGlobalCookie

  #Security Rules
  WriteAndLog "Get security rules"
  $AllSecurityRules = GetAllSecurityRules
  $nbSecurityRules = CountContent 'SystemRule'
  addLines 'SystemRule' $nbSecurityRules $AllSecurityRules
  
  #Data connections
  WriteAndLog "Get data connections"  
  $AllDataConnections = GetAllDataConnections
  $nbDataConnection = CountContent 'DataConnection'
  addLines 'DataConnection' $nbDataConnection $AllDataConnections

  #Analytic connections
  WriteAndLog "Get analytic connections"   
  $AllAnalyticConnection = GetAllAnalyticConnection
  $nbAnalyticConnection = CountContent 'AnalyticConnection'
  addLines 'AnalyticConnection' $nbAnalyticConnection $AllAnalyticConnection

  #Content library
  WriteAndLog "Get content library"     
  $AllContentLibrary = GetAllContentLibrary
  $nbContentLibrary = CountContent 'ContentLibrary'
  addLines 'ContentLibrary' $nbContentLibrary $AllContentLibrary

  #Custom properties
  WriteAndLog "Get custom properties"  
  $allCustomProperties = GetAllCustomProperties
  $nbCustomProperties = CountContent 'CustomPropertyDefinition'
  addLines 'CustomPropertyDefinition' $nbCustomProperties $AllCustomProperties
  
  #Streams
  WriteAndLog "Get Streams" 
  $AllStreams = GetAllStreams
  $nbStream = CountContent 'Stream'
  addLines 'Stream' $nbStream $AllStreams

  #Tasks
  WriteAndLog "Get Tasks"   
  $AllTask = GetAllTask
  $nbTask = CountContent 'reloadtask'
  addLines 'reloadtask' $nbTask $AllTask
  
  #Apps
  WriteAndLog "Get Apps"  
  $AllApp = GetAllApp
  $nbApp = CountContent 'App'
  addLines 'App' $nbApp $AllApp
  
  #Extension
  WriteAndLog "Get Extension" 
  $AllExtension = GetAllExtension
  $nbExtension = CountContent 'Extension'
  addLines 'Extension' $nbExtension $AllExtension

  $textTable = $releaseTable | Out-String
  #WriteAndLog "Export release table file : `r $textTable"
  $releaseTable | export-csv “$vPathRepertoryScript\igGetter_$ServerIdentification.csv” -noType -delimiter ';'
}

#Add line to the export file
Function addLines($content, $nblines, $Collection)
{
  WriteAndLog "addLines($content, $nblines)"
  if( $nblines -gt 1)
  {
    foreach ($current in $Collection)
    {
      $id = $current[0]
      $name = $current[2]
      WriteAndLog "$id - $name"
    
      $row = $releaseTable.NewRow()
      $row.content = $content
      $row.id = $id
      $row.name = $name
      $releaseTable.Rows.Add($row)
    }
  }
  elseif($nblines -eq 1)
  { 
    $id = $Collection[0] 
    $name = $Collection[2]
    WriteAndLog "$id - $name"

    $row = $releaseTable.NewRow()
    $row.content = $content
    $row.id = $id
    $row.name = $name
    $releaseTable.Rows.Add($row)
  }
}

#Create the cookie needed to use POST queries
Function GetGlobalCookie()
{
  AddLog("GetGlobalCookie()")
  $url = "https://$ServerIdentification/qrs/SystemRule/count?filter=category+eq+%27security%27&xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
}

#Get the number of count specified
Function CountContent($idContent)
{
  AddLog("CountContent($idContent)")
  $url = "https://$ServerIdentification/qrs/$idContent/count?xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject.value
}

#Get All custom propoerties
Function GetAllCustomProperties()
{
  AddLog("GetAllCustomProperties()")
  $url = "https://$ServerIdentification/qrs/CustomPropertyDefinition/table?orderAscending=false&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"CustomPropertyDefinition","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"objectTypes","columnType":"Property","definition":"objectTypes"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Get All content library
Function GetAllContentLibrary()
{
  AddLog("GetAllContentLibrary()")
  $url = "https://$ServerIdentification/qrs/ContentLibrary/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"ContentLibrary","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"owner","columnType":"Property","definition":"owner"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Get All Analytic connections
Function GetAllAnalyticConnection()
{
  AddLog("GetAllAnalyticConnection()")
  $url = "https://$ServerIdentification/qrs/AnalyticConnection/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"AnalyticConnection","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"host","columnType":"Property","definition":"host"},{"name":"port","columnType":"Property","definition":"port"},{"name":"certificateFilePath","columnType":"Property","definition":"certificateFilePath"},{"name":"reconnectTimeout","columnType":"Property","definition":"reconnectTimeout"},{"name":"requestTimeout","columnType":"Property","definition":"requestTimeout"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Get All Streams
Function GetAllStreams()
{
  AddLog("GetAllStreams()")

  $url = "https://$ServerIdentification/qrs/Stream/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"Stream","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows
  return $rows

}

#Ask for all security rules
Function GetAllSecurityRules()
{
  AddLog("GetAllSecurityRules()")
  $url = "https://$ServerIdentification/qrs/SystemRule/table?filter=(category eq 'Security')&orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"SystemRule","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"comment","columnType":"Property","definition":"comment"},{"name":"resourceFilter","columnType":"Property","definition":"resourceFilter"},{"name":"actions","columnType":"Property","definition":"actions"},{"name":"disabled","columnType":"Property","definition":"disabled"},{"name":"ruleContext","columnType":"Property","definition":"ruleContext"},{"name":"type","columnType":"Property","definition":"type"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Ask for all DataConnection
Function GetAllDataConnections()
{
  AddLog("GetAllDataConnections()")
  $url = "https://$ServerIdentification/qrs/DataConnection/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"DataConnection","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"owner","columnType":"Property","definition":"owner"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Ask for all App
Function GetAllApp()
{
  AddLog("GetAllDataConnections()")
  $url = "https://$ServerIdentification/qrs/App/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"App","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"owner","columnType":"Property","definition":"owner"},{"name":"publishTime","columnType":"Property","definition":"publishTime"},{"name":"AppStatuss","columnType":"List","definition":"AppStatus","list":[{"name":"statusType","columnType":"Property","definition":"statusType"},{"name":"statusValue","columnType":"Property","definition":"statusValue"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"stream","columnType":"Property","definition":"stream"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

#Ask for all Extensions
Function GetAllExtension()
{
  AddLog("GetAllDataConnections()")
  $url = "https://$ServerIdentification/qrs/Extension/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"Extension","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"owner","columnType":"Property","definition":"owner"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows

}

#Ask for all Task
Function GetAllTask()
{
  AddLog("GetAllTask()")
  $url = "https://$ServerIdentification/qrs/reloadtask/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"reloadtask","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"compositeEvents","columnType":"Function","definition":"Count(CompositeEvent)"},{"name":"compositeEventRules","columnType":"Function","definition":"Count(CompositeEvent.Rule)"},{"name":"userDirectory.name","columnType":"Property","definition":"userDirectory.name"},{"name":"app.name","columnType":"Property","definition":"app.name"},{"name":"name","columnType":"Property","definition":"name"},{"name":"taskType","columnType":"Property","definition":"taskType"},{"name":"enabled","columnType":"Property","definition":"enabled"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}


#write inside the console and the log folder
Function WriteAndLog($text)
{
  Write-Host $text
  AddLog $text
}

#add a line inside the log file
Function AddLog($text)
{
  $vDate = get-date -format "yyyy/MM/dd HH:mm:ss"
  $MyLine = "$vDate - $text"
  add-content $logFile $MyLine
}

#Function that perform a REST request
Function WebRequestCall($url, $method, $body)
{  
  WriteAndLog("WebRequestCall $url")
  WriteAndLog("Headers { Method : $method, ContentType : application/json;charset=UTF-8,  UserAgent : Mozilla/5.0 (Windows NT 6.1; WOW64), X-Qlik-Xrfkey : $XRFKEY")
  WriteAndLog("Cookie : $cookiejar")
  WriteAndLog("Body : $body")  
  WriteAndLog("Start request")  
  $webrequest = [System.Net.HTTPWebRequest]::Create($url);
  $webrequest.Headers.Add("X-Qlik-Xrfkey",$XRFKEY)
  $webrequest.ContentType = 'application/json;charset=UTF-8'
  $webrequest.UserAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64)'
  $webrequest.Method = $method
  $webrequest.UseDefaultCredentials = $true
  $webrequest.CookieContainer = $cookiejar
  if (($method -eq 'POST') -or ($method -eq 'PUT'))
  {
    $BodyByte = [byte[]][char[]]$body
    $Stream = $webrequest.GetRequestStream();
    $Stream.Write($BodyByte, 0, $BodyByte.Length);
  }
  $response = $webrequest.GetResponse()
  $responseStream = $response.GetResponseStream()
  $streamReader = New-Object System.IO.Streamreader($responseStream)
  $output = $streamReader.ReadToEnd() 
  WriteAndLog("End request")  
  WriteAndLog("Response : $output")
  return $output
}

Function GetEnv()
{
  $result = Read-Host -Prompt "Enter 0 for dev 1 for prod"

  Switch ($result)
  {
    0 {
        return 'FRDCDWQLIS001.criteois.lan'
    }   
    1 {
        return 'FRDCPWQLIS001.criteois.lan'
    }   
    2 {
        return 'frdcdwqlipoc001.criteois.lan'
    }   
    3 {
        return 'frdcdwqlipoc002.criteois.lan'
    }
    default {
      GetEnv
    }
  }

  return $Environment
}

#Serveur Id
$ServerIdentification = GetEnv 

#Appel du programme principal
Main
WriteAndLog("Success")