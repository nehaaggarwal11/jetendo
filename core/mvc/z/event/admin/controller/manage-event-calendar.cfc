<cfcomponent>
<cfoutput>


<cffunction name="delete" localmode="modern" access="remote" roles="member">
	<cfscript>
	var db=request.zos.queryObject; 
	application.zcore.adminSecurityFilter.requireFeatureAccess("Manage Event Categories", true);
	db.sql="SELECT * FROM #db.table("event_calendar", request.zos.zcoreDatasource)# event_calendar
	WHERE event_calendar_id= #db.param(application.zcore.functions.zso(form,'event_calendar_id'))# and 
	event_calendar_deleted = #db.param(0)# and
	site_id = #db.param(request.zos.globals.id)#";
	qCheck=db.execute("qCheck");
	
	if(qCheck.recordcount EQ 0){
		application.zcore.status.setStatus(Request.zsid, 'Event calendar no longer exists', false,true);
		application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/index?zsid=#request.zsid#');
	}
	</cfscript>
	<cfif structkeyexists(form,'confirm')>
		<cfscript> 
		db.sql="DELETE FROM #db.table("event_calendar", request.zos.zcoreDatasource)#  
		WHERE event_calendar_id= #db.param(application.zcore.functions.zso(form, 'event_calendar_id'))# and 
		event_calendar_deleted = #db.param(0)# and 
		site_id = #db.param(request.zos.globals.id)# ";
		q=db.execute("q");

		// also delete the categories and events attached to this calendar?

		application.zcore.status.setStatus(Request.zsid, 'Event calendar deleted');
		application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/index?zsid=#request.zsid#');
		</cfscript>
	<cfelse>
		<div style="font-size:14px; font-weight:bold; text-align:center; "> Are you sure you want to delete this event calendar?<br />
			<br />
			#qCheck.event_calendar_name#br />
			<br />
			<a href="/z/event/admin/manage-event-calendar/delete?confirm=1&amp;event_calendar_id=#form.event_calendar_id#">Yes</a>&nbsp;&nbsp;&nbsp;
			<a href="/z/event/admin/manage-event-calendar/index">No</a> 
		</div>
	</cfif>
</cffunction>

<cffunction name="insert" localmode="modern" access="remote" roles="member">
	<cfscript>
	this.update();
	</cfscript>
</cffunction>

<cffunction name="update" localmode="modern" access="remote" roles="member">
	<cfscript>
	var ts={};
	var result=0;
	variables.init();
	application.zcore.adminSecurityFilter.requireFeatureAccess("Manage Event Categories", true);
	form.site_id = request.zos.globals.id;
	ts.event_calendar_name.required = true;
	result = application.zcore.functions.zValidateStruct(form, ts, Request.zsid,true);
	if(result){	
		application.zcore.status.setStatus(Request.zsid, false,form,true);
		if(form.method EQ 'insert'){
			application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/add?zsid=#request.zsid#');
		}else{
			application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/edit?event_calendar_id=#form.event_calendar_id#&zsid=#request.zsid#');
		}
	}
	ts=StructNew();
	ts.table='event_calendar';
	ts.datasource=request.zos.zcoreDatasource;
	ts.struct=form;
	if(form.method EQ 'insert'){
		form.event_calendar_id = application.zcore.functions.zInsert(ts);
		if(form.event_calendar_id EQ false){
			application.zcore.status.setStatus(request.zsid, 'Failed to save event calendar.',form,true);
			application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/add?zsid=#request.zsid#');
		}else{
			application.zcore.status.setStatus(request.zsid, 'Event calendar saved.');
			variables.queueSortCom.sortAll();
		}
	}else{
		if(application.zcore.functions.zUpdate(ts) EQ false){
			application.zcore.status.setStatus(request.zsid, 'Failed to save event calendar.',form,true);
			application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/edit?event_calendar_id=#form.event_calendar_id#&zsid=#request.zsid#');
		}else{
			application.zcore.status.setStatus(request.zsid, 'Event calendar updated.');
		}
		
	} 
	application.zcore.functions.zRedirect('/z/event/admin/manage-event-calendar/index?zsid=#request.zsid#');
	</cfscript>
