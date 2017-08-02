<cfcomponent>
<cfoutput>


<!--- 
ts={
	inquiries_id:,
	dataStruct:inquiryDataStruct,
	site_id:request.zos.globals.id
};
rs=storeCustomerForInquiry(ts);
if(rs.success){
	// associate to record
	// form.customer_id=rs.data.customer_id;
}
 --->
<cffunction name="storeCustomerForInquiry" localmode="modern" access="public">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	ts={
		site_id:request.zos.globals.id
	};
	ss=arguments.ss;
	ds=ss.dataStruct;
	structappend(ss, ts, false);
	db=request.zos.queryObject;


	phone=trim(application.zcore.functions.zFormatInquiryPhone(ds.inquiries_phone1));
	email=trim(ds.inquiries_email);

	if(len(phone) < 7 and len(email) < 5){
		// can't make a customer record without a unique phone or email.
		return { success:false};
	}

	db.sql="select * from #db.table("customer", request.zos.zcoreDatasource)# where 
	(";
	if(phone NEQ ""){
		db.sql&=" customer_phone1 = #db.param(phone)# or customer_phone2 = #db.param(phone)# or customer_phone3 = #db.param(phone)# ";
	}
	if(email NEQ ""){
		if(phone NEQ ""){
			db.sql&=" or ";
		}
		db.sql&=" customer_email=#db.param(arguments.email)# ";
	}
	db.sql&=" ) and 
	customer_deleted=#db.param(0)# and 
	site_id=#db.param(arguments.site_id)# 
	LIMIT #db.param(0)#, #db.param(1)# ";
	qCustomer=db.execute("qCustomer");

	cs={};
	for(row in qCustomer){
		cs=row;
	}

	cs=mapInquiryDataToCustomerData(ts.dataStruct, cs);


	t2={
		struct:cs,
		datasource:request.zos.zcoreDatasource,
		table:"customer"
	};
	if(qCustomer.recordcount EQ 0){
		// setup fields

		customer_id=application.zcore.functions.zInsert(t2);
	}else{
		t2.struct.customer_id=qCustomer.customer_id;
		application.zcore.functions.zUpdate(t2);
	}

	return {success:true, customer_id:customer_id};
	// user / mail_user / track_user are all the same, but different code writes to them.  If i add customer, i will still need to connect the other ones eventually.
	</cfscript>
</cffunction>

<cffunction name="mapInquiryDataToCustomerData" localmode="modern" access="public">
	<cfargument name="inquiryData" type="struct" required="yes">
	<cfargument name="customerData" type="struct" required="yes">
	<cfscript>
	ds=arguments.inquiryData;
	cs=arguments.customerData;
 
	cs.site_id=ss.site_id; 
	// need phone to be formatted here to guarantee a match
 
	if(cs.customer_phone1_formatted EQ phone or cs.customer_phone2_formatted EQ phone or cs.customer_phone3_formatted EQ phone){
		// leave as is
	}else if(cs.customer_phone1_formatted EQ ""){
		cs.customer_phone1=ds.inquiries_phone1;
		cs.customer_phone1_formatted=phone;
	}else if(cs.customer_phone2_formatted EQ ""){
		cs.customer_phone2=ds.inquiries_phone1;
		cs.customer_phone2_formatted=phone;
	}else if(cs.customer_phone3_formatted EQ ""){
		cs.customer_phone3=ds.inquiries_phone1;
		cs.customer_phone3_formatted=phone;		
	}
	if(cs.customer_email NEQ email){
		cs.customer_email=email;
	}

	cs.customer_deleted=0;
	cs.office_id=application.zcore.functions.zso(ds, 'office_id'); 

	cs.customer_company=application.zcore.functions.zso(ds, 'inquiries_company');
	//cs.customer_salutation
	cs.customer_first_name=application.zcore.functions.zso(ds, 'inquiries_first_name');
	cs.customer_last_name=application.zcore.functions.zso(ds, 'inquiries_last_name');
	cs.customer_address=application.zcore.functions.zso(ds, 'inquiries_address');
	cs.customer_city=application.zcore.functions.zso(ds, 'inquiries_city');
	cs.customer_state=application.zcore.functions.zso(ds, 'inquiries_state');
	cs.customer_country=application.zcore.functions.zso(ds, 'inquiries_country');
	cs.customer_postal_code=application.zcore.functions.zso(ds, 'inquiries_zip');

	cs.customer_interested_in_model=application.zcore.functions.zso(ds, 'inquiries_interested_in_model');
	cs.customer_interest_level=application.zcore.functions.zso(ds, 'inquiries_interest_level');
	cs.customer_interested_in_category=application.zcore.functions.zso(ds, 'inquiries_interested_in_category');

	// don't need these yet
	//cs.customer_suffix
	//cs.customer_job_title
	//cs.customer_birthday  
	//cs.customer_spouse_first_name
	//cs.customer_spouse_suffix
	//cs.customer_spouse_job_title
	//cs.customer_lead_source
	//cs.customer_form_name
	//cs.customer_received_date
	//cs.customer_interests
	/*cs.customer_interested_in_type
	cs.customer_interested_in_year
	cs.customer_interested_in_make
	cs.customer_interested_in_model
	cs.customer_interested_in_category
	cs.customer_interested_in_name
	cs.customer_interested_in_hin_vin
	cs.customer_interested_in_stock
	cs.customer_interested_in_length
	cs.customer_interested_in_currently_owned_type
	cs.customer_interested_in_read
	cs.customer_interested_in_age
	cs.customer_interested_in_email
	cs.customer_interested_in_email_alternate
	cs.customer_interested_in_bounce_reason
	cs.customer_interested_in_home_phone
	cs.customer_interested_in_work_phone
	cs.customer_interested_in_mobile_phone
	cs.customer_interested_in_fax
	cs.customer_interested_in_buying_horizon
	cs.customer_interested_in_status
	cs.customer_interested_in_interest_level
	cs.customer_interested_in_sales_stage
	cs.customer_interested_in_date_added
	cs.customer_interested_in_date_updated
	cs.customer_interested_in_customer_source
	cs.customer_interested_in_dealership
	cs.customer_interested_in_assigned_to
	cs.customer_interested_in_bounced_email
	cs.customer_interested_in_owners_magazine
	cs.customer_interested_in_purchased
	cs.customer_interested_in_service_date
	cs.customer_interested_in_date_delivered
	cs.customer_interested_in_date_sold
	cs.customer_interested_in_warranty_date
	cs.customer_interested_in_lead_comments
	*/
	return cs;
	</cfscript>
</cffunction>
			

<!--- 
// The idea in delaying emails may allow the person to improve / fix their email before it goes to the group if they notice a mistake real quick.

// This api only works for leads that are generated from our system.  CRM / API integrations may need additional custom programming.
ts={
	forceUniqueType:true, // prevent multiple scheduled emails of the same type

	// required
	data:{
		inquiries_type_id:"",
		inquiries_type_id_siteIDType:"",
		email_queue_unique:"1", // 1 is unique and 0 allows multiple entries for this type for the same email_queue_to address.
		email_queue_from:"",
		email_queue_to:"",
		email_queue_subject:"",
		email_queue_html:"",
		email_queue_send_datetime:dateadd("m", 30, now())
		// optional
		email_queue_cc:"",
		email_queue_bcc:"",
		email_queue_text:"",
		site_id:request.zos.globals.id
	}
}
scheduleLeadEmail(ts);
 --->
<cffunction name="scheduleLeadEmail" localmode="modern" access="public">
	<cfargument name="ss" type="struct" required="yes">
	<cfscript>
	ss=arguments.ss;
	db=request.zos.queryObject;
	throw("this is incomplete - pseudocode");
	// add email to an email queue table that will go out at specific time.  
	// table has full html. 

	ss.email_queue_send_datetime=dateformat(ss.email_queue_send_datetime, "yyyy-mm-dd")&" "&timeformat(ss.email_queue_send_datetime, "HH:mm:ss");

	ts={
		table:"email_queue",
		datasource:request.zos.zcoreDatasource,
		struct:ss
	};

	update=false;
	if(ss.forceUniqueType){
		// if email already exists, run update instead of insert
		update=true;
	}
	if(update){
		ts.struct.email_queue_id=qCheck.email_queue_id;
		application.zcore.functions.zUpdate(ts);
	}else{
		email_queue_id=application.zcore.functions.zInsert(ts);
	}

	return {success:true, email_queue_id:email_queue_id};
	</cfscript>
</cffunction>


<cffunction name="rescheduleLeadEmail" localmode="modern" access="public">
	<cfscript>
	// the scheduled time should be relative to session expiration, not the initial entry.

	</cfscript>
</cffunction>

<cffunction name="cancelScheduledLeadEmail" localmode="modern" access="public">
	<cfscript>
	db=request.zos.queryObject;

	// delete email from email queue table whether it exists or not 
	</cfscript>
</cffunction>	

</cfoutput>	
</cfcomponent>