## Introduction
SQUAD is a powershell tool that enable apps transport between two different Qlik Sense instance. This is useful for testing Qlik configuration on a sandbox 


## Prerequisites :

 - The user that start SQUAD must have licence and rights in order to use Qlik Sense. 
 - Modify Prepare program in order to set the right servers URL. 
 - Production Server site : Tag all apps, Streams, Data Connections, ReloadTask with the corresponding Dev id of the entity.    You can use IdGetter, IdMerger et IdInsertInsideTags in order to help this insert.
 - Authentication is made with AD strategy (UseDefaultCredentials)
 - Instance must be set under Prepare.ps1: 
	- Server Source:      $ServerIdentification
	- Server Destination: $ServerIdentification


### /!\ ACHTUNG :
- There might be a bug in the QMC with the display of reload task using SQUAD. This bug is known and reported to Qlik. Sometimes Task Status, Last execution and Next execution is shown as "never refresh" but the task is actually working.
- Transport applications with SQUAD should not be done when applications are reloading.


## How it's work :

The powershell's script Prepare.ps1 is run with a config file (csv) against the non-prod tenant. After that, folder Release.[Version] is created with Release.[Version].ps1 script inside, and can be run against production tenant. 

The powershell's script work with a csv file as input, describe as follow: 

| ENTITY   | ACTION                    | ID_DEV            | ID_PROD              | PARAM               |
| -------- | ------------------------- | ----------------- | -------------------- | ------------------- |
| Entity   |**Transport** or **Delete**| id in staging env | id in production env | optional parameters |

CSV file must be name as Prepare.[Version].csv

**Entities name handle by Squad:**
- App
- SystemRule
- DataConnection
- ReloadTask
- Stream
- CustomPropertyDefinition
- Tag

### Transport:

The transport Create, Replace, Update, Publish with the informations contained in the source version. You must enter the type of entity and the DEV id of the entity you want to transport.

**App**
  - Be careful that the stream, where the app is published, exists in PROD with a tag referering to the same stream id in DEV. 
  - Be careful if you tag an app manually in Prod that the app is published in the same Stream than in prod. 

**DataConnection**
  - PARAM refers to a Connection String such as "OLEDB CONNECT32 TO [Provider=XXX;Data Source=C:\XXX.mdb;]". You have to fulfill in order to pass your connection string.
  - Be careful not to use Data connection with name that contain "PROD", "REC", "INT". Data connections should always be generic.
 
**ReloadTask**
  - Be careful that the app, to which the stream refers, exists in PROD with a tag referering to the same app id in DEV. 
  - Be careful, when you release a task containing a trigger, that the task to which the trigger refers already exists and has a tag referering to the same task in DEV.
  - Be careful when you want to add a task for an app that the Business Analyst created in prod, this one should contain the tag id referering to the same app in DEV.

**Tags**
  - Tags are automaticaly created and added when it's linked to one of the entities above

**Custom Property**
  - Custom Properties are automaticaly created and added when it's linked to one of the entities above
  
 ### Delete:

The delete drop task, app, etc... You must enter the type of entity and the production id of the entity you want to delete.


### Input file sample:

    ENTITY|ACTION|ID_DEV|ID_PROD|PARAM
	App|Transport|331dacb2-2e1b-463d-a1c4-9a26227df176||
	App|Delete||331dacb2-2e1b-463d-a1c4-9a26227df176|
	DataConnection|Transport|mcgd02dv-ae58-dks6-dfhj-7a673bfadhv2||
	DataConnection|Transport|406d36fc-de10-49a6-b8ca-7a673bf77ae2||OLEDB CONNECT32 TO [Provider=XXX;Data Source=C:\XXX.mdb;]
	DataConnection|Delete||e78c02dv-ae58-dks6-dfhj-5785a29cbba2|
	SystemRule|Transport|4cbd12a3-e892-4f81-a983-4d47fb053696||
	SystemRule|Delete||6f47079c-3f4a-44fc-8636-70641df90637|
	ReloadTask|Transport|04ce67ab-1864-44ed-940d-294daab2628b||
	ReloadTask|Delete||8715320b-1a18-4753-96d2-8cd13c75808b|
	CustomPropertyDefinition|Delete|||CustomPropertyNameToDelete
	Tag|Delete|||TagNameToDelete
	Tag|Clear|||


## Authors

-   **Charley Beaudouin**  -  _Initial work_  -  [Criteo](https://github.com/criteo/qs-squad)

See also the list of  [contributors](https://github.com/criteo/qs-squad/graphs/contributors)  who participated in this project.


## License
This project is licensed under the Apache 2.0 license.


## Contributing

Any contribution are welcome, as an issue or pull request. 

When contributing to this repository, please first discuss the change you wish to make via issue, email, or any other method with the owners of this repository before making a change. 

Please note we have a code of conduct, please follow it in all your interactions with the project:
* Using welcoming and inclusive language
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Showing empathy towards other community members