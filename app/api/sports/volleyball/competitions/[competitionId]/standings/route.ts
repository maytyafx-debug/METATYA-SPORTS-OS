import { NextRequest, NextResponse } from "next/server";
import { resolveTenant } from "@/lib/tenancy/resolve-tenant";

type TeamRow={team_id:string;pool_code:string|null;status:string};
type MatchRow={id:string;home_team_id:string;away_team_id:string;best_of:number};
type SetRow={match_id:string;home_points:number;away_points:number};

export async function GET(req:NextRequest,ctx:{params:Promise<{competitionId:string}>}) {
  const c=await resolveTenant(req);
  if(!c.ok)return NextResponse.json({error:c.error},{status:c.status});
  const {competitionId}=await ctx.params;
  const {data:competition,error:competitionError}=await c.supabase.from("sports_volleyball_competitions")
    .select("id,name,points_win_clear,points_win_narrow,points_loss_narrow,points_loss_clear")
    .eq("tenant_id",c.tenantId).eq("id",competitionId).single();
  if(competitionError||!competition)return NextResponse.json({error:"رقابت یافت نشد."},{status:404});
  const {data:registrations,error:registrationError}=await c.supabase.from("sports_volleyball_competition_teams")
    .select("team_id,pool_code,status").eq("tenant_id",c.tenantId).eq("competition_id",competitionId);
  if(registrationError)return NextResponse.json({error:"دریافت تیم‌های رقابت ناموفق بود."},{status:500});
  const teamIds=(registrations??[]).filter((x:TeamRow)=>x.status==="registered").map((x:TeamRow)=>x.team_id);
  const {data:teamRows,error:teamError}=teamIds.length
    ? await c.supabase.from("sports_volleyball_teams").select("id,name").eq("tenant_id",c.tenantId).in("id",teamIds)
    : {data:[],error:null};
  if(teamError)return NextResponse.json({error:"دریافت مشخصات تیم‌ها ناموفق بود."},{status:500});
  const {data:matches,error:matchError}=await c.supabase.from("sports_volleyball_matches")
    .select("id,home_team_id,away_team_id,best_of").eq("tenant_id",c.tenantId)
    .eq("competition_id",competitionId).eq("result_status","approved");
  if(matchError)return NextResponse.json({error:"دریافت مسابقات تأییدشده ناموفق بود."},{status:500});
  const matchIds=(matches??[]).map((m:MatchRow)=>m.id);
  const {data:sets,error:setError}=matchIds.length
    ? await c.supabase.from("sports_volleyball_match_sets").select("match_id,home_points,away_points")
      .eq("tenant_id",c.tenantId).in("match_id",matchIds)
    : {data:[],error:null};
  if(setError)return NextResponse.json({error:"دریافت امتیاز ست‌ها ناموفق بود."},{status:500});

  const standings=new Map<string,{team_id:string;team_name:string;pool_code:string|null;played:number;wins:number;losses:number;match_points:number;sets_for:number;sets_against:number;points_for:number;points_against:number}>();
  for(const t of (teamRows??[]) as {id:string;name:string}[]){
    const reg=(registrations??[]).find((x:TeamRow)=>x.team_id===t.id);
    standings.set(t.id,{team_id:t.id,team_name:t.name,pool_code:reg?.pool_code??null,played:0,wins:0,losses:0,match_points:0,sets_for:0,sets_against:0,points_for:0,points_against:0});
  }
  for(const m of (matches??[]) as MatchRow[]){
    const home=standings.get(m.home_team_id),away=standings.get(m.away_team_id);
    if(!home||!away)continue;
    const matchSets=(sets??[] as SetRow[]).filter((s: SetRow)=>s.match_id===m.id);
    let hs=0,as=0;
    for(const s of matchSets){if(s.home_points>s.away_points)hs++;else if(s.away_points>s.home_points)as++;home.points_for+=s.home_points;home.points_against+=s.away_points;away.points_for+=s.away_points;away.points_against+=s.home_points;}
    home.played++;away.played++;home.sets_for+=hs;home.sets_against+=as;away.sets_for+=as;away.sets_against+=hs;
    if(hs>as){home.wins++;away.losses++;if(hs-as===1){home.match_points+=Number(competition.points_win_narrow);away.match_points+=Number(competition.points_loss_narrow);}else{home.match_points+=Number(competition.points_win_clear);away.match_points+=Number(competition.points_loss_clear);}}
    else if(as>hs){away.wins++;home.losses++;if(as-hs===1){away.match_points+=Number(competition.points_win_narrow);home.match_points+=Number(competition.points_loss_narrow);}else{away.match_points+=Number(competition.points_win_clear);home.match_points+=Number(competition.points_loss_clear);}}
  }
  const ratio=(a:number,b:number)=>b===0?(a>0?Number.POSITIVE_INFINITY:0):a/b;
  const ordered=[...standings.values()].sort((a,b)=>{
    if(a.pool_code!==b.pool_code)return (a.pool_code??"").localeCompare(b.pool_code??"");
    return b.match_points-a.match_points||b.wins-a.wins||ratio(b.sets_for,b.sets_against)-ratio(a.sets_for,a.sets_against)||ratio(b.points_for,b.points_against)-ratio(a.points_for,a.points_against);
  });
  return NextResponse.json({competition:competition.name,standings:ordered},{headers:{"Cache-Control":"private, no-store"}});
}
