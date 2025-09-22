#include <amxmodx>
#include <csx>

new const g_szWeaponName[] = "worldspawn"

public plugin_init()
{
	register_plugin("C4 Death Icon", "1.0", "KayDee")
	register_cvar("@C4DeathIcon", "1.0", FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
}

public client_death(iVictim, iKiller, iWeapon)
{
    // check if killed by c4
    if(iWeapon == CSW_C4)
    {
         make_deathmsg(0, iVictim, 0, g_szWeaponName)
    }
}