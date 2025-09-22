// Copyright © 2022 Vaqtincha

#define PL_VERSION "0.1"

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

const GRENADES_BIT_SUM = ((1 << any:WEAPON_HEGRENADE) | (1 << any:WEAPON_SMOKEGRENADE) | (1 << any:WEAPON_FLASHBANG))

#define IsPlayer(%1)				(1 <= %1 <= MaxClients)
#define IsGrenadeWeaponID(%1) 		(GRENADES_BIT_SUM & (1 << any:%1))

enum any:BW_CONTROLLERS
{
	BW_CONTROLLER_DISTANCE,
	BW_CONTROLLER_HEIGHT,
	BW_CONTROLLER_SLOPE,
	BW_CONTROLLER_ANGLE
}

enum any:BW_STYLES
{
	BW_STYLE1,
	BW_STYLE2
}

enum bw_player_models_s { szPlayerModel[32], iStyle, aStyle1[BW_CONTROLLERS], aStyle2[BW_CONTROLLERS] }

new const BW_MODEL_NAME[] = "models/back_weapons.mdl"
new const BW_MODEL_DEFAULT_POS[BW_CONTROLLERS] = { 15, 15, 10, 160 }

new const PLAYER_MODEL_LIST[][bw_player_models_s] =
{
	// "modelname", style, { distance(0~40), height(-5~50), slope(-5~90), angle(0~360) } }

	{ "urban",		BW_STYLE2,	{ 15, 15, 45, 20 }, { 15, 33, 0, 160 } },
	{ "gign",		BW_STYLE2,	{ 12, 15, 50, 20 }, { 12, 33, 0, 160 } },
	{ "sas",		BW_STYLE2,	{ 17, 15, 45, 20 }, { 17, 33, 0, 160 } },
	{ "gsg9",		BW_STYLE2,	{ 12, 15, 50, 20 }, { 11, 33, 0, 160 } },
	// { "spetsnaz",BW_STYLE2,	{ 11, 15, 50, 20 }, { 11, 33, 0, 160 } },

	{ "terror",		BW_STYLE2,	{ 13, 15, 50, 20 }, { 13, 33, 0, 160 } },
	{ "leet",		BW_STYLE2,	{ 20, 15, 50, 20 }, { 20, 33, 0, 160 } },
	{ "guerilla",	BW_STYLE2,	{ 16, 15, 50, 20 }, { 16, 33, 0, 160 } },
	{ "arctic",		BW_STYLE2,	{ 5,  15, 40, 20 }, { 5,  33, 0, 160 } }
	// { "militia",	BW_STYLE2,	{ 15,  15, 40, 20 }, { 5,  33, 0, 160 } }
}

new const BW_MODEL_BODY_INDEX[any:WEAPON_P90 + 1] =
{
	0, //
	0, // WEAPON_P228
	0, //
	10,// WEAPON_SCOUT
	0, // WEAPON_HEGRENADE
	11,// WEAPON_XM1014
	0, // WEAPON_C4
	18,// WEAPON_MAC10
	1, // WEAPON_AUG
	0, // WEAPON_SMOKEGRENADE
	0, // WEAPON_ELITE
	0, // WEAPON_FIVESEVEN
	16,// WEAPON_UMP45
	8, // WEAPON_SG550
	6, // WEAPON_GALIL
	15,// WEAPON_FAMAS
	0, // WEAPON_USP
	0, // WEAPON_GLOCK18
	3, // WEAPON_AWP
	4, // WEAPON_MP5NAVY
	14,// WEAPON_M249
	12,// WEAPON_M3
	7, // WEAPON_M4A1
	17,// WEAPON_TMP
	13,// WEAPON_G3SG1
	0, // WEAPON_FLASHBANG
	0, // WEAPON_DEAGLE
	9, // WEAPON_SG552
	2, // WEAPON_AK47
	0, // WEAPON_KNIFE
	5  // WEAPON_P90
}

new Trie:g_tCachedModels

public plugin_precache() {
	precache_model(BW_MODEL_NAME)
}

