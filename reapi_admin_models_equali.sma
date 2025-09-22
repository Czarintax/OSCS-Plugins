//	Copyright © 2016 Vaqtincha

#include <amxmodx>
#include <reapi>

enum player_models { szTTModel[64], szCTModel[64], iFlag }


/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define SET_MODELINDEX
#define MAX_MODEL_PATH_LEN 	128

/// FORMAT: "Terrorist Model" "Counter-Terrorist Model"  "Access Flag" 

new const g_eModelsData[][player_models] = 
{
	{ "oscs_terror_admin", "oscs_gign_admin", ADMIN_MENU },
	{ "oscs_terror_vip", "oscs_gign_vip", ADMIN_LEVEL_H },

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

	{"", "", -1} // don't touch it!! 
}

#define IsValidArrayIndex(%1) 		(0 <= %1 <= sizeof(g_eModelsData)-1)

#if defined SET_MODELINDEX
	new g_iTTModelIndex[sizeof(g_eModelsData)], g_iCTModelIndex[sizeof(g_eModelsData)]
#endif


public plugin_precache()
{
	if(g_eModelsData[0][iFlag] == -1)
	{
		set_fail_state("Array g_eModelsData are empty!")
		return
	}

	for(new i = 0; i < sizeof(g_eModelsData)-1; i++)
	{
	#if defined SET_MODELINDEX
		g_iTTModelIndex[i] = precache_player_model(g_eModelsData[i][szTTModel])
		g_iCTModelIndex[i] = precache_player_model(g_eModelsData[i][szCTModel])
	#else
		precache_player_model(g_eModelsData[i][szTTModel])
		precache_player_model(g_eModelsData[i][szCTModel])
	#endif
	}
}

public plugin_init()
{
	register_plugin("[ReAPI] Admin Models", "0.0.2", "Vaqtincha")

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "SetClientUserInfoModel", .post = false)
}


public SetClientUserInfoModel(const pPlayer, infobuffer[], szNewModel[])
{
	new iArrayIndex = get_user_model_by_flag(get_user_flags(pPlayer))

	if(!IsValidArrayIndex(iArrayIndex))
		return HC_CONTINUE
	
	switch(get_member(pPlayer, m_iTeam))
	{
		case TEAM_TERRORIST: {
		#if defined SET_MODELINDEX
			set_member(pPlayer, m_modelIndexPlayer, g_iTTModelIndex[iArrayIndex])
		#endif
			SetHookChainArg(3, ATYPE_STRING, g_eModelsData[iArrayIndex][szTTModel])
		}
		case TEAM_CT: {
		#if defined SET_MODELINDEX
			set_member(pPlayer, m_modelIndexPlayer, g_iCTModelIndex[iArrayIndex])
		#endif
			SetHookChainArg(3, ATYPE_STRING, g_eModelsData[iArrayIndex][szCTModel])
		}
		default: return HC_CONTINUE
	}

	return HC_CONTINUE
}


get_user_model_by_flag(const iUserFlags)
{
	const INVALID_INDEX = -1

	if(iUserFlags & (1<<29)) {
		return INVALID_INDEX
	}

	for(new i = 0; i < sizeof(g_eModelsData)-1; i++)
	{
		if(iUserFlags & g_eModelsData[i][iFlag] || g_eModelsData[i][iFlag] == ADMIN_ALL)
			return i
	}

	return INVALID_INDEX // non admin player
}

precache_player_model(const szModel[])
{	
	new szFileToPrecache[MAX_MODEL_PATH_LEN], szErrMsg[MAX_MODEL_PATH_LEN + 64]

	formatex(szFileToPrecache, charsmax(szFileToPrecache), "models/player/%s/%s.mdl", szModel, szModel)

	if(!file_exists(szFileToPrecache))
	{
		formatex(szErrMsg, charsmax(szErrMsg), "[Admin Models] ERROR: Model ^"%s^" not found!", szFileToPrecache)
		set_fail_state(szErrMsg)
		return 0
	}

	return precache_model(szFileToPrecache)
}
