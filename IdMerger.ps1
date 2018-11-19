$FichierDev = 'igGetter_frdcdwqlipoc001.criteois.lan.csv'
$FichierProd = 'igGetter_frdcdwqlipoc002.criteois.lan.csv'

$vPathRepertoryScript = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

$Dev = Import-CSV “$vPathRepertoryScript\$FichierDev” -delimiter ";" 
$Prod = Import-CSV “$vPathRepertoryScript\$FichierProd” -delimiter ";"


$releaseTable = New-Object system.Data.DataTable “igGetter $idMerger”

$colContent = New-Object system.Data.DataColumn content,([string])
$colId = New-Object system.Data.DataColumn id,([string])
$colName = New-Object system.Data.DataColumn name,([string])
$idDevForTag = New-Object system.Data.DataColumn idDevForTag,([string])

$releaseTable.columns.add($colContent)
$releaseTable.columns.add($colId)
$releaseTable.columns.add($colName)
$releaseTable.columns.add($idDevForTag)
  
$Prod | Foreach-Object{

  $contentProd = $_.content
  $idProd = $_.id
  $nameProd = $_.name

  $idDevForTag = '';
  $Dev | Foreach-Object{
    
    $contentDev = $_.content 
    $nameDev = $_.name

    if( ($contentProd -eq $contentDev) -and ($nameProd -eq $nameDev))
    {
      $idDevForTag = $_.id
    }

  }

  $row = $releaseTable.NewRow()
  $row.content = $contentProd
  $row.id = $idProd
  $row.name = $nameProd
  $row.idDevForTag = $idDevForTag
  $releaseTable.Rows.Add($row)


}

$textTable = $releaseTable | Out-String
#WriteAndLog "Export release table file : `r $textTable"
$releaseTable | export-csv “$vPathRepertoryScript\IdInsertInsideTags.csv” -noType -delimiter ';'
