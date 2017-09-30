<cfcomponent>
<cfoutput>  
<cffunction name="getFieldData" localmode="modern" access="public">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	ss=arguments.ss;  
	var db=request.zos.queryObject; 
	db.sql="SELECT * FROM #db.table("site_option", request.zos.zcoreDatasource)#
	WHERE site_id= #db.param(request.zos.globals.id)# and  
	site_option_group_id <> #db.param(0)# and  
	site_option_group_id = #db.param(ss.site_option_group_id)# and  
	site_option_deleted = #db.param(0)#  
	ORDER BY site_option_group_id ASC, site_option_sort ASC";
	qOption=db.execute("qOption");

	db.sql="SELECT * FROM #db.table("site_option_group", request.zos.zcoreDatasource)#
	WHERE site_id= #db.param(request.zos.globals.id)# and  
	site_option_group_id = #db.param(ss.site_option_group_id)# and  
	site_option_group_deleted = #db.param(0)#  ";
	qGroup=db.execute("qGroup");
	ds={};
	ds.groupStruct={}; 
	for(row in qGroup){
		ds.groupStruct[row.site_option_group_id]={
			data:row, 
			arrOptionOrder:[], 
			options:{}, 
			hasFileFields:false,
			arrParent:[]
		};
	}
	for(i in ds.groupStruct){
		group=ds.groupStruct[i];
		currentGroup=group;
		n=0;
		while(true){
			if(currentGroup.data.site_option_group_parent_id EQ 0){
				break;
			}
			arrayPrepend(ds.groupStruct[i].arrParent, currentGroup.data.site_option_group_parent_id);
			currentGroup=ds.groupStruct[currentGroup.data.site_option_group_parent_id];
			n++;
			if(n GT 25){
				throw("Detected infinite loop in #group.site_option_group_name# parent ids");
			}
		}
	}
	var optionBase=createobject("component", "zcorerootmapping.com.app.option-base");
	typeCFCStruct=optionBase.getOptionTypeCFCs();
	for(i in typeCFCStruct){
		typeCFCStruct[i].init("site", "site");
	}  
	for(row in qOption){
		if(not structkeyexists(ds.groupStruct, row.site_option_group_id)){
			continue;
		}
		typeCFC=typeCFCStruct[row.site_option_type_id];
		json=deserializeJson(row.site_option_type_json);

		group=ds.groupStruct[row.site_option_group_id];
		fieldName=ss.tableName&"_"&replace(application.zcore.functions.zURLEncode(lcase(row.site_option_display_name), "_"), "__", "_", "all");
		dataStruct={
			'uniqueFieldName#row.site_option_id#': ''
		}
		if(row.site_option_type_id EQ 2){
			value=('
			<cfscript>
			htmlEditor = application.zcore.functions.zcreateobject("component", "/zcorerootmapping/com/app/html-editor");
			htmlEditor.instanceName	= "#fieldName#";
			htmlEditor.value			= form.#fieldName#;
			htmlEditor.width			= "100%";
			htmlEditor.height		= #application.zcore.functions.zso(json, 'editorwidth', true, 300)#;
			htmlEditor.create();
			</cfscript>
			');
		}else if(row.site_option_type_id EQ 3){
			value=(' 
			<cfscript>
			application.zcore.functions.zInputImage("#fieldName#", application.zcore.functions.zvar("privatehomedir",request.zos.globals.id)&"#removeChars(ss.uploadDisplayPath, 1 , 1)#", request.zos.currentHostName&"#ss.uploadDisplayPath#",250, true); 
			</cfscript>
			');
		}else if(row.site_option_type_id EQ 9){
			value=('
			<cfscript>
			ts3=StructNew();
			ts3.name="#fieldName#";
			ts3.allowDelete=true;
			ts3.downloadPath="#ss.uploadDisplayPath#";
			application.zcore.functions.zInput_file(ts3);
			</cfscript>
			');
		}else{
			row2=duplicate(row);
			row2.site_option_id="";
			rs=typeCFC.getFormField(row2, json, "uniqueFieldName", dataStruct);
			value=replace(rs.value, "uniqueFieldName", fieldName, "all");
			//value=replace(value, '##', '####', 'all');
		}
		value=replace(value, ' value=""', 'value="##htmleditformat(form.#fieldName#?:"")##"');
 
		ts={
			label:replace(htmleditformat(replace(row.site_option_display_name, "##", "####", "all")), '"', "", "all"),
			columnSQL:typeCFC.getCreateTableColumnSQL(fieldName),
			fieldName:fieldName,
			json:json,
			data:row,
			formField:value,
			beforeInsert:'',
			beforeUpdate:'',
			afterUpdate:'',
			visible:true,
			required:row.site_option_required
		};
		if(row.site_option_type_id EQ 3){
			ts.columnSQL&=", `#ts.fieldName#_original` varchar(255) NOT NULL ";
		}
		if(row.site_option_type_id EQ 12){
			ts.visible=false;
		}
		if(row.site_option_type_id EQ 9 or row.site_option_type_id EQ 3){
			ds.groupStruct[row.site_option_group_id].hasFileFields=true;
		} 

		ds.groupStruct[row.site_option_group_id].options[row.site_option_id]=ts;
		arrayAppend(ds.groupStruct[row.site_option_group_id].arrOptionOrder, row.site_option_id); 
	}
	for(groupId in ds.groupStruct){
		group=ds.groupStruct[groupId];
		// if site_id enabled, add it

		if(ss.enableSiteId){
			ts={
				label:"Site ID",
				columnSQL:"`site_id` int(11) unsigned NOT NULL",
				fieldName:"site_id",
				json:{},
				data:{},
				formField:'',
				beforeUpdate:'',
				afterUpdate:'',
				visible:false,
				required:false
			};
			ds.groupStruct[groupId].options[ts.fieldName]=ts;
			arrayPrepend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
		}

		// add primary key
		ts={
			label:"ID",
			columnSQL:"`#ss.tableName#_id` int(11) unsigned NOT NULL",
			fieldName:ss.tableName&"_id",
			json:{},
			data:{},
			formField:'',
			beforeUpdate:'',
			afterUpdate:'',
			visible:false,
			required:false
		};
		if(not ss.enableSiteId){
			ts.columnSQL&=" AUTO_INCREMENT";
		}
		ds.groupStruct[groupId].options[ts.fieldName]=ts;
		arrayPrepend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
 

		// if sorting enabled add field
		if(ss.enableSorting EQ 1){
			ts={
				label:"Sort",
				columnSQL:"`#ss.tableName#_sort` int(11) unsigned NOT NULL",
				fieldName:ss.tableName&"_sort",
				json:{},
				data:{},
				formField:'',
				beforeUpdate:'',
				afterUpdate:'',
				visible:false,
				required:false
			};
			ds.groupStruct[groupId].options[ts.fieldName]=ts;
			arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
		}

		// if image library enabled, add field
		if(group.data.site_option_group_enable_image_library EQ 1){
			ts={
				label:"Photos",
				columnSQL:"`#ss.tableName#_image_library_id` int(11) unsigned NOT NULL",
				fieldName:ss.tableName&"_image_library_id",
				json:{},
				data:{},
				formField:'',
				beforeUpdate:'',
				afterUpdate:'', // activate image library
				visible:true,
				required:false
			};
			ds.groupStruct[groupId].options[ts.fieldName]=ts;
			arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
 
		}
		if(ss.enableSearch){
			ts={
				label:"Search",
				columnSQL:"`#ss.tableName#_search` LONGTEXT NOT NULL",
				fieldName:ss.tableName&"_search",
				json:{},
				data:{},
				formField:'',
				beforeUpdate:'',
				afterUpdate:'',
				visible:false,
				required:false
			};
			ds.groupStruct[groupId].options[ts.fieldName]=ts;
			arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
		}

		// add created, updated and deleted fields
		ts={
			label:"Date Created",
			columnSQL:"`#ss.tableName#_created_datetime` datetime NOT NULL",
			fieldName:ss.tableName&"_created_datetime",
			json:{},
			data:{},
			formField:'',
			beforeUpdate:'',
			afterUpdate:'',
			visible:false,
			required:false
		};
		ds.groupStruct[groupId].options[ts.fieldName]=ts;
		arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);

		ts={
			label:"Last Updated",
			columnSQL:"`#ss.tableName#_updated_datetime` datetime NOT NULL",
			fieldName:ss.tableName&"_updated_datetime",
			json:{},
			data:{},
			formField:'',
			beforeUpdate:'#ss.tableName#_updated_datetime=request.zos.mysqlnow;',
			afterUpdate:'',
			visible:false,
			required:false
		};
		ds.groupStruct[groupId].options[ts.fieldName]=ts;
		arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);

		ts={
			label:"Deleted",
			columnSQL:"`#ss.tableName#_deleted` int(11) unsigned NOT NULL DEFAULT '0'",
			fieldName:ss.tableName&"_deleted",
			json:{},
			data:{},
			formField:'',
			beforeUpdate:'#ss.tableName#_deleted=0;',
			afterUpdate:'',
			visible:false,
			required:false
		};
		ds.groupStruct[groupId].options[ts.fieldName]=ts;
		arrayAppend(ds.groupStruct[groupId].arrOptionOrder, ts.fieldName);
	}
	/*
	for(id in ds.groupStruct){
		structdelete(ds.groupStruct[id], 'data');
		for(option in ds.groupStruct[id].options){
			structdelete(ds.groupStruct[id].options[option], 'data');
		}
	}*/
	//writedump(ds);	abort;
	// one group at a time here:
	for(groupId in ds.groupStruct){
		group=ds.groupStruct[groupId];
		ds.groupStruct[groupId].createTable=getCreateTable(ss, group); 
	}
	if(ss.enableSiteId){
		ds.groupStruct[groupId].createTable&=chr(10)&chr(10)&'// you must also create the trigger for this table in the database upgrade script using the following code:'&chr(10)&' application.zcore.functions.zCreateSiteIdPrimaryKeyTrigger("#ss.datasource#", "#ss.tableName#", "#ss.tableName#_id"); ';
	}
	return ds.groupStruct[ss.site_option_group_id];
	</cfscript> 
</cffunction>
 
<cffunction name="getCreateTable" localmode="modern" access="public">
	<cfargument name="ss" type="struct" required="yes">
	<cfargument name="ds" type="struct" required="yes">
	<cfscript>
	ss=arguments.ss;
	ds=arguments.ds;
	a=["CREATE TABLE #ss.tableName# ("];

	hasSiteId=false;
	for(i=1;i<=arraylen(ds.arrOptionOrder);i++){
		option=ds.options[ds.arrOptionOrder[i]];
		if(option.fieldName EQ "site_id"){
			hasSiteId=true;
		}
		if(structcount(option.data) NEQ 0 and option.data.site_option_type_id EQ 11){
			continue;
		}
		arrayAppend(a, option.columnSQL&", "); 
	}
	if(hasSiteId){ 
		arrayAppend(a, " PRIMARY KEY (`site_id`,`#ss.tableName#_id`),
		KEY `NewIndex1` (`site_id`), ");
	}else{
		arrayAppend(a, " PRIMARY KEY (`#ss.tableName#_id`) ");
	}
	if(ss.enableSearch){
		arrayAppend(a, ", 
		FULLTEXT INDEX `NewIndex2` (`#ss.tableName#_search`) ");
	}

	arrayAppend(a, ") ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;");

	return arrayToList(a, chr(10));
	</cfscript> 
</cffunction>


<cffunction name="getFormTemplate" localmode="modern" access="public">
	<cfargument name="ss" type="struct" required="yes">
	<cfargument name="fieldData" type="struct" required="yes">
	<cfscript>
	ss=arguments.ss; 
	fd=arguments.fieldData;
	</cfscript>  
<cfsavecontent variable="templateCode">
<cfscript> 
echo('<cfcomponent> 	 
<cfoutput>  
<cffunction name="init" localmode="modern" access="public">
	<cfscript>');
	if(ss.enableSorting){
		echo(' 
	var queueSortStruct = StructNew();
	variables.queueSortCom = application.zcore.functions.zcreateobject("component", "zcorerootmapping.com.display.queueSort");
	queueSortStruct.tableName = "{tableName}";
	queueSortStruct.datasource={datasource};
	queueSortStruct.sortFieldName = "{tableName}_sort";
	queueSortStruct.primaryKeyName = "{tableName}_id";
	queueSortStruct.where=" {tableName}_deleted=''0''  ');
	if(ss.enableSiteId){
		echo(' and site_id=##db.param(request.zos.globals.id)## ');
	}
	echo(' ";
	queueSortStruct.ajaxURL="{adminURL}index";
	queueSortStruct.ajaxTableId="sortRowTable";
	variables.queueSortCom.init(queueSortStruct);
	variables.queueSortCom.returnJson();');
	}
	echo('
	</cfscript>
</cffunction>

<cffunction name="delete" localmode="modern" access="remote" roles="administrator">
	<cfscript>
	init(); 
	var db=request.zos.queryObject; 
	db.sql="SELECT * FROM ##db.table("{tableName}", {datasource})##
	WHERE {tableName}_id= ##db.param(application.zcore.functions.zso(form,"{tableName}_id"))## and  
	{tableName}_deleted = ##db.param(0)##  ');
	if(ss.enableSiteId){
		echo(' and 
		site_id=##db.param(request.zos.globals.id)## ')
	}
	echo('";
	qCheck=db.execute("qCheck");
	
	if(qCheck.recordcount EQ 0){
		application.zcore.status.setStatus(Request.zsid, "{friendlyName} doesnt exist or was already removed", false,true);
		application.zcore.functions.zRedirect("{adminURL}index?zsid=##request.zsid##");
	} 
	');
	if(fd.hasFileFields){
		// process file uploads...
		for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
			optionId=fd.arrOptionOrder[i];
			option=fd.options[optionId];
			if(option.site_option_type_id EQ 3){
				// image
				echo(' 
				application.zcore.functions.zDeleteFile("#ss.uploadPath#"&qCheck.#option.fieldName#_original");
				application.zcore.functions.zDeleteFile("#ss.uploadPath#"&qCheck.#option.fieldName#");
				');
			}else if(option.site_option_type_id EQ 9){
				// file
				echo('
				application.zcore.functions.zDeleteFile("#ss.uploadPath#"&qCheck.#option.fieldName#");
				');

			}else if(option.site_option_type_id EQ 23){
				// image library
				echo('
				application.zcore.imageLibraryCom.deleteImageLibraryId(qCheck.#option.fieldName#);
				');
			}else if(option.fieldName EQ ss.tableName&"_image_library_id"){
				// image library
				echo('
				application.zcore.imageLibraryCom.deleteImageLibraryId(qCheck.#ss.tableName#_image_library_id);
				');
			}
		}
	} 

	echo('
	db.sql="DELETE FROM ##db.table("{tableName}", {datasource})## WHERE 
	{tableName}_id= ##db.param(application.zcore.functions.zso(form, "{tableName}_id"))## and  
	{tableName}_deleted = ##db.param(0)##   ');
	if(ss.enableSiteId){
		echo(' and 
		site_id=##db.param(request.zos.globals.id)## ')
	}
	echo('";
	q=db.execute("q");

	');
	if(ss.enableSorting){
		echo('variables.queueSortCom.sortAll(); ');
	}
	echo('
	application.zcore.status.setStatus(Request.zsid, "{friendlyName} deleted");
	application.zcore.functions.zRedirect("{adminURL}index?zsid=##request.zsid##");
	</cfscript> 
</cffunction>

<cffunction name="insert" localmode="modern" access="remote" roles="administrator">
	<cfscript>
	this.update();
	</cfscript>
</cffunction>

<cffunction name="update" localmode="modern" access="remote" roles="administrator">
	<cfscript>
	var ts={};
	var result=0;
	init(); 
	');
	for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
		optionId=fd.arrOptionOrder[i];
		option=fd.options[optionId];
		if(!option.required){
			continue;
		}
		echo('ts.#option.fieldName#.required=true;
		ts.#option.fieldName#.friendlyName="#option.label#";
		');
	}
	echo('
	error = application.zcore.functions.zValidateStruct(form, ts, Request.zsid,true);
	if(error){	
		application.zcore.status.setStatus(Request.zsid, false,form,true);
		if(form.method EQ "insert"){
			application.zcore.functions.zRedirect("{adminURL}add?zsid=##request.zsid##");
		}else{
			application.zcore.functions.zRedirect("{adminURL}edit?{tableName}_id=##form.{tableName}_id##&zsid=##request.zsid##");
		}
	}  
	');
	if(fd.hasFileFields and ss.uploadPath NEQ ""){
		echo('
		application.zcore.functions.zCreateDirectory("#ss.uploadPath#");
		');
	}

	if(ss.enableSearch){
		echo('arrSearch=[];
		');
		for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
			optionId=fd.arrOptionOrder[i];
			option=fd.options[optionId];
			if(!option.visible){
				continue;
			}
			echo('arrayAppend(arrSearch, form["'&option.fieldName&'"]);
			');
		}
		echo(' 
		form.{tableName}_search = arrayToList(arrSearch, " ");
		form.{tableName}_search=application.zcore.functions.zCleanSearchText(form.{tableName}_search, true);
			');

	}
	if(fd.hasFileFields){
		// process file uploads...
		for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
			optionId=fd.arrOptionOrder[i];
			option=fd.options[optionId];
			if(option.site_option_type_id EQ 3){
				// image 
				photoresize=application.zcore.functions.zso(option.json, 'imagewidth',false,'1000')&"x"&application.zcore.functions.zso(option.json, 'imageHeight',false,'1000');
				if(application.zcore.functions.zso(option.json, 'imagecrop', true, 0) EQ '1'){
					crop="1";
				}else{
					crop="0";
				}
				echo('
				arrList = application.zcore.functions.zUploadResizedImagesToDb("#option.fieldName#", "#ss.uploadPath#", "#photoresize#","","","",{datasource}, #crop#, request.zos.globals.id, false);

				if(isarray(arrList) EQ false){
					fail=true;
					application.zcore.status.setStatus(request.zsid, "<strong>PHOTO ERROR:</strong> invalid format or corrupted.  Please upload a jpeg, png or gif file.<br />"&request.zImageErrorCause, form, true);
				}else if(ArrayLen(arrList) NEQ 0){
					form.#option.fieldName#_original=request.zos.lastUploadFileName; 
					form.#option.fieldName#=arrList[1];
				}
				');
			}else if(option.site_option_type_id EQ 9){
				// file
				
				echo(' 
				form.#option.fieldName#=application.zcore.functions.zUploadFileToDb("#option.fieldName#", "#ss.uploadPath#", "#ss.tableName#", "#ss.tableName#_id", application.zcore.functions.zso(form, "#option.fieldName#_deleted", true, 0), {datasource}); 
				');

			}
		}
	}

	echo('
	form.{tableName}_deleted=0;
	form.{tableName}_updated_datetime=request.zos.mysqlnow; 
	ts=StructNew();
	ts.table="{tableName}";
	ts.datasource={datasource};
	ts.struct=form;
	if(form.method EQ "insert"){
		form.#ss.tableName#_created_datetime=request.zos.mysqlnow;
		form.{tableName}_id = application.zcore.functions.zInsert(ts);
		if(form.{tableName}_id EQ false){
			application.zcore.status.setStatus(request.zsid, "Failed to save {friendlyName}.",form,true);
			application.zcore.functions.zRedirect("{adminURL}add?zsid=##request.zsid##");
		}else{
			application.zcore.status.setStatus(request.zsid, "{friendlyName} saved.");
			');
			if(ss.enableSorting){
				echo('variables.queueSortCom.sortAll(); ');
			}
			echo('
		}
	}else{
		if(application.zcore.functions.zUpdate(ts) EQ false){
			application.zcore.status.setStatus(request.zsid, "Failed to save {friendlyName}.",form,true);
			application.zcore.functions.zRedirect("{adminURL}edit?{tableName}_id=##form.{tableName}_id##&zsid=##request.zsid##");
		}else{
			application.zcore.status.setStatus(request.zsid, "{friendlyName} updated.");
		} 
	} 
	');
	if(fd.hasFileFields){
		// process file uploads...
		for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
			optionId=fd.arrOptionOrder[i];
			option=fd.options[optionId];
			if(option.data.site_option_type_id EQ 23){
				// image library
				echo('
				application.zcore.imageLibraryCom.activateLibraryId(application.zcore.functions.zso(form, "#option.fieldName#"));
				');
			}else if(option.fieldName EQ ss.tableName&"_image_library_id"){
				// image library
				echo('
				application.zcore.imageLibraryCom.activateLibraryId(application.zcore.functions.zso(form, "#ss.tableName#_image_library_id"));
				');
			}
		}
	} 

	echo('
	// TODO: consider storing in "search" table when search is enabled

	application.zcore.functions.zRedirect("{adminURL}index?zsid=##request.zsid##");
	</cfscript>
</cffunction>

<cffunction name="add" localmode="modern" access="remote" roles="administrator">
	<cfscript>
	this.edit();
	</cfscript>
</cffunction>

<cffunction name="edit" localmode="modern" access="remote" roles="administrator">
	<cfscript> 
	init(); 
	var db=request.zos.queryObject; 
	var currentMethod=form.method; 
	form.{tableName}_id=application.zcore.functions.zso(form, "{tableName}_id", true, 0);
	db.sql="SELECT * FROM ##db.table("{tableName}", {datasource})##
	WHERE  
	{tableName}_deleted = ##db.param(0)## and  
	{tableName}_id=##db.param(form.{tableName}_id)##');
	if(ss.enableSiteId){
		echo(' and 
		site_id=##db.param(request.zos.globals.id)## ')
	}
	echo('";
	q{tableName}=db.execute("q{tableName}");
	application.zcore.functions.zQueryToStruct(q{tableName});
	application.zcore.functions.zStatusHandler(request.zsid,true);
	</cfscript>
	<h2><cfif currentMethod EQ "add">
		Add
		<cfscript>
		application.zcore.functions.zCheckIfPageAlreadyLoadedOnce();
		</cfscript>
	<cfelse>
		Edit
	</cfif>
	{friendlyName}</h2>
	 
	<cfscript>
	tabCom=application.zcore.functions.zcreateobject("component","zcorerootmapping.com.display.tab-menu");
			tabCom.init();
	tabCom.setTabs(["Basic"]);
	tabCom.setMenuName("admin-list"); 
	cancelURL="{adminURL}index"; 
	tabCom.setCancelURL(cancelURL);
	tabCom.enableSaveButtons();
	</cfscript>
	<p>* denotes required field.</p>
	<form id="listForm1" action="{adminURL}<cfif currentMethod EQ "add">insert<cfelse>update</cfif>?{tableName}_id=##form.{tableName}_id##" method="post" ');
	if(fd.hasFileFields){
		echo(' enctype="multipart/form-data" ');
	}
	echo('>
	##tabCom.beginTabMenu()##
	##tabCom.beginFieldSet("Basic")##

	<table style="width:100%;" class="table-list">  
		');
		for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
			optionId=fd.arrOptionOrder[i];
			option=fd.options[optionId];
			if(!option.visible){
				continue;
			}
			echo('<tr>
				<th>'&option.label&' ');
				if(option.required){
					echo(' *');
				}
				echo('</th>
				<td>'&trim(option.formField)&'</td>
			</tr>'&chr(10));
		}
		echo('
	</table>

	##tabCom.endFieldSet()##  
	##tabCom.endTabMenu()##    
	</form>
</cffunction>

<cffunction name="index" localmode="modern" access="remote" roles="administrator">
	<cfscript>
	var db=request.zos.queryObject; 
	init();  
	application.zcore.functions.zStatusHandler(request.zsid);

	form.zIndex=application.zcore.functions.zso(form, "zIndex",true, 1); 
	');
	if(ss.enableSearch){
		echo('	form.{tableName}_search=application.zcore.functions.zso(form, "{tableName}_search"); 
		searchOn=false; 
		cleanSearch=application.zcore.functions.zCleanSearchText(form.{tableName}_search);
		');
	}
 	echo('
	db.sql="SELECT {tableName}.* "; ');

	if(ss.enableSearch){

		echo('
		if(form.{tableName}_search NEQ ""){

			db.sql &= ", IF ( concat(`{tableName}`.{tableName}_id, ##db.param(" ")##, `{tableName}`.{tableName}_search) LIKE ##db.param("%"& application.zcore.functions.zURLEncode( form.{tableName}_search, "%")&"%")##, ##db.param("1")##, ##db.param("0")## ) exactMatch,
				MATCH( `{tableName}`.{tableName}_search) AGAINST(##db.param(cleanSearch)##) relevance ";
		}
	');
	}
	echo('	db.sql&=" 
		from ##db.table("{tableName}", {datasource})##  
	WHERE  
	{tableName}_deleted = ##db.param(0)## ');
	if(ss.enableSiteId){
		echo(' and 
		site_id=##db.param(request.zos.globals.id)## ')
	}
	echo('";
	if(form.{tableName}_search NEQ ""){
		searchOn=true;
		db.sql&=" and (
			MATCH({tableName}_search) AGAINST (##db.param(cleanSearch)##) or 
			{tableName}_search like ##db.param("%##application.zcore.functions.zURLEncode(form.{tableName}_search, "%")##%")## or {tableName}.{tableName}_id =##db.param(form.{tableName}_search)##) ";
	}  
	if(form.{tableName}_search NEQ ""){
		db.sql&=" ORDER BY exactMatch DESC, relevance DESC ";
	}else{
		');

		arrOrder=[];
		if(ss.enableSorting){
			arrayAppend(arrOrder, ss.tableName&"."&ss.tableName&"_sort ASC");
		}else{
			for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
				optionId=fd.arrOptionOrder[i];
				option=fd.options[optionId]; 
				if(structcount(option.data) EQ 0 or option.data.site_option_admin_sort_field EQ 0){
					continue;
				}
				arrayAppend(arrOrder, ss.tableName&"."&option.fieldName&" ASC");
			}
			if(arraylen(arrOrder) EQ 0){
				arrayAppend(arrOrder, ss.tableName&"."&ss.tableName&"_id ASC");
			}
		}
		echo (' db.sql&=" ORDER BY #arrayToList(arrOrder, ', ')# ";
	}
	db.sql&=" LIMIT ##db.param((form.zIndex-1)*30)##, ##db.param(30)##";
	q{tableName}=db.execute("q{tableName}");

	');
	if(ss.enableSearch){
		echo('db.sql="SELECT count({tableName}_id) count 
	 from ##db.table("{tableName}", {datasource})##  
	WHERE  
	{tableName}_deleted = ##db.param(0)## ');
	if(ss.enableSiteId){
		echo(' and 
		site_id=##db.param(request.zos.globals.id)## ')
	}
	echo('";
	if(form.{tableName}_search NEQ ""){
		searchOn=true;
		db.sql&=" and (
			MATCH({tableName}_search) AGAINST (##db.param(cleanSearch)##) or 
			{tableName}_search like ##db.param("%##application.zcore.functions.zURLEncode(form.{tableName}_search, "%")##%")## or {tableName}.{tableName}_id =##db.param(form.{tableName}_search)##) ";
	}  
	qCount=db.execute("qCount"); 
		');
	}
	echo('
	searchStruct = StructNew();
	searchStruct.showString = "";
	searchStruct.indexName = "zIndex";
	searchStruct.url = "{adminURL}index');
	if(ss.enableSearch){
		echo('?{tableName}_search=##urlencodedformat(form.{tableName}_search)##');
	}
	echo('";
	searchStruct.index=form.zIndex;
	searchStruct.buttons = 5;
	searchStruct.count = qCount.count;
	searchStruct.perpage = 30;
	searchNav=application.zcore.functions.zSearchResultsNav(searchStruct);
	if(qCount.count <= searchStruct.perpage){
		searchNav="";
	}
	</cfscript>
	<h2>Manage {friendlyName}s</h2>
	<p><a href="{adminURL}add">Add {friendlyName}</a></p> 
	');
	if(ss.enableSearch){
		echo('
	<form action="{adminURL}index" method="get">
		<table class="table-list">
			<tr>
				<td><h2>Search</h2></td>
				<td>
					Keyword or ID: <input type="text" name="{tableName}_search" style="min-width:200px;width:200px;" value="##htmleditformat(form.{tableName}_search)##">
				</td> 
				<td>
					<input type="submit" name="search1" value="Search"> 
					<cfif searchOn>
		
						<input type="button" name="showall1" value="Show All" onclick="window.location.href=''{adminURL}index'';">
					</cfif>
				</td>
			</tr>
		</table>
	</form>
	');
	}
	echo('
	<cfif q{tableName}.recordcount EQ 0>
		<p>No {friendlyName}s found.</p>
	<cfelse>
		##searchNav##
		<table ');
			if(ss.enableSorting){
				echo('id="sortRowTable" ');
			}
			echo(' class="table-list">
			<thead>
			<tr>
				<th>ID</th> ');
			for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
				optionId=fd.arrOptionOrder[i];
				option=fd.options[optionId];
				if(structcount(option.data) EQ 0 or option.data.site_option_primary_field EQ 0){
					continue;
				}
				echo('
				<th>'&option.label&'</th>');
			}

				echo(' 
				<th>Updated Date</th>  
				');
				if(ss.enableSorting){
					echo('<th>Sort</th> ');
				}
				echo('
				<th>Admin</th>
			</tr>
			</thead>
			<tbody>
				<cfloop query="q{tableName}">
				<tr ');
				if(ss.enableSorting){
					echo('##variables.queueSortCom.getRowHTML(q{tableName}.{tableName}_id)## ');
				}
				echo('<cfif q{tableName}.currentRow MOD 2 EQ 0>class="row2"<cfelse>class="row1"</cfif>>
					<td>##q{tableName}.{tableName}_id##</td> 
					');

				for(i=1;i<=arraylen(fd.arrOptionOrder);i++){
					optionId=fd.arrOptionOrder[i];
					option=fd.options[optionId]; 
					if(structcount(option.data) EQ 0 or option.data.site_option_primary_field EQ 0){
						continue;
					}
					echo('
					<td>##q{tableName}.#option.fieldName###</td> ');
				}
				if(ss.enableSorting){
					echo('
					<td style="vertical-align:top; ">##variables.queueSortCom.getAjaxHandleButton(q{tableName}.{tableName}_id)##</td>'&chr(10));
				}
				echo('
					<td> 
					<a href="{adminURL}view?##{tableName}_id=q{tableName}.{tableName}_id##" target="_blank">View</a> | 
					<a href="{adminURL}edit?{tableName}_id=##q{tableName}.{tableName}_id##">Edit</a> |  
						<a href="{adminURL}delete?{tableName}_id=##q{tableName}.{tableName}_id##" onclick="return window.confirm("Are you sure you want to remove this {friendlyName}?");">Delete</a> 

					</td>

				</tr>
				</cfloop>
			</tbody>
		</table>
		##searchNav##
	</cfif>
</cffunction>
</cfoutput>
</cfcomponent>');
</cfscript>
</cfsavecontent>
	<cfscript>
	templateCode=replace(templateCode, '{tableName}', ss.tableName, "all");
	templateCode=replace(templateCode, '{datasource}', ss.datasource, "all");
	templateCode=replace(templateCode, '{friendlyName}', ss.friendlyName, "all");
	templateCode=replace(templateCode, '{adminURL}', ss.adminURL, "all");

	return templateCode;
	</cfscript>

</cffunction>
</cfoutput>
</cfcomponent>