public plugin_init()
{
	register_plugin("Back Weapons New", PL_VERSION, "Vaqtincha")

	for (new any:iId = WEAPON_P228, szWeaponName[32]; iId <= WEAPON_P90; iId++)
	{
		if (get_weaponname(iId, szWeaponName, charsmax(szWeaponName)))
		{
			if (BW_MODEL_BODY_INDEX[iId] > 0)
				RegisterHam(Ham_Item_AttachToPlayer, szWeaponName, "CBasePlayerItem_AttachToPlayer", .Post = true)
			
			if (BW_MODEL_BODY_INDEX[iId] > 0 || iId == WEAPON_KNIFE || IsGrenadeWeaponID(iId))
			{
				RegisterHam(Ham_Item_Holster, szWeaponName, "CBasePlayerItem_Holster", .Post = true)
				RegisterHam(Ham_Item_Deploy, szWeaponName, "CBasePlayerItem_Deploy", .Post = false)
			}
		}
	}

	g_tCachedModels = TrieCreate()
	for (new i, eData[bw_player_models_s]; i < sizeof(PLAYER_MODEL_LIST); i++) 
	{
		eData[iStyle] = PLAYER_MODEL_LIST[i][iStyle]
		VecCopy(PLAYER_MODEL_LIST[i][aStyle1], eData[aStyle1])
		VecCopy(PLAYER_MODEL_LIST[i][aStyle2], eData[aStyle2])

		TrieSetArray(g_tCachedModels, PLAYER_MODEL_LIST[i][szPlayerModel], eData, bw_player_models_s)
	}
}


public CBasePlayerItem_AttachToPlayer(const pItem, const pPlayer)
{
	if (pItem <= 0 || !is_user_alive(pPlayer))
		return

	SetModelByWeaponId(pItem)
	SetModelPosByPlayerModel(pPlayer, pItem)

	if (get_member(pPlayer, m_pActiveItem) != pItem) {
		set_entvar(pItem, var_effects, 0)
	}
}

public CBasePlayerItem_Deploy(const pItem)
{
	if (pItem <= 0)
		return
	
	new any:iId = get_member(pItem, m_iId)
	if (iId == WEAPON_KNIFE) {
		SetModelPosByWeaponType(get_member(pItem, m_pPlayer), 3)
	}
	else if (IsGrenadeWeaponID(iId)) {
		SetModelPosByWeaponType(get_member(pItem, m_pPlayer), 4)
	}
	else {
		set_entvar(pItem, var_effects, EF_NODRAW)
	}
}

public CBasePlayerItem_Holster(const pItem)
{
	if (pItem <= 0)
		return
	
	new any:iId = get_member(pItem, m_iId)
	if (iId == WEAPON_KNIFE) {
		SetModelPosByWeaponType(get_member(pItem, m_pPlayer), -3)
	}
	else if (IsGrenadeWeaponID(iId)) {
		SetModelPosByWeaponType(get_member(pItem, m_pPlayer), -4)
	}
	else
	{
		if (get_entvar(pItem, var_modelindex) == 0) // AttachToPlayer not called by 3rd plugins
		{
			SetModelByWeaponId(pItem)
			SetModelPosByPlayerModel(get_member(pItem, m_pPlayer), pItem)
		}

		set_entvar(pItem, var_effects, 0)
	}
}

stock SetModelPosByWeaponType(const pPlayer, const iValue)
{
	if (!IsPlayer(pPlayer))
		return
	
	new iDis, pBackItem = get_member(pPlayer, m_rgpPlayerItems, PRIMARY_WEAPON_SLOT)
	while (!is_nullent(pBackItem))
	{
		iDis = get_entvar(pBackItem, var_controller, BW_CONTROLLER_DISTANCE)
		if (iDis > 0)
			set_entvar(pBackItem, var_controller, iDis - iValue, BW_CONTROLLER_DISTANCE)	
		
		pBackItem = get_member(pBackItem, m_pNext)
	}
}

stock SetModelByWeaponId(const pItem)
{
	engfunc(EngFunc_SetModel, pItem, BW_MODEL_NAME)
	set_entvar(pItem, var_body, BW_MODEL_BODY_INDEX[get_member(pItem, m_iId)])
}

stock SetModelPosByPlayerModel(const pPlayer, const pItem)
{
	if (!IsPlayer(pPlayer))
		return

	new eData[bw_player_models_s], szModel[32]
	get_user_info(pPlayer, "model", szModel, charsmax(szModel))
	
	if (TrieGetArray(g_tCachedModels, szModel, eData, bw_player_models_s))
	{
		for (new i = BW_CONTROLLER_DISTANCE; i < BW_CONTROLLERS; i++)
		{
			set_entvar(pItem, var_controller, eData[iStyle] == BW_STYLE1 ? eData[aStyle1][i] : eData[aStyle2][i], i)
			// server_print("PlayerModel %s | Style %i | Controller %i | Value %i", szModel,  eData[iStyle], i, eData[iStyle] == 1 ? eData[aStyle2][i] : eData[aStyle1][i])
		}
	}
	else
	{
		// default values for other models
		for (new i = BW_CONTROLLER_DISTANCE; i < BW_CONTROLLERS; i++) {
			set_entvar(pItem, var_controller, BW_MODEL_DEFAULT_POS[i], i)
		}
	}
}

stock VecCopy(const vecIn[], vecOut[])
{
	for (new i = BW_CONTROLLER_DISTANCE; i < BW_CONTROLLERS; i++) {
		vecOut[i] = vecIn[i]
	}
}

