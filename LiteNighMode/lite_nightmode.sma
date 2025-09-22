#include <amxmodx>
#include <shop_addon>

#define STARTTIME	 22	// Время начала ночного режима. Тестировал только с 00 часов. Поддежка раннего времени есть, но не проверялось:)
#define ENDTIME		8		// Окончание ночного режима
#define MAP 		"de_dust2_2x2"	// Карта ночного режима
#define AUTORR		16		// Авторестарт карты (sv_restart 1) каждые n раундов. Установите 0 для отключения данной плюшки.

new g_pTimeLimit, g_iOldTime, Float:g_flResetTime;
new bool:g_bNight;
#if AUTORR > 0
new g_iRound;
#endif
#if AMXX_VERSION_NUM < 183
	#define engine_changelevel(%0) server_cmd("amx_changemap %s", %0)
#endif

public plugin_init()
{
#define VERSION "1.1"
	register_plugin("Lite NightMode", VERSION, "neygomon");
	register_cvar("lite_nightmode", VERSION, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_dictionary("lite_nightmode.txt");

	register_event("TextMsg", 	"eGameCommencing", "a", "2=#Game_Commencing", "2=#Game_will_restart_in");	
	register_event("HLTV", 		"eRoundStart", "a", "1=0", "2=0");

	register_clcmd("say rtv", "RtvHook");
	register_clcmd("say_team rtv", "RtvHook");
	register_clcmd("say /rtv", "RtvHook");
	register_clcmd("say_team rtv", "RtvHook");
	register_clcmd("amx_rtv", "RtvHook");
	
	g_pTimeLimit = get_cvar_pointer("mp_timelimit");
}

public plugin_end()
	if(g_iOldTime) 
		set_pcvar_num(g_pTimeLimit, g_iOldTime);

public client_putinserver(id)
	if(g_bNight) 
		remove_user_flags(id, ADMIN_MAP|ADMIN_VOTE);
		
public eGameCommencing()
{
	g_flResetTime = get_gametime();
#if AUTORR > 0	
	g_iRound = 0;
#endif	
}	

public eRoundStart()
{
	static szCurMap[32], CurHour; time(CurHour);

#if STARTTIME > ENDTIME
	if(CurHour >= STARTTIME || CurHour < ENDTIME)
#else
	if(STARTTIME <= CurHour < ENDTIME)
#endif	
	{	
		if(!szCurMap[0])
			get_mapname(szCurMap, charsmax(szCurMap));
		
		if(!equal(szCurMap, MAP))
			engine_changelevel(MAP);	
		else if(!g_bNight)
		{
			g_bNight = true;
			RemovePlayersFlags();
			g_iOldTime = get_pcvar_num(g_pTimeLimit);
			set_pcvar_num(g_pTimeLimit, 0);
		}
		
		if(!shop_is_blocked())
			shop_set_block(true);
#if AUTORR > 0			
		static iRound; iRound = AUTORR - ++g_iRound;
		if(!(iRound > 0)) client_print(0, print_center, "%L", LANG_PLAYER, "LITE_NIGHTMODE_AUTORR", iRound);
		{
			rg_swap_all_players();
		}
#endif			
	}	
	else if(g_bNight)
	{
		set_pcvar_num(g_pTimeLimit, floatround(get_gametime() - g_flResetTime) / 60 + 5);
		g_bNight = false;
		shop_set_block(false);
	}
}

public RtvHook(id)
{
	if(!g_bNight) return PLUGIN_CONTINUE;
	client_print(id, print_chat, ^"^3[^2OSCS^3]^1 %L", LANG_PLAYER, "LITE_NIGHTMODE_RTVHOOK");
	return PLUGIN_HANDLED;
}

RemovePlayersFlags()
{
	static players[32], pcount;
	get_players(players, pcount, "ch");
	for(new i; i < pcount; i++)
		remove_user_flags(players[i], ADMIN_MAP|ADMIN_VOTE);
}
