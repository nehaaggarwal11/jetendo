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
	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, "ALTER TABLE `layout_column`   
  ADD COLUMN `layout_column_sort` INT(11) UNSIGNED DEFAULT 0  NOT NULL AFTER `layout_column_deleted`")){
		return false;
	}   
 

	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>