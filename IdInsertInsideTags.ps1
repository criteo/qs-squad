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

#Serveur Id
$ServerIdentification = 'frdcdwqlipoc002.criteois.lan'

[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore ssl warning
$cookiejar = New-Object System.Net.CookieContainer


Function Main(){

  GetGlobalCookie
  $idCollection = Import-CSV “$vPathRepertoryScript\IdInsertInsideTags.csv” -delimiter ";"
  $allTags = GetAllTags

  $idCollection | Foreach-Object{

    $content = $_.content
    $id = $_.id
    $name = $_.name
    $idDevForTag = $_.idDevForTag

    if( ($idDevForTag.Length -eq 36))#-and ($id -eq "9f2db04d-e703-4873-9323-4044cbd9e28a")
    {

      switch($content) 
      {
        "SystemRule" 
        {
          $contentInfo = GetInformations "SystemRule" $id
          if( $contentInfo.type -ne 'ReadOnly'){
            addTag "SystemRule" $id $idDevForTag $allTags
          }          
        }
        "DataConnection"
        {
          addTag "DataConnection" $id $idDevForTag $allTags
        }
        "ContentLibrary"
        {
          addTag "ContentLibrary" $id $idDevForTag $allTags
        }
        "Stream"
        {
          addTag "Stream" $id $idDevForTag $allTags
        }
        "reloadtask"
        {
          addTag "reloadtask" $id $idDevForTag $allTags
        }
        "Extension"
        {
          addTag "Extension" $id $idDevForTag $allTags
        }
        "App"
        {
          $contentInfo = GetInformations "App" $id
          if( $contentInfo.published )
          {
            addTag "App" $id $idDevForTag $allTags
          }
        }
      }
    }
  }

}


Function addTag($contentType, $id, $idDevForTag, $allTags)
{
  #GetGlobalCookie
  WriteAndLog "$contentType $id -> $idDevForTag"
  $contentInfo = GetInformations $contentType $id
  $idExist = CheckExistTagId $allTags $idDevForTag
  $tag = $null
  if (-not $idExist){
    $tag = AddTagToQmc $idDevForTag
  }else{
    $tag = GetTagInformations $idExist
  }
  $ContentInfoJSON = GetUpdatedObject $contentInfo $tag
  $ContentInfoJSON | Out-File "$vPathRepertoryScript\$contentTypeInfoJSON.txt"
  UpdateContent $contentType $id $ContentInfoJSON
}

#Function that check if the tag id exists
Function CheckExistTagId($allTags, $idName)
{
  foreach ($current in $allTags) 
  {
    if ($current[2] -eq $idName)
    {
      return $current[0]
    }
  }
  return $false
}

#Get All Tags
Function GetAllTags()
{
  AddLog("GetAllTags()")
  $url = "https://$ServerIdentification/qrs/Tag/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"  
  $method = 'POST'
  $body = '{"entity":"Tag","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"occurrences","columnType":"Function","definition":"Count(EngineService,PrintingService,ProxyService,VirtualProxyConfig,RepositoryService,SchedulerService,ServerNodeConfiguration,App,App.Object,ReloadTask,ExternalProgramTask,UserSyncTask,SystemRule,Stream,User,UserDirectory,DataConnection,Extension,ContentLibrary)"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $rows = $outputObject.rows 
  return $rows
}

Function GetTagInformations($id)
{
  $tagGlobal = GetInformations "Tag" $id
  
  $tagInfo =@{}
  $tagInfo.id = $tagGlobal.id
  $tagInfo.name = $tagGlobal.name
  $tagInfo.privileges = $null
  return $tagInfo
}

Function GetUpdatedObject($object, $tag)
{
  $test = $true
  foreach ($current in $object.tags) 
  {
    if( $current.name -eq $tag.name )
    {
      $test = $false
    }
  }
  if($test)
  {
    $object.tags += $tag
  }
  $toBeUpdated= @{}
  $toBeUpdated.tags = $object.tags
  $theDate = Get-Date
  $toBeUpdated.modifiedDate = $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  $toBeUpdated.id = $object.id
  $objectJSON = $toBeUpdated | ConvertTo-Json

  return $objectJSON
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

#Update the content
Function UpdateContent($content, $id, $param)
{
  AddLog("UpdateSecurityRule $idSecurityRule `r $paramSecurityRules)")  
  $url = "https://$ServerIdentification/qrs/$content/"+$id+"?xrfkey=$XRFKEY"
  $method = "PUT"
  $body = $param
  $result = WebRequestCall $url $method $body  
}

Function AddTagToQmc($tagName){
  AddLog("AddTagToQmc()")
  $url = "https://$ServerIdentification/qrs/Tag?xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"id":"00000000-0000-0000-0000-000000000000","name":"'+$tagName+'","privileges":null,"impactSecurityAccess":false,"schemaPath":"Tag"}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  
  $tagInfo = @{}
  $tagInfo.id = $outputObject.id
  $tagInfo.name = $outputObject.name
  $tagInfo.privileges = $null
  
  return $tagInfo
}

#Get the parameters informations of a content
Function GetInformations($content, $idContent)
{
  AddLog("GetInformations($content, $idSecurityRule)")
  $url = "https://$ServerIdentification/qrs/$content/"+$idContent+"?privileges=true&xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
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

Main