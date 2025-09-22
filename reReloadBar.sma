#include <amxmodx>
#include <reapi>

new bool:Reloading[MAX_PLAYERS+1];

public plugin_init() {
	register_plugin("Reload Bar","1.0","heaveNN");

	RegisterHookChain(RG_CBasePlayerWeapon_DefaultReload,"DefaultReload",true);
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy,"DefaultDeploy",true);
}

public DefaultReload(const ent, iClipSize, iAnim, Float:fDelay) {
	new id = get_member(ent,m_pPlayer);
	if(CanReload(id,ent)) {
		rg_send_bartime(id,floatround(fDelay));
		Reloading[id] = true;
	}
}

public DefaultDeploy(const ent, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal) {
	new id = get_member(ent,m_pPlayer);
	if(!is_user_connected(id)) return;
	if(Reloading[id]) {
		rg_send_bartime(id,0);
		Reloading[id] = false;
	}
}

bool:CanReload(const id, const ent) {
	new WeaponIdType:weaponId = get_member(ent,m_iId);
	new ammo = rg_get_user_ammo(id,weaponId);
	if(ammo < rg_get_weapon_info(weaponId,WI_GUN_CLIP_SIZE)) {
		return true;
	}
	return false;
}