// Copyright © 2016/2017 Vaqtincha

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG START ■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define KFADE_HOLD_TIME			0.8	// Продолжительность
#define KFADE_FX_TIME			0.5	// Плавное исчезновение	
#define VAULT_EXPIRE_DAYS		7	// Через сколько дней удалить настройку (если игрок не заходил)

/**■■■■■■■■■■■■■■■■■■■■■■■■■■■■■ CONFIG END ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■*/

#define MESSAGE_TYPE			MSG_ONE_UNRELIABLE
// #define DEBUG
new const VAULT_FILE[] = "kscfade_data"

#define PL_VERSION 		"0.0.5"

#include <amxmodx>
#include <reapi>
#include <nvault_array>

#if AMXX_VERSION_NUM < 183
	#define client_disconnected 		client_disconnect
#endif

#define IsBot(%1)						(!g_aPlayerData[%1][AuthId][0])

const MAX_AUTHID_LENGHT = 64
const MENU_KEYS = (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0)
const KEY_EXIT = 10
const FADE_COLORS_RANDOM = 0

enum color_e { R, G, B }

enum player_s
{
	AuthId[MAX_AUTHID_LENGHT],
	State,
	FadeColor,
	AlphaPercent
}

enum
{
	KSF_DISABLED,
	KSF_ENABLED,
	KSF_ONLY_HS
}

new const FADE_ALPHA[] = { 10, 20, 30, 40, 50, 60, 70, 80, 90 }

new const FADE_COLORS[][color_e] = 
{
    {0, 0, 0},									// random
    {0, 127, 255}, 				// blue 
    {255, 127, 0},			 	// orange 
    {127, 0, 255}, 				// violet
    {0, 255, 0}, 						// green
    {255, 100, 150},	 // pink
    {255, 255, 255},  // white
    {255, 0, 0} 	    		// red
}

new g_aPlayerData[MAX_CLIENTS + 1][player_s]
new g_hVault = INVALID_HANDLE

public plugin_end() 
{
	if(g_hVault != INVALID_HANDLE) {
		nvault_close(g_hVault)
	}
}

public plugin_cfg()
{
	if((g_hVault = nvault_open(VAULT_FILE)) == INVALID_HANDLE) {
		set_fail_state("[KSCFADE] ERROR: Opening nVault failed!")
	}
	else{
		nvault_prune(g_hVault, 0, get_systime() - (86400 * VAULT_EXPIRE_DAYS))
	}
}

public plugin_init()
{
	register_plugin("Killer ScreenFade", PL_VERSION, "Vaqtincha")
	register_dictionary("killer_screenfade.txt")
	register_menucmd(register_menuid("SettingsMenu"), MENU_KEYS, "SettingsMenuHandler")

	register_clcmd("fade", "ClCmd_ScfMenu")
	register_clcmd("say /fade", "ClCmd_ScfMenu")
	register_clcmd("say_team /fade", "ClCmd_ScfMenu")

	RegisterHookChain(RG_CSGameRules_PlayerKilled, "CSGameRules_PlayerKilled", .post = true)
	// RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", .post = true)
}

public client_disconnected(pClient) {
	SaveUserInfo(pClient)
}

public client_putinserver(pClient)
{
	g_aPlayerData[pClient][AuthId][0] = 0

	if(is_user_bot(pClient) || is_user_hltv(pClient))
		return
	
	get_user_authid(pClient, g_aPlayerData[pClient][AuthId], MAX_AUTHID_LENGHT - 1)

	if(nvault_get_array(g_hVault, g_aPlayerData[pClient][AuthId], g_aPlayerData[pClient], player_s) <= 0)
	{
		g_aPlayerData[pClient][State] = KSF_ENABLED
		g_aPlayerData[pClient][FadeColor] = 1
		g_aPlayerData[pClient][AlphaPercent] = 4
	}
	
#if defined DEBUG
	static const szText[KSF_ONLY_HS + 1][] = { "disabled", "enabled", "hs only" }
	server_print("^n[KSCFADE] Client: %s | State: %s | Color: %d | Alpha: %d", g_aPlayerData[pClient][AuthId],
		szText[g_aPlayerData[pClient][State]], g_aPlayerData[pClient][FadeColor], g_aPlayerData[pClient][AlphaPercent])
#endif
}

public ClCmd_ScfMenu(const pPlayer)
{
	new szMenu[512], iKeys = (MENU_KEY_0|MENU_KEY_3)
	new iLen = formatex(szMenu, charsmax(szMenu), "%L^n^n", pPlayer, "KSF_MENU_TITLE")

	static const szColText[sizeof(FADE_COLORS)][] = 
	{ 
	  "KSF_COLOR_RANDOM",
	  "KSF_COLOR_BLUE",
	  "KSF_COLOR_ORANGE",
	  "KSF_COLOR_VIOLET",
	  "KSF_COLOR_GREEN",
	  "KSF_COLOR_PINK",
	  "KSF_COLOR_WHITE",
	  "KSF_COLOR_RED"
	}
	static const szStateText[KSF_ONLY_HS + 1][] = { "KSF_STATE_DISABLED", "KSF_STATE_ENABLED", "KSF_STATE_ONLY_HS" }
	
	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
		"%L\y\R%L^n\
		%L\y\R%d^n^n",
		pPlayer, "KSF_MENU_ITEM1", pPlayer, szColText[g_aPlayerData[pPlayer][FadeColor]],
		pPlayer, "KSF_MENU_ITEM2", FADE_ALPHA[g_aPlayerData[pPlayer][AlphaPercent]]
	)

	iKeys |= (MENU_KEY_1|MENU_KEY_2)
	
	formatex(szMenu[iLen], charsmax(szMenu) - iLen, 
		"%L\y\R%L^n^n^n\
		%L",
		pPlayer, "KSF_MENU_ITEM3", pPlayer, szStateText[g_aPlayerData[pPlayer][State]],
		pPlayer, "KSF_MENU_EXIT"
	)
	
	show_menu(pPlayer, iKeys, szMenu, -1, "SettingsMenu")
	return PLUGIN_HANDLED
}

