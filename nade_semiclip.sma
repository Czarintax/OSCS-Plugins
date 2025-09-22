#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define PEV_OWNER_TEAM pev_iuser1

#define m_iTeam 114
#define m_bIsC4 96

#define getUserTeam(%1)	get_pdata_int(%1, m_iTeam)
#define getNadeOwnerTeam(%1) pev(%1, PEV_OWNER_TEAM)
#define isC4(%1)	(get_pdata_int(%1, m_bIsC4) & (1<<8))

#define GRENADE_CLASS "grenade"

new gCvarSemiclip, gSemiclip

#define PLUGIN "Nade Semiclip"
#define VERSION "2.7"
#define AUTHOR "JustGo"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_cvar("nade_semiclip_version", VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	set_cvar_string("nade_semiclip_version", VERSION)
	
	register_event("HLTV", "newRound", "a", "1=0", "2=0")
	
	register_forward(FM_SetModel, "setModel")
	register_forward(FM_ShouldCollide, "shouldCollide")
	
	gCvarSemiclip = register_cvar("nade_semiclip", "1")
}

public newRound()
{
	gSemiclip = get_pcvar_num(gCvarSemiclip)
}

public setModel(iEntity, const Model[])
{
	
	if(!gSemiclip)
		return FMRES_IGNORED
	
	if(!isGrenade(iEntity))
		return FMRES_IGNORED
		
	static id; id = pev(iEntity, pev_owner)

	if(!id) return FMRES_IGNORED
	
	if(!pev(iEntity, PEV_OWNER_TEAM))  
	{
		set_pev(iEntity, PEV_OWNER_TEAM, getUserTeam(id)) // remember the nade owner team
	}
		
	return FMRES_IGNORED
}

public shouldCollide(player, ent)
{
	
	if(!gSemiclip)
		return FMRES_IGNORED

	if(!is_user_alive(player) || !isGrenade(ent))
		return FMRES_IGNORED

	if(gSemiclip == 1 && (getUserTeam(player) != getNadeOwnerTeam(ent)))
		return FMRES_IGNORED

	if(aboutToExplode(ent))
		return FMRES_IGNORED

	forward_return(FMV_CELL, 0)
	return FMRES_SUPERCEDE
}

stock bool:isGrenade(iEntity)
{
	if(!pev_valid(iEntity))
		return false
	
	static class[9] 
	pev(iEntity, pev_classname, class, charsmax(class)) 
	
	if(!equal(class, GRENADE_CLASS))
		return false
	
	if (isC4(iEntity))
		return false
	
	return true
}

stock bool:aboutToExplode(ent)
{
	static Float:dmgtime
	pev(ent, pev_dmgtime, dmgtime)
	
	// It's going to explode :D
	return (dmgtime <= get_gametime())
}