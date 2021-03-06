<cfcomponent implements="zcorerootmapping.interface.databaseVersion">
<cfoutput>
<cffunction name="getChangedTableArray" localmode="modern" access="public" returntype="array">
	<cfscript>
	arr1=[];
	return arr1;
	</cfscript>
</cffunction>

<cffunction name="executeUpgrade" localmode="modern" access="public" returntype="boolean">
	<cfargument name="dbUpgradeCom" type="component" required="yes">
	<cfscript>
	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, "ALTER TABLE `event`   
  ADD COLUMN `event_suggested_by_name` VARCHAR(100) NOT NULL AFTER `event_phone`,
  ADD COLUMN `event_suggested_by_email` VARCHAR(100) NOT NULL AFTER `event_suggested_by_name`,
  ADD COLUMN `event_suggested_by_phone` VARCHAR(15) NOT NULL AFTER `event_suggested_by_email`")){
		return false;
	}  

	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>