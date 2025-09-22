#include amxmodx
#include fakemeta
#tryinclude reapi
new g_fwdSpawn;
public plugin_precache() {
	g_fwdSpawn = register_forward(FM_Spawn, "@FakeMeta_SpawnEntity", false);
}
public plugin_init() {
	register_plugin("Remove Game Text", "1.1", "g3cKpunTop");
	if(g_fwdSpawn) { unregister_forward(FM_Spawn, g_fwdSpawn, false); }
}

@FakeMeta_SpawnEntity(iEntity) {
	new szClassName[32];
	#if defined _reapi_included
		get_entvar(iEntity, var_classname, szClassName, charsmax(szClassName));
	#else 
		pev(iEntity, pev_classname, szClassName, charsmax(szClassName));
	#endif
	if (equal(szClassName, "game_text")) {
		forward_return(FMV_CELL, -1);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}