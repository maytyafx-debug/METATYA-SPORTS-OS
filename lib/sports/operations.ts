export type OperationsResource = {
  table: string;
  select: string;
  createFields: readonly string[];
  updateFields: readonly string[];
  readRoles: readonly string[];
  writeRoles: readonly string[];
  required: readonly string[];
  actorField?: string;
  updatedAt?: boolean;
  orderBy?: string;
};

const managers = ["owner", "admin", "staff"] as const;
const coaches = ["owner", "admin", "staff", "coach"] as const;
const privateManagers = ["owner", "admin"] as const;

export const SPORTS_OPERATIONS: Record<string, OperationsResource> = {
  "org-units": {
    table:"sports_org_units",select:"id,parent_id,unit_type,name,code,status,created_at",
    createFields:["parent_id","unit_type","name","code","status"],updateFields:["parent_id","unit_type","name","code","status"],
    readRoles:managers,writeRoles:managers,required:["unit_type","name"],actorField:"created_by",updatedAt:true
  },
  memberships: {
    table:"sports_member_memberships",select:"id,member_id,org_unit_id,membership_number,membership_type,status,valid_from,valid_until,fee_status,approved_by,approved_at,notes,created_at",
    createFields:["member_id","org_unit_id","membership_number","membership_type","valid_from","valid_until","fee_status","notes"],
    updateFields:["org_unit_id","membership_type","status","valid_from","valid_until","fee_status","notes"],
    readRoles:managers,writeRoles:managers,required:["member_id","membership_type"],updatedAt:true
  },
  staff: {
    table:"sports_staff_profiles",select:"id,member_id,staff_role,license_number,grade,status,started_on,ended_on,created_at",
    createFields:["member_id","staff_role","license_number","grade","status","started_on","ended_on"],
    updateFields:["staff_role","license_number","grade","status","started_on","ended_on"],
    readRoles:managers,writeRoles:managers,required:["member_id","staff_role"],updatedAt:true
  },
  credentials: {
    table:"sports_staff_credentials",select:"id,staff_profile_id,credential_type,title,issuer,credential_number,issued_on,expires_on,verification_status,verified_by,verified_at,created_at",
    createFields:["staff_profile_id","credential_type","title","issuer","credential_number","issued_on","expires_on"],
    updateFields:["credential_type","title","issuer","credential_number","issued_on","expires_on","verification_status"],
    readRoles:managers,writeRoles:managers,required:["staff_profile_id","credential_type","title"]
  },
  "guardian-consents": {
    table:"sports_member_guardian_consents",select:"id,member_id,guardian_user_id,consent_scope,status,valid_from,valid_until,captured_at,revoked_at,notes",
    createFields:["member_id","guardian_user_id","consent_scope","valid_from","valid_until","notes"],
    updateFields:["valid_until","notes"],
    readRoles:privateManagers,writeRoles:privateManagers,required:["member_id","guardian_user_id","consent_scope"],actorField:"captured_by",orderBy:"captured_at"
  },
  "training-programs": {
    table:"sports_training_programs",select:"id,title,sport_type,age_group,target_group,coach_profile_id,start_date,end_date,status,description,created_at",
    createFields:["title","sport_type","age_group","target_group","coach_profile_id","start_date","end_date","status","description"],
    updateFields:["title","age_group","target_group","coach_profile_id","start_date","end_date","status","description"],
    readRoles:coaches,writeRoles:coaches,required:["title","sport_type"],actorField:"created_by",updatedAt:true
  },
  "training-sessions": {
    table:"sports_training_sessions",select:"id,program_id,title,starts_at,ends_at,facility_id,coach_profile_id,status,notes,created_at",
    createFields:["program_id","title","starts_at","ends_at","facility_id","coach_profile_id","status","notes"],
    updateFields:["title","starts_at","ends_at","facility_id","coach_profile_id","status","notes"],
    readRoles:coaches,writeRoles:coaches,required:["program_id","title","starts_at"],orderBy:"starts_at"
  },
  attendance: {
    table:"sports_training_attendance",select:"id,session_id,member_id,attendance_status,recorded_by,notes,recorded_at",
    createFields:["session_id","member_id","attendance_status","notes"],updateFields:["attendance_status","notes"],
    readRoles:coaches,writeRoles:coaches,required:["session_id","member_id","attendance_status"],actorField:"recorded_by",orderBy:"recorded_at"
  },
  assessments: {
    table:"sports_member_assessments",select:"id,member_id,sport_type,assessment_type,assessed_on,assessor_profile_id,score,indicators,strengths,development_areas,recommendation,review_status,created_at",
    createFields:["member_id","sport_type","assessment_type","assessed_on","assessor_profile_id","guardian_consent_id","score","indicators","strengths","development_areas","recommendation"],
    updateFields:["score","indicators","strengths","development_areas","recommendation","review_status"],
    readRoles:coaches,writeRoles:coaches,required:["member_id","sport_type","assessment_type"],actorField:"created_by"
  },
  "development-plans": {
    table:"sports_member_development_plans",select:"id,member_id,assessment_id,title,goals,start_date,review_date,status,assigned_coach_profile_id,guardian_consent_id,progress_notes,created_at",
    createFields:["member_id","assessment_id","title","goals","start_date","review_date","assigned_coach_profile_id","guardian_consent_id","progress_notes"],
    updateFields:["title","goals","review_date","status","assigned_coach_profile_id","guardian_consent_id","progress_notes"],
    readRoles:coaches,writeRoles:coaches,required:["member_id","title"],actorField:"created_by",updatedAt:true
  },
  facilities: {
    table:"sports_facilities",select:"id,name,facility_type,address,capacity,status,accessibility_notes,created_at",
    createFields:["name","facility_type","address","capacity","status","accessibility_notes"],
    updateFields:["name","facility_type","address","capacity","status","accessibility_notes"],
    readRoles:managers,writeRoles:managers,required:["name","facility_type"],updatedAt:true
  },
  bookings: {
    table:"sports_facility_bookings",select:"id,facility_id,purpose,starts_at,ends_at,booking_status,requested_by,decided_by,decision_note,created_at",
    createFields:["facility_id","purpose","starts_at","ends_at"],updateFields:["booking_status","decision_note"],
    readRoles:managers,writeRoles:managers,required:["facility_id","purpose","starts_at","ends_at"],actorField:"requested_by",orderBy:"starts_at"
  },
  invoices: {
    table:"sports_fee_invoices",select:"id,member_id,membership_id,invoice_number,description,amount_minor,currency,due_date,invoice_status,issued_by,created_at",
    createFields:["member_id","membership_id","invoice_number","description","amount_minor","currency","due_date"],
    updateFields:["invoice_status"],readRoles:privateManagers,writeRoles:privateManagers,required:["member_id","invoice_number","description","amount_minor"],actorField:"issued_by"
  },
  payments: {
    table:"sports_fee_payments",select:"id,invoice_id,amount_minor,currency,payment_method,external_reference,payment_status,received_at,confirmed_by,notes,created_at",
    createFields:["invoice_id","amount_minor","currency","payment_method","external_reference","notes"],
    updateFields:["payment_status","received_at","notes"],readRoles:privateManagers,writeRoles:privateManagers,required:["invoice_id","amount_minor","payment_method"],actorField:"confirmed_by"
  },
  insurance: {
    table:"sports_member_insurance",select:"id,member_id,provider,policy_number,coverage_type,valid_from,valid_until,insurance_status,verified_by,verified_at,created_at",
    createFields:["member_id","provider","policy_number","coverage_type","valid_from","valid_until","insurance_status"],
    updateFields:["provider","policy_number","coverage_type","valid_from","valid_until","insurance_status"],
    readRoles:privateManagers,writeRoles:privateManagers,required:["member_id","coverage_type"],updatedAt:true
  },
  announcements: {
    table:"sports_announcements",select:"id,title,body,audience,publish_at,expires_at,status,created_by,created_at",
    createFields:["title","body","audience","publish_at","expires_at","status"],updateFields:["title","body","audience","publish_at","expires_at","status"],
    readRoles:managers,writeRoles:managers,required:["title","body"],actorField:"created_by"
  },
  settings: {
    table:"sports_tenant_settings",select:"id,setting_scope,setting_key,setting_value,version,effective_from,changed_by,created_at",
    createFields:["setting_scope","setting_key","setting_value","version","effective_from"],
    updateFields:[],readRoles:privateManagers,writeRoles:privateManagers,required:["setting_key","setting_value"],actorField:"changed_by",orderBy:"created_at"
  }
};

export function sanitizeOperationsPayload(
  input: unknown,
  allowedFields: readonly string[],
  requiredFields: readonly string[] = [],
): { ok:true; value:Record<string,unknown> } | { ok:false; error:string } {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    return {ok:false,error:"ساختار اطلاعات معتبر نیست."};
  }
  const source=input as Record<string,unknown>;
  const allowed=new Set(allowedFields);
  for (const key of Object.keys(source)) {
    if (!allowed.has(key)) return {ok:false,error:"فیلد غیرمجاز در درخواست وجود دارد: "+key};
  }
  for (const key of requiredFields) {
    const value=source[key];
    if (value===undefined || value===null || value==="") return {ok:false,error:"فیلد الزامی ارسال نشده است: "+key};
  }
  return {ok:true,value:source};
}
