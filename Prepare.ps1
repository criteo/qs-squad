# Last modification : 01/02/2018
# By : Charley Beaudouin
# Version : 3.0

# GOLBAL PARAMS
##########################################################################################################

#Params
$XRFKEY = 'somerandomstring'

#Logs
$vPathRepertoryScript = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
$currentScriptName = $MyInvocation.MyCommand.Name 
$fileTimeName = get-date -format "yyyy-MM-dd-HH-mm-ss"
$currentScriptName = $currentScriptName.substring(0,$($currentScriptName.lastindexofany(".")))
$PathFile = "$vPathRepertoryScript\$($currentScriptName)_Log_$fileTimeName.txt"
$logFile = New-Item -type file $PathFile -Force

#Stop script when error
$ErrorActionPreference = "Stop"

#Server Source
if ($currentScriptName -eq 'Prepare')
{
  $ServerIdentification = 'XXX'
}
#Server Destination
if ($currentScriptName -eq 'Release')
{
  $ServerIdentification = 'XXX'
}

# Get Credentaials, add them to cache
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore ssl warning
$cookiejar = New-Object System.Net.CookieContainer

#Create Table
$releaseTable = New-Object system.Data.DataTable “releaseTable”

#creation of the release table columns
$colEntity = New-Object system.Data.DataColumn entity,([string])
$colAction = New-Object system.Data.DataColumn action,([string])
$colName = New-Object system.Data.DataColumn name,([string])
$colId = New-Object system.Data.DataColumn id,([string])
$filename = New-Object system.Data.DataColumn filename,([string])
$colJson = New-Object system.Data.DataColumn json,([string])
$colStatus = New-Object system.Data.DataColumn status,([string])

#Columns added to the table
$releaseTable.columns.add($colEntity)
$releaseTable.columns.add($colAction)
$releaseTable.columns.add($colName)
$releaseTable.columns.add($colId)
$releaseTable.columns.add($filename)
$releaseTable.columns.add($colJson)
$releaseTable.columns.add($colStatus)

# Main Functions
##########################################################################################################

#Main function to create the prepare file
Function Prepare()
{

  WriteAndLog $version

  #The first request must be a get in order to retrieve the cookie
  GetGlobalCookie
  
  #Create the export folder
  CreateAndReplaceRepository

  #get the param csv
  $prepareCSV = Import-CSV “$vPathRepertoryScript\$nameFile” -delimiter "|"
  
  #course the csv of import
  $prepareCSV  | Foreach-Object{
    $entity = $_.ENTITY
    $action = $_.ACTION
    $idSource = $_.ID_DEV
    $idDestination = $_.ID_PROD
    $param = $_.PARAM
  
    WriteAndLog "CSV Line : $entity | $action | $idSource | $idDestination | $param"

    #Dispatch to the right function
    switch($action)
    {
      'Transport'
      {
        if (($entity -eq 'SystemRule') -or ($entity -eq 'DataConnection') -or ($entity -eq 'ReloadTask') -or ($entity -eq 'Stream')){
          AddLineTransport $entity $action $idSource $param
        }elseif($entity -eq 'App'){
          AddLineTransportApp $entity $action $idSource
        }else{
          $error = "ERROR : Impossible to transport an entity "+$entity
          throw $error
        }
      }
      'Delete'
      {
        if (($entity -eq 'App') -or ($entity -eq 'SystemRule') -or ($entity -eq 'DataConnection') -or ($entity -eq 'ReloadTask') -or ($entity -eq 'Stream') -or ($entity -eq 'Tag') -or ($entity -eq 'CustomPropertyDefinition')){
          AddLineDelete $entity $idDestination $param
        }else{        
          $error = "ERROR : Impossible to delete an entity "+$entity
          throw $error
        }
      }
      'Clear'
      {
        if (($entity -eq 'Tag')){
          AddLineClear $entity
        }else{
          $error = "ERROR : Impossible to clear entity "+$entity
          throw $error
        }
      }
    }
    WriteAndLog "--> Done"    
  }
  
  #Export the releaseTable
  ExportReleaseTable
}

#Main function to release the update
Function Release()
{
  #The first request must be a get in order to retrieve the cookie
  GetGlobalCookie
  
  #course the csv of release
  $releaseCSV = Import-CSV “$vPathRepertoryScript\$nameFile” -delimiter "|"
  $releaseCSV  | Foreach-Object{
    $entity = $_.entity
    $action = $_.action
    $name = $_.name
    $id = $_.id
    $filename = $_.filename
    $json = $_.json
    $status = $_.status


    WriteAndLog "CSV Line : $entity | $action | $name | $id | $filename  | $json | $status"

    if($status -ne 'done'){
      #Dispatch to the right function
      switch($action)
      {
        'Transport'
        {
          if(($entity -eq 'SystemRule') -or ($entity -eq 'DataConnection') -or ($entity -eq 'ReloadTask') -or ($entity -eq 'Stream')){
            CreateOrUpdateEntityWithTag $entity $json $id
          }elseif($entity -eq 'App'){
            ImportReplacePublishApp $id $name $filename $json
          }else{
            $error = "ERROR : Impossible to transport an entity "+$entity
            throw $error
          }
        }
        'Delete'
        {
          if (($entity -eq 'App') -or ($entity -eq 'SystemRule') -or ($entity -eq 'DataConnection') -or ($entity -eq 'ReloadTask') -or ($entity -eq 'Stream')){
            DeleteCheckEntity $entity $id
          }elseif(($entity -eq 'Tag') -or ($entity -eq 'CustomPropertyDefinition')){
            DeleteEntityByName $entity $name
          }else{        
            $error = "ERROR : Impossible to delete an entity "+$entity
            throw $error
          }
        }
        'Clear'
        {
          if (($entity -eq 'Tag')){
            ClearEntity $entity
          }else{
            $error = "ERROR : Impossible to clear entity "+$entity
            throw $error
          }
        }
      }
    }

    $row = $releaseTable.NewRow()
    $row.entity = $entity
    $row.action = $action
    $row.name = $name
    $row.id = $id
    $row.filename = $filename
    $row.json = $json 
    $row.status = 'done'
    $releaseTable.Rows.Add($row)

    WriteAndLog "--> Done"    
  }
  ExportReleaseTable
  WriteAndLog "Release successful"
}



