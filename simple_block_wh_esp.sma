#include <amxmodx>
#include <fakemeta_util>

public plugin_init() {
	register_plugin("Simple Block WH/ESP", "1.0", "mlibre")
	
	register_forward(FM_AddToFullPack, "pfw_atfp", 1) 
}

public pfw_atfp(es, e, ent, host, flags, player, set)
{
    if(!is_user_alive(host)) return FMRES_IGNORED;
        
    if(!pev_valid(ent)) return FMRES_IGNORED;

    pev(ent, pev_classname, "block", 31);

    set_es(es, ES_Solid, SOLID_NOT); 
    
    return FMRES_IGNORED;
} 