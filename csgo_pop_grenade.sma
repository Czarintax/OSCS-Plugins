#include <amxmodx>
#include <hamsandwich>
#include <reapi>

// Порядковый номер анимации броска
#define ANIM_NUM 		2

enum {
	normal,
	slower,
	medium
};

new const g_GrenadeClassNames[][] = {
	"weapon_flashbang",
	"weapon_hegrenade"
	//"weapon_smokegrenade"
};

new const Float:g_VelocityMultiplier[] = {
	1.0,
	0.5,
	0.75
};

new g_HandleThrowType[MAX_CLIENTS + 1];
new Float:g_flLastAttack[MAX_CLIENTS + 1];

public plugin_init() {
	register_plugin("[ReAPI] Pop Grenades", "2.4", "EFFx & HamletEagle & Minni Mouse");

	for(new i; i < sizeof(g_GrenadeClassNames); i++) {
		RegisterHam(Ham_Weapon_SecondaryAttack, g_GrenadeClassNames[i], "Weapon_SecAttack_Pre", .Post = false);
		RegisterHam(Ham_Item_Deploy, g_GrenadeClassNames[i], "Item_Deploy_Pre", .Post = false);
	}

	RegisterHookChain(RG_CBasePlayer_ThrowGrenade, "Player_ThrowGrenade_Pre", .post = false);
}

public Item_Deploy_Pre(pItem) {
	if(!is_nullent(pItem)) {
		g_HandleThrowType[ get_member(pItem, m_pPlayer) ] = normal;
	}

	return HAM_IGNORED;
}

public Weapon_SecAttack_Pre(pWeapon) {
	if(get_member_game(m_bFreezePeriod)) {
		return HAM_IGNORED;
	}

	if(is_nullent(pWeapon)) {
		return HAM_IGNORED;
	}

	static pPlayer, Float:flCurTime;
	pPlayer = get_member(pWeapon, m_pPlayer);
	flCurTime = get_gametime();

	if(g_flLastAttack[pPlayer] > flCurTime) {
		return HAM_IGNORED;
	}

	g_HandleThrowType[pPlayer] = (get_entvar(pPlayer, var_button) & IN_ATTACK) ? medium : slower;

	ExecuteHamB(Ham_Weapon_PrimaryAttack, pWeapon);

	g_flLastAttack[pPlayer] = flCurTime + 1.5;

	return HAM_IGNORED;
}

public Player_ThrowGrenade_Pre(pPlayer, grenade, Float:vecSrc[3], Float:vecThrow[3], Float:time, usEvent) {
	if(is_nullent(grenade)) {
		return HC_CONTINUE;
	}

	new Float:flMultiplier = g_VelocityMultiplier[g_HandleThrowType[pPlayer]];

	vecThrow[0] *= flMultiplier;
	vecThrow[1] *= flMultiplier;
	vecThrow[2] *= flMultiplier;

	set_entvar(grenade, var_velocity, vecThrow);

	if(g_HandleThrowType[pPlayer] == slower) {
		rg_send_grenade_anim(pPlayer, ANIM_NUM);
	}

	g_HandleThrowType[pPlayer] = normal;

	return HC_CONTINUE;
}

stock rg_send_grenade_anim(const pPlayer, const iAnimation) {
	set_entvar(pPlayer, var_weaponanim, iAnimation);

	message_begin(MSG_ONE, SVC_WEAPONANIM, .player = pPlayer);
	write_byte(iAnimation);
	write_byte(0);
	message_end();
}