public SettingsMenuHandler(const pPlayer, const iKey)
{
	if(iKey == KEY_EXIT - 1) 
	{
		SaveUserInfo(pPlayer)
		return PLUGIN_HANDLED
	}
	
	switch(iKey)
	{
		case 0:
		{
			if(++g_aPlayerData[pPlayer][FadeColor] >= sizeof(FADE_COLORS)) {
				g_aPlayerData[pPlayer][FadeColor] = FADE_COLORS_RANDOM
			}
	
			new iCol = g_aPlayerData[pPlayer][FadeColor]
			__UTIL_ScreenFade(pPlayer, iCol != FADE_COLORS_RANDOM ? FADE_COLORS[iCol] : FADE_COLORS[random_num(1, sizeof(FADE_COLORS) - 1)], FADE_ALPHA[g_aPlayerData[pPlayer][AlphaPercent]],
				KFADE_FX_TIME, KFADE_HOLD_TIME
			)
		}
		case 1:
		{
			if(++g_aPlayerData[pPlayer][AlphaPercent] >= sizeof(FADE_ALPHA)) {
				g_aPlayerData[pPlayer][AlphaPercent] = 0
			}

			new iCol = g_aPlayerData[pPlayer][FadeColor]
			__UTIL_ScreenFade(pPlayer, iCol != FADE_COLORS_RANDOM ? FADE_COLORS[iCol] : FADE_COLORS[random_num(1, sizeof(FADE_COLORS) - 1)], FADE_ALPHA[g_aPlayerData[pPlayer][AlphaPercent]],
				KFADE_FX_TIME, KFADE_HOLD_TIME
			)
		}
		case 2:
		{
			switch(g_aPlayerData[pPlayer][State])
			{
				case KSF_DISABLED: 
				{
					g_aPlayerData[pPlayer][State] = KSF_ENABLED
					// client_print(pPlayer, print_center, "ScreenFade Enabled!")
				}
				case KSF_ENABLED: g_aPlayerData[pPlayer][State] = KSF_ONLY_HS
				case KSF_ONLY_HS: 
				{
					g_aPlayerData[pPlayer][State] = KSF_DISABLED
					client_print(pPlayer, print_center, "ScreenFade Disabled!")
				}
			}
		}
	}
	
	return ClCmd_ScfMenu(pPlayer)
}


public CSGameRules_PlayerKilled(const pPlayer, const pevKiller, const pevInflictor)
{
	if(pPlayer == pevKiller || pevKiller != pevInflictor /* ignore grenade kills */ || !is_user_alive(pevKiller))
		return HC_CONTINUE
	
	if(IsBot(pevKiller) || g_aPlayerData[pevKiller][State] == KSF_DISABLED)
		return HC_CONTINUE
	
	if(g_aPlayerData[pevKiller][State] == KSF_ENABLED || (g_aPlayerData[pevKiller][State] == KSF_ONLY_HS && get_member(pPlayer, m_bHeadshotKilled)))
	{
		new iCol = g_aPlayerData[pevKiller][FadeColor]
		__UTIL_ScreenFade(pevKiller, iCol != FADE_COLORS_RANDOM ? FADE_COLORS[iCol] : FADE_COLORS[random_num(1, sizeof(FADE_COLORS) - 1)], FADE_ALPHA[g_aPlayerData[pevKiller][AlphaPercent]],
			KFADE_FX_TIME, KFADE_HOLD_TIME
		)
	}
	
	return HC_CONTINUE
}

SaveUserInfo(pPlayer)
{
	if(!IsBot(pPlayer)) {
		nvault_set_array(g_hVault, g_aPlayerData[pPlayer][AuthId], g_aPlayerData[pPlayer], player_s)
	}
}

stock __UTIL_ScreenFade(const pPlayer, iColor[color_e], iAlpha, Float:flFxTime = 1.0, Float:flHoldTime = 1.0)
{
	if(IsBlind(pPlayer))
		return

	const FFADE_IN = 0x0000
	static iMsgIdScreenFade

	if(iMsgIdScreenFade > 0 || (iMsgIdScreenFade = get_user_msgid("ScreenFade")))
	{
		message_begin(MESSAGE_TYPE, iMsgIdScreenFade, .player = pPlayer)
		write_short(FixedUnsigned16(flFxTime))
		write_short(FixedUnsigned16(flHoldTime))
		write_short(FFADE_IN)
		write_byte(iColor[R])
		write_byte(iColor[G])
		write_byte(iColor[B])
		write_byte(iAlpha)
		message_end()
	}
}

stock FixedUnsigned16(Float:flValue, iScale = (1 << 12)) {
	return clamp(floatround(flValue * iScale), 0, 0xFFFF)
}

stock bool:IsBlind(const pPlayer) {
	return bool:(Float:get_member(pPlayer, m_blindStartTime) + Float:get_member(pPlayer, m_blindFadeTime) >= get_gametime())
}

// stock bool:IsBlind(const pPlayer) {
	// return bool:(Float:get_member(pPlayer, m_blindUntilTime) > get_gametime())
// }