# REQUESTS
##########################################################################################################

#Create the cookie needed to use POST queries
Function GetGlobalCookie()
{
  AddLog("GetGlobalCookie()")
  $url = "https://$ServerIdentification/qrs/SystemRule/count?filter=category+eq+%27security%27&xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
}

#Function that dispatch to the right GetAll function depending on entities
Function GetAllDispatcher($entity){
  AddLog("GetAllDispatcher($entity)")
  switch($entity)
  {
    'SystemRule'
    {
      return GetAllSystemRule
    }
    'DataConnection'
    {
      return GetAllDataConnections
    }
    'Task'
    {
      return GetAllTask
    }
    'App'
    {
      return GetAllApp
    }
    'Tag'
    {
      return GetAllTags
    }    
    'CustomPropertyDefinition'
    {
      return GetAllCustomProperties
    }
    'Stream'
    {
      return GetAllStreams
    }
    'ReloadTask'
    {
      return GetAllTask
    }
  }
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
  return $outputObject
}

#Get All Custom Properties
Function GetAllCustomProperties(){
  AddLog("GetCustomProperties()")
  $url = "https://$ServerIdentification/qrs/CustomPropertyDefinition/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY" 
  $method = 'POST'
  $body = '{"entity":"CustomPropertyDefinition","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"objectTypes","columnType":"Property","definition":"objectTypes"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json 
  return $outputObject

}

