#pragma semicolon 1

#include <amxmodx>
#include <reapi>

public plugin_init(){
	register_plugin
	(
		.plugin_name ="Remove Dead Body",
		.version = "0.1",
		.author = "Aconyonn"
	);

	RegisterHookChain(RG_CBasePlayer_Killed,"@rKilled",.post=true);
}
@rKilled(victim,attacker){
	#pragma unused attacker
	set_entvar(victim,var_effects,get_entvar(victim,var_effects)|EF_NODRAW);
}