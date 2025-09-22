new const VERSION[] = "2.0";

#include <amxmodx>
#include <reapi>

#define IsPlayer(%0)		(1<=%0<=MaxClients)

public plugin_init() {
	register_plugin("WallShotBlocking",VERSION,"b0t.");

	RegisterHookChain(RG_IsPenetrableEntity,"RG_IsPenetrableEntity_Pre", .post = false);
}

public RG_IsPenetrableEntity_Pre(const Float:fVecStart[3],const Float:fVecEnd[3],const pAttacker,const iEnt) {
	if(!Is_ShootThrough(iEnt))
		return HC_CONTINUE;

	SetHookChainReturn(ATYPE_BOOL,false);
	return HC_SUPERCEDE;
}

stock bool:Is_ShootThrough(const iEnt) {
	if(IsPlayer(iEnt) || FClassnameIs(iEnt,"func_door_rotating") || FClassnameIs(iEnt,"func_door"))
		return false;
	
	if(FClassnameIs(iEnt,"worldspawn") || FClassnameIs(iEnt,"func_wall"))
		return true;
	
	if(FClassnameIs(iEnt,"func_breakable")) {
		if(Float:get_entvar(iEnt,var_takedamage) == DAMAGE_NO)
			return true;
	}

	return false;
}