#Ask for all security rules
Function GetAllSystemRule()
{
  AddLog("GetAllSystemRule()")
  $url = "https://$ServerIdentification/qrs/SystemRule/table?filter=(category eq 'Security')&orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"SystemRule","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"comment","columnType":"Property","definition":"comment"},{"name":"resourceFilter","columnType":"Property","definition":"resourceFilter"},{"name":"actions","columnType":"Property","definition":"actions"},{"name":"disabled","columnType":"Property","definition":"disabled"},{"name":"ruleContext","columnType":"Property","definition":"ruleContext"},{"name":"type","columnType":"Property","definition":"type"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Ask for all DataConnection
Function GetAllDataConnections()
{
  AddLog("GetAllDataConnections()")
  $url = "https://$ServerIdentification/qrs/DataConnection/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"DataConnection","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"owner","columnType":"Property","definition":"owner"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Ask for all App
Function GetAllApp()
{
  AddLog("GetAllApp()")
  $url = "https://$ServerIdentification/qrs/App/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"App","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"owner","columnType":"Property","definition":"owner"},{"name":"publishTime","columnType":"Property","definition":"publishTime"},{"name":"AppStatuss","columnType":"List","definition":"AppStatus","list":[{"name":"statusType","columnType":"Property","definition":"statusType"},{"name":"statusValue","columnType":"Property","definition":"statusValue"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"stream","columnType":"Property","definition":"stream"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json 
  return $outputObject
}

#Ask for all Task
Function GetAllTask()
{
  AddLog("GetAllTask()")
  $url = "https://$ServerIdentification/qrs/Task/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"Task","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]},{"name":"compositeEvents","columnType":"Function","definition":"Count(CompositeEvent)"},{"name":"compositeEventRules","columnType":"Function","definition":"Count(CompositeEvent.Rule)"},{"name":"userDirectory.name","columnType":"Property","definition":"userDirectory.name"},{"name":"app.name","columnType":"Property","definition":"app.name"},{"name":"taskType","columnType":"Property","definition":"taskType"},{"name":"enabled","columnType":"Property","definition":"enabled"},{"name":"status","columnType":"Property","definition":"operational.lastExecutionResult.status"},{"name":"operational.lastExecutionResult.startTime","columnType":"Property","definition":"operational.lastExecutionResult.startTime"},{"name":"nextExecution","columnType":"Property","definition":"operational.nextExecution"}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Ask for all streams
Function GetAllStreams(){
  AddLog("GetAllTask()")
  $url = "https://$ServerIdentification/qrs/Stream/table?orderAscending=true&skip=0&sortColumn=name&xrfkey=$XRFKEY"
  $method = 'POST'
  $body = '{"entity":"Stream","columns":[{"name":"id","columnType":"Property","definition":"id"},{"name":"privileges","columnType":"Privileges","definition":"privileges"},{"name":"name","columnType":"Property","definition":"name"},{"name":"tags","columnType":"List","definition":"tag","list":[{"name":"name","columnType":"Property","definition":"name"},{"name":"id","columnType":"Property","definition":"id"}]}]}'
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Get the parameters informations of the specified entity
Function GetInformations($entity, $idEntity)
{
  AddLog("GetInformations $entity $idEntity")
  $url = "https://$ServerIdentification/qrs/$entity/"+$idEntity+"?privileges=true&xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Get the informations of the task and the event triggered linked to the task
Function GetTaskEventInformations($idTask){
  AddLog("GetTaskEventInformations $idTask")
  $url = "https://$ServerIdentification/qrs/event/full?filter=reloadTask.id+eq+$idTask&xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = webRequestCall $url $method $body
  #$result | Out-File "$vPathRepertoryScript\GetTaskEventInformations.txt"
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Update the entity
Function UpdateEntity($entity, $id, $param)
{
  AddLog("Update entity $id `r $paramSecurityRules")  
  $url = "https://$ServerIdentification/qrs/$entity/"+$id+"?xrfkey=$XRFKEY"
  $method = "PUT"
  $body = $param
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json  
  return $outputObject
}

#Publish the App
Function PublishApp($id, $streamId){
  AddLog("PublishApp $id $streamId")  
  $url =  "https://$ServerIdentification/qrs/app/$id/publish?stream={$streamId}&xrfkey=$XRFKEY"
  $method = "PUT"
  $body = ''
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json  
  return $outputObject
}

#Function that Replace an app, identified by {replacedAppId}, with the app identified by {appId}.
Function ReplaceApp($appId, $replacedAppId){
  AddLog("ReplaceApp $replacedAppId by $appId")  
  $url =  "https://$ServerIdentification/qrs/app/$appId/replace?app={$replacedAppId}&xrfkey=$XRFKEY"
  $method = "PUT"
  $body = ''
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json  
  return $outputObject
}

#Function that creates a tag inside the QMC
Function AddTagToQmc($tagName){
  AddLog("AddTagToQmc($tagName)")
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

#Create the entity specified
Function CreateEntity($entity, $paramEntity){
  AddLog "CreateEntity $entity $paramEntity"
  #$url = "https://$ServerIdentification/qrs/"+$entity+"?privileges=true&xrfkey=$XRFKEY"
  $url = "https://$ServerIdentification/qrs/"+$entity+"?xrfkey=$XRFKEY"
  $method = 'POST'
  $body = $paramEntity
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  return $outputObject
}

#Delete the specified entity
Function DeleteEntity($entity, $idEntity)
{ 
  AddLog("DeleteEntity $entity $idEntity")  
  $url = "https://$ServerIdentification/qrs/$entity/"+$idEntity+"?xrfkey=$XRFKEY"
  $method = "DELETE"
  $body = $null
  WebRequestCall $url $method $body  
}

# Controller
##########################################################################################################

#Function that create or update the content inside the qmc adding the specified tag
Function CreateOrUpdateEntityWithTag($entity, $paramEntity, $idTag){  

  $paramEntityObject = $paramEntity | ConvertFrom-Json    
  #-1 check for CustomProperties  
  if([bool]($paramEntityObject.PSobject.Properties.name -match "customProperties") -or [bool]($paramEntityObject.task.PSobject.Properties.name -match "customProperties")){
    
    if($entity -eq 'ReloadTask'){
      $paramEntityObject.task.customProperties = GetOrCreateCustomProperties $paramEntityObject.task.customProperties
    }else{
      $paramEntityObject.customProperties = GetOrCreateCustomProperties $paramEntityObject.customProperties
    }        
  }
  $paramEntity = $paramEntityObject | ConvertTo-Json -Depth 5

  #0 check the right ids to put to reload task
  if($entity -eq 'ReloadTask'){
    $paramEntity = UpdateInformationsReloadTaskBeforeUpdate $paramEntity
  }

  #1 create the tag if not exists
  $tag = GetOrCreateTag $idTag
  
  #2 check if the entity exist  
  $idEntityFromTagCheck = CheckTagWithinEntites $entity $idTag
  AddLog "idfound : $idEntityFromTagCheck"

  #create
  if( -not $idEntityFromTagCheck){
    CreateEntityWithTag $entity $paramEntity $tag
  #update
  }else{
    if($entity -eq 'ReloadTask'){
      UpdateReloadTaskWithTag $entity $idEntityFromTagCheck $paramEntity $tag
    }else{
      UpdateEntityWithTag $entity $idEntityFromTagCheck $paramEntity $tag
    }
  }
}

#Function that proceed some checks before create or update an entity
#and return the paramEntity with some id modifications if needed
#Check if App linked to reload task exists
#Update App informations  
Function UpdateInformationsReloadTaskBeforeUpdate($paramEntity){
  $paramEntityObject = $paramEntity | ConvertFrom-Json
  $app = @{}
  $app.id = CheckTagWithinEntites 'App' $paramEntityObject.task.app.id
  if(-not $app.id){
    $error = "ERROR : Problem of transport for reloadTask : "+$paramEntityObject.task.name+" no app found corresponding to "+$paramEntityObject.task.app.name+" with id : "+$paramEntityObject.task.app.id
    throw $error
  }
  $paramEntityObject.task.app = $app
  $paramEntityObject.compositeEvents | Foreach-Object{
    $_.compositeRules | Foreach-Object{        
      $testTaskExists = CheckTagWithinEntites 'ReloadTask' $_.reloadTask.id
      if(-not $testTaskExists){
        $error='ERROR : Reload Task corresponding to tag id :'+$_.reloadTask.id+" do not exists"
        throw $error
      }
      $_.reloadTask.id = $testTaskExists
    }
  }
  $paramEntity = $paramEntityObject | ConvertTo-Json -Depth 5
  return $paramEntity
}

#Function that check if the custom properties are the same
Function CompareCustomProperties( $customSource, $customToCompar){
  if($customSource.valueType -ne $customToCompar.valueType){
    return $false
  }
  $result = Compare-Object -ReferenceObject $customSource.choiceValues -DifferenceObject $customToCompar.choiceValues
  if($result -ne $null){
    return $false
  }  
  $result = Compare-Object -ReferenceObject $customSource.objectTypes -DifferenceObject $customToCompar.objectTypes
  if($result -ne $null){
    return $false
  }
  return $true
}

#Function that check if the custom properties
#update the Custom preperty if needed
#or creates it if not exists
#And then return the informations
Function GetOrCreateCustomProperties($customProperties){
  $allCustomObj = GetAllDispatcher "CustomPropertyDefinition"
  $allCustomProperties = $allCustomObj.rows
  $cutomNameExists = $false  
  $cpResult = @()
  foreach ($current in $customProperties){   
    $newCustom =  @{}
    $newCustom.valueType = $current.definition.valueType
    $newCustom.choiceValues = $current.definition.choiceValues
    $newCustom.name = $current.definition.name
    $newCustom.objectTypes = $current.definition.objectTypes
    $customFound = $false
    $idCP = $null
    foreach($customCurrent in $allCustomProperties){
      if ($customCurrent[2] -eq $current.definition.name){
        $newCustom.id = $customCurrent[0]
        $idCP = $customCurrent[0]
        $customFound = $true
        $cpInfo = GetInformations "CustomPropertyDefinition" $customCurrent[0]
        $updateCP = CompareCustomProperties $cpInfo $newCustom
        if(-not $updateCP){
          #Update 
          $theDate = Get-Date
          $newCustom.modifiedDate = $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
          $definitionJson = $newCustom | ConvertTo-Json -Depth 5
          $entityUpdated = UpdateEntity "CustomPropertyDefinition" $customCurrent[0] $definitionJson          
        }
      }
    }
    if(-not $customFound){
      #create new CP
      $definitionJson = ConvertTo-Json $newCustom -Depth 5
      $entityCreated = CreateEntity "CustomPropertyDefinition" $definitionJson 
      $idCP = $entityCreated.id #tobedefined
    }
    $valueCustomEntity = @{}
    $valueCustomEntity.Definition =@{}
    $valueCustomEntity.Definition.ID = $idCP
    $valueCustomEntity.value = $current.value
    $cpResult+=$valueCustomEntity
  }

  #$customPropertiesJSON = ConvertTo-Json $cpResult  -Depth 5
  return ,$cpResult
}

#Function that create or update the content inside the qmc
Function CreateOrUpdateEntity($entity, $paramEntity){
  
  $paramEntityObject = $paramEntity | ConvertFrom-Json 
  $name = $paramEntityObject.name

  #check if the name already exists
  $idEntityCheck = CheckNameWithinEntites $entity $name

  if( -not $idEntityCheck){
    CreateEntity $entity $paramEntity
  }else{
    $theDate = Get-Date
    $paramEntityObject | Add-Member -MemberType NoteProperty -Name "modifiedDate" -Value $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
    $paramEntityJson = $paramEntityObject | ConvertTo-Json -Depth 5
    UpdateEntity $entity $idEntityCheck $paramEntityJson
  }
}

#Function that return the tag that containt the idTag as Name and creates it if not exists
Function GetOrCreateTag($idTag){  
  $idExist = CheckExistEntityByName 'Tag' $idTag
  $tag = $null
  if (-not $idExist){
    $tag = AddTagToQmc $idTag
  }else{
    $tag = GetTagInformationsForUpdate $idExist
  }
  return $tag
}

#Function that creates an entity with the specified tag
Function CreateEntityWithTag($entity, $paramEntity, $tag){
  AddLog "CreateEntityWithTag($entity, $paramEntity, $tag)"
  $paramEntityObject = $paramEntity | ConvertFrom-Json  
  if($entity -eq 'ReloadTask'){  
    $paramEntityObject.task= PrepareTagForCreateUpdate $paramEntityObject.task $tag  
    $entity  = 'ReloadTask/create'
  }else{     
    $paramEntityObject = PrepareTagForCreateUpdate $paramEntityObject $tag     
  }
  $paramEntityJson = $paramEntityObject | ConvertTo-Json -Depth 5
  CreateEntity $entity $paramEntityJson
}

#Function that update an entity with the specified tag
Function UpdateEntityWithTag($entity, $idEntityFromTagCheck, $paramEntity, $tag){
  AddLog "UdateEntityWithTag($entity, $idEntityFromTagCheck, $paramEntity, $tag)"
  $paramEntityObject = $paramEntity | ConvertFrom-Json
  $theDate = Get-Date
  $paramEntityObject | Add-Member -MemberType NoteProperty -Name "modifiedDate" -Value $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  $paramEntityObject = PrepareTagForCreateUpdate $paramEntityObject $tag
  $paramEntityJson = $paramEntityObject | ConvertTo-Json -Depth 5
  UpdateEntity $entity $idEntityFromTagCheck $paramEntityJson
}

#Function that update a reload task and it's events
Function UpdateReloadTaskWithTag($entity, $idEntityFromTagCheck, $paramEntity, $tag){
  AddLog "UpdateReloadTaskWithTag($entity, $idEntityFromTagCheck, $paramEntity, $tag)"
  $paramEntityObject = $paramEntity | ConvertFrom-Json
  $theDate = Get-Date
  $tasksEvent = GetTaskEventInformations $idEntityFromTagCheck
  $schemaEventsToDelete = @()
  $compositeEventsToDelete = @()    
  $tasksEvent | Foreach-Object{  
    If($_.schemaPath -eq 'CompositeEvent'){
      $compositeEventsToDelete+=$_.id
    }elseif($_.schemaPath -eq 'SchemaEvent'){
      $schemaEventsToDelete+=$_.id
    } 
  }
  $paramEntityObject | Add-Member -MemberType NoteProperty -Name "schemaEventsToDelete" -Value $schemaEventsToDelete
  $paramEntityObject | Add-Member -MemberType NoteProperty -Name "compositeEventsToDelete" -Value $compositeEventsToDelete
  $paramEntityObject.task | Add-Member -MemberType NoteProperty -Name "id" -Value $idEntityFromTagCheck
  $paramEntityObject.task= PrepareTagForCreateUpdate $paramEntityObject.task $tag  
  $paramEntityObject.task | Add-Member -MemberType NoteProperty -Name "modifiedDate" -Value $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  $paramEntityObject.schemaEvents | Foreach-Object{
    $reloadTask = @{}
    $reloadTask.id = $idEntityFromTagCheck
    $_ | Add-Member -MemberType NoteProperty -Name "reloadTask" -Value $reloadTask
  }
  $paramEntityObject.compositeEvents | Foreach-Object{
    $reloadTask = @{}
    $reloadTask.id = $idEntityFromTagCheck
    $_ | Add-Member -MemberType NoteProperty -Name "reloadTask" -Value $reloadTask
  }
  $paramEntityJson = $paramEntityObject | ConvertTo-Json -Depth 6
  $paramEntityJson | Out-File "$vPathRepertoryScript\ModifyTask.txt"
  $url = "https://$ServerIdentification/qrs/reloadtask/update?xrfkey=$XRFKEY"
  $method = 'POST'
  $result = webRequestCall $url $method $paramEntityJson
}

#Function that match the paramEntityObject list of tags with the right ids and add a new one if not exist
Function PrepareTagForCreateUpdate($paramEntityObject, $tag){
  $allTags = GetAllDispatcher 'Tag'
  if([bool]($paramEntityObject.PSobject.Properties.name -match "tags")){
    $tagIdDevExists = $false
    foreach ($current in $paramEntityObject.tags){
      if ($current.name -eq $tag.name){
        $tagIdDevExists = $true
      }
      #check if tag exist
      $currentTagId = ''
      foreach ($currentTag in $allTags){
        if($currentTag[2] -eq $current.name){
          $currentTagId = $currentTag[0]
        }
      }
      if($currentTagId.Length -eq 0){
        $newTag = AddTagToQmc($current.name)
        $currentTagId = $newTag.id
      }
      $current.id = $currentTagId
    }    
    if(-not $tagIdDevExists){
      $paramEntityObject.tags += $tag
    }
  }else{
    $tagPoperties = @()
    $paramEntityObject | Add-Member -MemberType NoteProperty -Name "tags" -value $tagPoperties
    $paramEntityObject.tags += $tag
  }
  return $paramEntityObject
}

#Function that return the tag informations in order to add it to an entity
Function GetTagInformationsForUpdate($id)
{
  AddLog("GetTagInformationsForUpdate($id)")
  $tagGlobal = GetInformations "Tag" $id
  
  $tagInfo =@{}
  $tagInfo.id = $tagGlobal.id
  $tagInfo.name = $tagGlobal.name
  $tagInfo.privileges = $null
  return $tagInfo
}

#Function that check an entity id by name
Function CheckExistEntityByName($entity, $idName)
{
  AddLog("CheckExistEntityByName($entity, $idName)")
  $allEntityObject = GetAllDispatcher $entity
  $allEntities = $allEntityObject.rows
  foreach ($current in $allEntities) 
  {
    if ($current[2] -eq $idName)
    {
      return $current[0]
    }
  }
  return $false
}

#Function that check if the id exist for an entity intity inside the QMC and return the following id if it does 
Function CheckTagWithinEntites($entity, $idName)
{
  AddLog("CheckTagWithinEntites($entity, $idName)")
  $collectionEntityObject = GetAllDispatcher $entity
  $collectionEntity= $collectionEntityObject.rows
  foreach ($current in $collectionEntity) 
  {    
   foreach ($value in $current[3].rows){
     if ($value[0] -eq $idName){
       return $current[0]
     }
   }
  }
  return $false
}


#Function that check if the name exist for an entity intity inside the QMC and return the following id if it does 
Function CheckNameWithinEntites($entity, $nameEntity){
  AddLog("CheckTagWithinEntites($entity, $idName)")
  $collectionEntityObject = GetAllDispatcher $entity
  $collectionEntity= $collectionEntityObject.rows
  foreach ($current in $collectionEntity) 
  {    
     if($current[3] -eq 0){
       
     }
  }
}

#Function that clear all entities not used
Function ClearEntity($entity)
{
  $allEntityObject = GetAllDispatcher $entity
  GetGlobalCookie
  $allEntities = $allEntityObject.rows
  foreach ($current in $allEntities) 
  {
    if ($current[3] -eq 0)
    {
      DeleteEntity $entity $current[0]
    }
  }

}

#Function that remove the entity using the name
Function DeleteEntityByName($entity, $name)
{
  AddLog "DeleteEntityByName : $entity $name" 
  GetGlobalCookie
  $resultId = CheckExistEntityByName $entity $name
  if (-not $resultId)
  {
    $textError = “ERROR : $entity $name do not exist” 
    throw $textError
  }

  DeleteEntity $entity $resultId
}

#Function that remove the content
Function DeleteCheckEntity($entity, $idEntity)
{
  AddLog "DeleteCheckEntity : $entity $idEntity" 

  GetGlobalCookie
  $CheckExisId = CheckExistId $entity $idEntity
  if (-not $CheckExisId)
  {
    $textError = “ERROR : $entity $idEntity do not exist” 
    throw $textError
  }
  DeleteEntity $entity $idEntity
}

#Modify the Json for update the content
Function PrepareJsonForUpdate($content, $paramContentObj, $informations)
{
  $theDate = Get-Date
  $paramContentObj.modifiedDate = $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  $paramContentObj.createdDate = $informations.createdDate
  if ($content -eq 'Data Connection')
  {
    $paramContentObj.owner = $informations.owner
  }
  $paramContent = $paramContentObj | ConvertTo-Json -Depth 5

  return $paramContent
}

#Function that check if the id exists
Function CheckExistId($entity, $id)
{
  AddLog "CheckExistId($entity, $id)"
  $listAllIdObject = GetAllDispatcher $entity
  $listAllId = $listAllIdObject.rows
  foreach ($current in $listAllId) 
  {
    if ($current[0] -eq $id)
    {
      AddLog($id+' exist')
      return $true
    }
  }
  AddLog($id+' do not exist')
  return $false
}

#Global function that create a line for create or updating a content
Function AddLineTransport($entity, $action, $idOrigin, $param)
{
  AddLog "AddLine($entity, $action, $idOrigin, $param)"

  GetGlobalCookie
  $CheckExisId = CheckExistId $entity $idOrigin
  if (-not $CheckExisId)
  {
    $textError = “ERROR : $entity $idOrigin do not exist” 
    throw $textError
  }
  $informations = GetInformations $entity $idOrigin
  $informationsString  = $informations | ConvertTo-Json -Depth 5
  #$informationsString  | Out-File "$vPathRepertoryScript\informationsString.txt"

  $jsonCreateUpdate = PrepareJsonCreateUpdate $entity $informations $param
  $jsonCreateUpdateString  = $jsonCreateUpdate | ConvertTo-Json -Depth 5
  #$jsonCreateUpdateString  | Out-File "$vPathRepertoryScript\jsonCreateUpdateString.txt"

  $row = $releaseTable.NewRow()
  $row.entity = $entity
  $row.action = $action
  $row.name = $informations.name
  $row.id = $informations.id
  $row.filename = $null
  $row.json = $jsonCreateUpdateString
  
  $releaseTable.Rows.Add($row)
}

Function GetCustomPropertiesInfo($customProperties){
  $cpResultInfosArr = @()
  #1 boucler sur les differentes CP
  foreach ($current in $customProperties) 
  {
    $cpInfo = GetInformations "CustomPropertyDefinition" $current.definition.id
    $cpSource = @{}
    $cpSource.name = $cpInfo.name
    $cpSource.valueType  = $cpInfo.valueType
    $cpSource.choiceValues = $cpInfo.choiceValues
    $cpSource.objectTypes = $cpInfo.objectTypes
    $cpInfosMap = @{}
    $cpInfosMap.value = $current.value
    $cpInfosMap.definition = $cpSource
    $cpResultInfosArr+= $cpInfosMap
    
  }
  $cpResultInfosJSON =  $cpResultInfosArr | ConvertTo-Json -Depth 5
  AddLog $cpResultInfosJSON
  return $cpResultInfosArr 
}

#Prepare the JSON used to create or update an entity depending on this type
Function PrepareJsonCreateUpdate($entity, $informations, $param){
  
  $informationsJSON = $informations | ConvertTo-Json -Depth 5
  AddLog 'PrepareJsonCreateUpdate : '+$entity+' '+$informationsJSON

  $jsonCreateUpdate = @{}
  
  switch($entity) 
  {
    "Stream"
    {
      $jsonCreateUpdate.name = $informations.name
      $jsonCreateUpdate.tags = $informations.tags
      $jsonCreateUpdate.customProperties = GetCustomPropertiesInfo $informations.customProperties
    }
    "SystemRule" 
    {
      $jsonCreateUpdate.name = $informations.name
      $jsonCreateUpdate.rule = $informations.rule
      $jsonCreateUpdate.comment = $informations.comment
      $jsonCreateUpdate.ruleContext = $informations.ruleContext
      $jsonCreateUpdate.disabled = $informations.disabled
      $jsonCreateUpdate.category = $informations.category
      $jsonCreateUpdate.resourceFilter = $informations.resourceFilter
      $jsonCreateUpdate.actions = $informations.actions
      $jsonCreateUpdate.type = $informations.type
      $jsonCreateUpdate.schemaPath = $informations.schemaPath
      $jsonCreateUpdate.privileges = $informations.privileges
      $jsonCreateUpdate.impactSecurityAccess = $informations.impactSecurityAccess
      $jsonCreateUpdate.tags = $informations.tags
    }
    "DataConnection" 
    {
      $jsonCreateUpdate.name = $informations.name
      #$jsonCreateUpdate.connectionstring = $informations.connectionstring
      if (-not ([string]::IsNullOrEmpty($param))){
        $jsonCreateUpdate.connectionstring = $param
      }
      $jsonCreateUpdate.type = $informations.type
      $jsonCreateUpdate.username = $informations.username
      $jsonCreateUpdate.tags = $informations.tags
      $jsonCreateUpdate.customProperties = GetCustomPropertiesInfo $informations.customProperties
    }
    "App" 
    {
      $jsonCreateUpdate.name = $informations.name
      $jsonCreateUpdate.tags = $informations.tags
      $jsonCreateUpdate.published = $informations.published
      $jsonCreateUpdate.stream = $informations.stream
      $jsonCreateUpdate.description = $informations.description
      $jsonCreateUpdate.customProperties = GetCustomPropertiesInfo $informations.customProperties
    }
    "ReloadTask"
    {
      $jsonCreateUpdate.task =  @{}
      $jsonCreateUpdate.task.name = $informations.name
      $jsonCreateUpdate.task.app = $informations.app
      $jsonCreateUpdate.task.enabled = $informations.enabled
      $jsonCreateUpdate.task.taskSessionTimeout = $informations.taskSessionTimeout
      $jsonCreateUpdate.task.maxRetries = $informations.maxRetries
      $jsonCreateUpdate.task.customProperties = GetCustomPropertiesInfo $informations.customProperties
      $jsonCreateUpdate.task.tags = $informations.tags    
      #get event triggered linked to the reload task
      $tasksEvent = GetTaskEventInformations $informations.id
      $jsonCreateUpdate.schemaEvents = @()
      $jsonCreateUpdate.compositeEvents = @()
      $tasksEvent | Foreach-Object{
        $name = $_.name      
        $schemaPath = $_.schemaPath   
        AddLog "Add Event :  $schemaPath \ $name"     
        If($_.schemaPath -eq 'CompositeEvent'){
          $newCompositeEvent = @{}
          $newCompositeEvent.name = $_.name
          $newCompositeEvent.enabled = $_.enabled
          $newCompositeEvent.eventType = $_.eventType
          $newCompositeEvent.timeConstraint=@{}
          $newCompositeEvent.timeConstraint.days = $_.timeConstraint.days
          $newCompositeEvent.timeConstraint.hours = $_.timeConstraint.hours
          $newCompositeEvent.timeConstraint.minutes = $_.timeConstraint.minutes
          $newCompositeEvent.timeConstraint.seconds = $_.timeConstraint.seconds
          $newCompositeEvent.compositeRules = @()
          $_.compositeRules | Foreach-Object{
            $newCompositeRule = @{}
            $newCompositeRule.ruleState = $_.ruleState
            $newCompositeRule.reloadTask = @{}
            $reloadTmp = $_.reloadTask
            $newCompositeRule.reloadTask.id =  $reloadTmp.id
            $newCompositeEvent.compositeRules+=$newCompositeRule
          }
          $jsonCreateUpdate.compositeEvents+=$newCompositeEvent
        }elseif($_.schemaPath -eq 'SchemaEvent'){
          $newSchemaEvent = @{}
          $newSchemaEvent.name = $_.name
          $newSchemaEvent.timeZone = $_.timeZone
          $newSchemaEvent.daylightSavingTime = $_.daylightSavingTime
          $newSchemaEvent.startDate = $_.startDate
          $newSchemaEvent.expirationDate = $_.expirationDate
          $newSchemaEvent.incrementDescription = $_.incrementDescription
          $newSchemaEvent.incrementOption = $_.incrementOption        
          $newSchemaEvent.enabled = $_.enabled
          $newSchemaEvent.schemaFilterDescription = $_.schemaFilterDescription
          $jsonCreateUpdate.schemaEvents+=$newSchemaEvent
        }     
      }
    }
  }
  $jsonCreateUpdateString  = $jsonCreateUpdate | ConvertTo-Json -Depth 5
  return $jsonCreateUpdate 
}

#Global function that create a line inside the release document in order to clear a content
Function AddLineClear($entity){
  $row = $releaseTable.NewRow()
  $row.entity = $entity
  $row.action = 'Clear'
  $row.name = $null
  $row.id = $null
  $row.filename = $null
  $row.json = $null

  $releaseTable.Rows.Add($row)
}

#Global function that create a line inside the release document for removing a content
Function AddLineDelete($entity, $idDestination, $idParam){
  $row = $releaseTable.NewRow()
  $row.entity = $entity
  $row.action = 'Delete'
  $row.name = $idParam
  $row.id = $idDestination
  $row.filename = $null
  $row.json = $null

  $releaseTable.Rows.Add($row)
}

#Function that export the app and create a line in the csv Release program in order to Import and replace the application
Function AddLineTransportApp($entity, $action, $idOrigin){
  AddLog "AddLineTransportApp($entity, $action, $idOrigin, $idDestination)"

  GetGlobalCookie
  $CheckExisId = CheckExistId $entity $idOrigin
  if(-not $CheckExisId)
  {
    $textError = “ERROR : $entity $idOrigin do not exist”
    throw  $textError
  }
  $informations = GetInformations $entity $idOrigin
  $jsonCreateUpdate = PrepareJsonCreateUpdate $entity $informations
  $jsonCreateUpdateString  = $jsonCreateUpdate | ConvertTo-Json -Depth 5

  $filename = DownloadApp $idOrigin

  $row = $releaseTable.NewRow()
  $row.entity = $entity
  $row.action = $action
  $row.name = $informations.name
  $row.id = $idOrigin
  $row.filename = $filename
  $row.json = $jsonCreateUpdateString
  
  $releaseTable.Rows.Add($row)

}

#Function that ckeck if the app exist, replace it or create it, modify it's informations and publish it to the good stream if the app is published
Function ImportReplacePublishApp($id, $name, $filename, $paramEntity){
  AddLog "ImportReplacePublishApp($id, $name, $filename, $paramEntity)"

  #check if published stream exist
  $paramEntityObject = $paramEntity | ConvertFrom-Json
  if( $paramEntityObject.published ){
    $idStream = CheckTagWithinEntites 'Stream' $paramEntityObject.stream.id
    if(-not $idStream){
      $textError = 'ERROR : the stream '+$paramEntityObject.stream.name+' do not exist'
      throw $textError 
    }
  }
     
  #check for CustomProperties  
  if([bool]($paramEntityObject.PSobject.Properties.name -match "customProperties")){
    $paramEntityObject.customProperties = GetOrCreateCustomProperties $paramEntityObject.customProperties        
  }
  $paramEntity = $paramEntityObject | ConvertTo-Json -Depth 5

  #check app existance
  $idEntityFromTagCheck = CheckTagWithinEntites 'App' $id
  
  if(-not $idEntityFromTagCheck){
    #import app
    $informations = ImportApp $name $filename
  }else{
    #check if publish and match publish
    $paramEntityObject = $paramEntity | ConvertFrom-Json
    #get informations
    $informations = GetInformations 'App' $idEntityFromTagCheck
    if($informations.published -and $paramEntityObject.published){
      if(($informations.stream.id -ne $idStream)){      
        $textError = 'ERROR : the current app '+$informations.name+' is published in the stream id '+$informations.stream.id+' while the new app should be published in '+$idStream
        throw $textError 
      }
    } 

    $informationsNewApp = ImportApp $name $filename

    #replace app
    ReplaceApp $informationsNewApp.id $idEntityFromTagCheck

    #drop remaining app
    DeleteEntity 'App' $informationsNewApp.id
  }
  
  #add tag to app
  $tag = GetOrCreateTag $id   
  $paramEntityObject = PrepareTagForCreateUpdate $paramEntityObject $tag

  #Publish if app not published
  if($paramEntityObject.published -and (-not $informations.published)){
    PublishApp $informations.id $idStream
  }

  #Update App name tags and Custom properties
  $paramEntityObject.PSObject.Properties.Remove('stream')
  $paramEntityObject.PSObject.Properties.Remove('published')
  $theDate = Get-Date
  if([bool]($paramEntityObject.PSobject.Properties.name -match "modifiedDate")){    
    $paramEntityObject.modifiedDate = $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  }else{
    $paramEntityObject | Add-Member -MemberType NoteProperty -Name "modifiedDate" -value $theDate.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ss.fffZ" )
  }  
  $paramEntityJson = $paramEntityObject | ConvertTo-Json -Depth 5

  #modifie les proprietes
  UpdateEntity 'App' $informations.id $paramEntityJson
}

#Function that import the app inside the qmc
Function ImportApp($name, $filename)
{
  AddLog "ImportApp($name, $filename)"

  #1 copy file inside the right folder
  $url = "https://$ServerIdentification/qrs/app/importfolder?xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $FilePath = WebRequestCall $url $method $body | ConvertFrom-Json
  
  AddLog "Remove filePath : $FilePath and it's content"
  $test = Test-Path $FilePath
  If($test)
  {
    Remove-Item $FilePath -Force -Recurse
  }
  new-item $FilePath -itemtype directory | Out-Null

  
  AddLog "Copy the file $filename to $FilePath"   
  Copy-Item “$vPathRepertoryScript\$filename.qvf” “$FilePath\$filename.qvf”
  
  #2 Import the app
  $url = "https://$ServerIdentification/qrs/app/import?name=$name&keepdata=true&xrfkey=$XRFKEY"
  $url = $url -replace ' ','%20'
  $method = 'POST'
  $body = '"'+$filename+'.qvf"'
  $result = WebRequestCall $url $method $body
  $resultObj = $result | ConvertFrom-Json

  return $resultObj
}

#download an app 
Function DownloadApp($id)
{
  AddLog "DownloadApp $id"
  $url = "https://$ServerIdentification/qrs/app/$id/export?xrfkey=$XRFKEY"
  $method = 'GET'
  $body = $null
  $result = WebRequestCall $url $method $body
  $outputObject= $result | ConvertFrom-Json
  $ticketValue = $outputObject.value

  $idAppAndTicket = "id_"+$id+"_ticketvalue_"+$ticketValue
  $url = "https://$ServerIdentification/qrs/download/app/$id/$ticketValue/Resultapp?xrfkey=$XRFKEY"
  DownloadFile $url "$vPathRepertoryScript\Release.$version\$idAppAndTicket.qvf"
  
  return $idAppAndTicket
}

# Technical
##########################################################################################################

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

#Get the release version from the csv file
Function GetVersion($nameFile){
  $version = $nameFile -replace '.csv',''
  $version = $version -replace 'Prepare.',''
  $version = $version -replace 'Release.',''
  return $version
}

#Erase and recreate Release repository
Function CreateAndReplaceRepository($nameFile)
{  
  AddLog "Create and replace repository $vPathRepertoryScript\Release.$version"
  $test = Test-Path “$vPathRepertoryScript\Release.$version"
  If($test)
  {
    Remove-Item “$vPathRepertoryScript\Release.$version" -Force -Recurse
  }
  new-item “$vPathRepertoryScript\Release.$version" -itemtype directory | Out-Null
  #copy import powershell into repository
  Copy-Item “$vPathRepertoryScript\Prepare.ps1” “$vPathRepertoryScript\Release.$version\Release.ps1”
}

#export the release table
Function ExportReleaseTable()
{
  $textTable = $releaseTable | Out-String
  AddLog "Export release table file : `r $textTable"  
  if ($currentScriptName -eq 'Prepare'){
    $releaseTable | export-csv “$vPathRepertoryScript\Release.$version\Release.$version.csv” -noType -delimiter "|"
  }else{
    $releaseTable | export-csv “$vPathRepertoryScript\Release.$version.csv” -noType -delimiter "|"
  }
}

#Function that perform a REST request
Function WebRequestCall($url, $method, $body)
{  
  AddLog("WebRequestCall $url")
  AddLog("Headers { Method : $method, ContentType : application/json;charset=UTF-8,  UserAgent : Mozilla/5.0 (Windows NT 6.1; WOW64), X-Qlik-Xrfkey : $XRFKEY")
  AddLog("Cookie : $cookiejar")
  AddLog("Body : $body")  
  AddLog("Start request")  
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
  AddLog("End request")  
  AddLog("Response : $output")
  return $output
}

#Function that download a file from an url
Function DownloadFile($url, $targetFile)
{ 
  AddLog("DownloadFile $url")
  $uri = New-Object "System.Uri" "$url" 
  $request = [System.Net.HttpWebRequest]::Create($uri)
  $request.Headers.Add("X-Qlik-Xrfkey",$XRFKEY)
  $request.ContentType = 'application/json;charset=UTF-8'
  $request.UserAgent = 'Mozilla/5.0 (Windows NT 6.1; WOW64)'
  $request.Method = 'GET'
  $request.UseDefaultCredentials = $true
  $request.CookieContainer = $cookiejar 
  $request.set_Timeout(15000) #15 second timeout 
  $response = $request.GetResponse() 
  $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024) 
  $responseStream = $response.GetResponseStream()
  $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create 
  $buffer = new-object byte[] 10KB 
  $count = $responseStream.Read($buffer,0,$buffer.length) 
  $downloadedBytes = $count 
  AddLog "Download Started" 
  while ($count -gt 0) 
  {        
      $targetStream.Write($buffer, 0, $count) 
      $count = $responseStream.Read($buffer,0,$buffer.length)         
  }    
  $targetStream.Flush()
  $targetStream.Close() 
  $targetStream.Dispose() 
  $responseStream.Dispose() 
  AddLog "End Download" 
  AddLog "Exported file : $targetFile"
}

Function GetCSVFile($reg){
  #$files =Get-ChildItem $vPathRepertoryScript | Where-Object {$_.Name -Like "*Prepare*.csv*"}
  $files =Get-ChildItem $vPathRepertoryScript | Where-Object {$_.Name -Like "$reg*"}
  if($files.count -gt 1){
    $error = “ERROR : "+$files.Length+" files Prepare*.csv found ” 
    throw $error
  }else{
    return $files[0].Name
  }  
}

# Program launch
##########################################################################################################

WriteAndLog "Server : $ServerIdentification"
WriteAndLog $currentScriptName

#try catch in order to print the error inside log file
try
{
  if ($currentScriptName -eq 'Prepare')
  {
    $nameFile = GetCSVFile("*Prepare*.csv*")
    $version = GetVersion $nameFile
    Prepare $nameFile
  }
  if ($currentScriptName -eq 'Release')
  {
    $nameFile = GetCSVFile("*Release*.csv*")
    $version = GetVersion $nameFile
    Release $nameFile
  }
}catch{
  if ($currentScriptName -eq 'Release'){
    $releaseCSV = Import-CSV “$vPathRepertoryScript\$nameFile” -delimiter "|"
    $i=0
    $releaseCSV  | Foreach-Object{
      if($i -gt ($releaseTable.rows.Count-1)){
        $row = $releaseTable.NewRow()
        $row.entity = $_.entity
        $row.action = $_.action
        $row.name = $_.name
        $row.id = $_.id
        $row.filename = $_.filename
        $row.json = $_.json
        $row.status = $null
        $releaseTable.Rows.Add($row)
      }

      $i+=1
    }
    ExportReleaseTable
  }

  WriteAndLog $PSItem
  throw $PSItem  
}



WriteAndLog "bye bye :)"