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
	
	if(!arguments.dbUpgradeCom.executeQuery(this.datasource, "ALTER TABLE `inquiries_autoresponder_subscriber`   
  ADD COLUMN `inquiries_autoresponder_subscriber_fail_count` INT(11) UNSIGNED DEFAULT 0 NOT NULL AFTER `inquiries_autoresponder_subscriber_officeid`, 
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`inquiries_autoresponder_subscriber_id`, `site_id`)")){		return false;	}
	 
	return true;
	</cfscript>
</cffunction>
</cfoutput>
</cfcomponent>