</cffunction>

<cffunction name="add" localmode="modern" access="remote" roles="member">
	<cfscript>
	this.edit();
	</cfscript>
</cffunction>

<cffunction name="edit" localmode="modern" access="remote" roles="member">
	<cfscript> 
	var db=request.zos.queryObject; 
	var currentMethod=form.method;
	var htmlEditor=0;
	application.zcore.functions.zSetPageHelpId("10.4");
	application.zcore.adminSecurityFilter.requireFeatureAccess("Manage Event Calendars");	
	if(application.zcore.functions.zso(form,'event_calendar_id') EQ ''){
		form.event_calendar_id = -1;
	}
	db.sql="SELECT * FROM #db.table("event_calendar", request.zos.zcoreDatasource)# event_calendar 
	WHERE site_id =#db.param(request.zos.globals.id)# and 
	event_calendar_deleted = #db.param(0)# and 
	event_calendar_id=#db.param(form.event_calendar_id)#";
	qEvent=db.execute("qEvent");
	application.zcore.functions.zQueryToStruct(qEvent);
	application.zcore.functions.zStatusHandler(request.zsid,true);
	</cfscript>
	<h2>
		<cfif currentMethod EQ "add">
			Add
			<cfscript>
			application.zcore.functions.zCheckIfPageAlreadyLoadedOnce();
			</cfscript>
		<cfelse>
			Edit
		</cfif> Calendar</h2>
	<form action="/z/event/admin/manage-event-calendar/<cfif currentMethod EQ 'add'>insert<cfelse>update</cfif>?event_calendar_id=#form.event_calendar_id#" method="post">
		<table style="width:100%;" class="table-list">
			<tr>
				<th>Name</th>
				<td><input type="text" name="event_calendar_name" value="#htmleditformat(form.event_calendar_name)#" /></td>
			</tr> 
			<tr>
				<th>Unique URL</th>
				<td><input type="text" name="event_calendar_unique_url" value="#htmleditformat(form.event_calendar_unique_url)#" /></td>
			</tr> 
			<tr>
				<th style="width:1%;">&nbsp;</th>
				<td><button type="submit" name="submitForm">Save</button>
					<button type="button" name="cancel" onclick="window.location.href = '/z/event/admin/manage-event-calendar/index';">Cancel</button></td>
			</tr>
		</table>
	</form>
</cffunction>

<cffunction name="index" localmode="modern" access="remote" roles="member">
	<cfscript>
	db=request.zos.queryObject;
	application.zcore.adminSecurityFilter.requireFeatureAccess("Manage Event Calendars");	
	application.zcore.functions.zSetPageHelpId("10.3");
	db.sql="select * from #db.table("event_calendar", request.zos.zcoreDatasource)# WHERE 
	site_id = #db.param(request.zos.globals.id)# and 
	event_calendar_deleted=#db.param(0)# ";
	qList=db.execute("qList");

	eventCom=application.zcore.app.getAppCFC("event");
	eventCom.getAdminNavMenu();
	</cfscript>
	<h2>Manage Calendars</h2>

	<p><a href="/z/event/admin/manage-event-calendar/add">Add Calendar</a></p>

	<table class="table-list">
		<tr>
			<th>Name</th>
			<th>Admin</th>
		</tr>
		<cfscript>
		for(row in qList){
			echo('<tr>
				<td>#row.event_calendar_name#</td>
				<td>
					<a href="#eventCom.getCalendarURL(row)#" target="_blank">View</a> | 
					<a href="/z/event/admin/manage-event-calendar/edit?event_calendar_id=#row.event_calendar_id#">Edit</a> | 
					<a href="##" onclick="zDeleteTableRecordRow(this, ''/z/event/admin/manage-event-calendar/delete?event_calendar_id=#row.event_calendar_id#&amp;returnJson=1&amp;confirm=1''); return false;">Delete</a>
				</td>
			</tr>');

		}
		</cfscript>  
	</table>
</cffunction>
</cfoutput>
</cfcomponent>