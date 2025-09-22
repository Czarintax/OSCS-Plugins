#include <amxmodx>
#include <reapi> 

//#define NOT_ALIVE	   // Использовать /me может только МЕРТВЫЙ игрок. Чтобы разрешить всем пользоваться, закомментируйте;)
//#define INFO_KILLER	 // Информация /me и /hp после смерти игрока
//#define NO_ROUND	  // Поддержка бесконечного раунда.

#if AMXX_VERSION_NUM < 183 
	#include <colorchat>
	#define MAX_PLAYERS 32
#endif 

#if AMXX_VERSION_NUM == 183
enum _:info
{
	damage,
	lasthit,
	killerid,
	killername[32],
	Float:hpkiller,
	Float:apkiller,
	Float:distance
}
new g_iPlayerData[MAX_PLAYERS+1][info];
#else
enum _:info
{
	damage,
	lasthit,
	killerid,
	killername[32]
}
new g_iPlayerData[MAX_PLAYERS+1][info];
new Float:g_fHpKiller[MAX_PLAYERS+1];
new Float:g_fApKiller[MAX_PLAYERS+1];
new Float:g_fDistance[MAX_PLAYERS+1];
#endif

new g_iVOrigin[3], g_iKOrigin[3];

new const g_szHitPlaces[][] = {
	"SAYME_HITZONE_1",
	"SAYME_HITZONE_2",
	"SAYME_HITZONE_3",
	"SAYME_HITZONE_4",
	"SAYME_HITZONE_5",
	"SAYME_HITZONE_6",
	"SAYME_HITZONE_7",
	"SAYME_HITZONE_8"
};

public plugin_init()
{
	register_plugin("Say me and Say hp", "1.4", "neygomon");
	register_dictionary("sayme.txt");	 

	register_event("Damage", "eventDamage", "b", "2!0");	
#if defined NO_ROUND
	RegisterHookChain(RG_CBasePlayer_Spawn, "fwdPlayerSpawn", true) 
#else
	register_event("HLTV",	   "eventRoundStart", "a", "1=0", "2=0");
#endif
	RegisterHookChain(RG_CBasePlayer_Killed, "fwdPlayerKilled", true) 

	register_clcmd("say /me",	  "ClCmdSayMe");
	register_clcmd("say_team /me",	   "ClCmdSayMe");
	register_clcmd("say /hp",	  "ClCmdSayHp");
	register_clcmd("say_team /hp",	   "ClCmdSayHp");
}

public client_putinserver(id)
{
	arrayset(g_iPlayerData[id], 0, info);
	#if AMXX_VERSION_NUM < 183
	g_fHpKiller[id] = g_fApKiller[id] = g_fDistance[id] = 0.0;
	#endif	  
}
#if defined NO_ROUND
public fwdPlayerSpawn(const id)
{
	arrayset(g_iPlayerData[id], 0, info);
	#if AMXX_VERSION_NUM < 183
	g_fHpKiller[id] = g_fApKiller[id] = g_fDistance[id] = 0.0;
	#endif
}
#else
public eventRoundStart()
{
	for(new i = 1; i <= MAX_PLAYERS; i++)
	{
		arrayset(g_iPlayerData[i], 0, info);
	#if AMXX_VERSION_NUM < 183	  
		g_fHpKiller[i] = g_fApKiller[i] = g_fDistance[i] = 0.0;
	#endif	  
	}
}
#endif
public eventDamage(id)
{
	static attacker, hit; attacker = get_user_attacker(id, 0, hit);
	if(id != attacker && 1 <= attacker <= MAX_PLAYERS)
	{
		g_iPlayerData[attacker][damage] += read_data(2);
		g_iPlayerData[attacker][lasthit] = hit;
	}	 
}

public fwdPlayerKilled(pVictim, pKiller)
{
	if(pVictim == pKiller || !is_user_connected(pKiller) || !is_user_connected(pVictim))
		return;
	
	get_user_origin(pVictim, g_iVOrigin);
	get_user_origin(pKiller, g_iKOrigin);	
							   
#if AMXX_VERSION_NUM == 183
	g_iPlayerData[pVictim][hpkiller] = get_entvar(pKiller, var_health);
	g_iPlayerData[pVictim][apkiller] = get_entvar(pKiller, var_armorvalue);
	g_iPlayerData[pVictim][distance] = get_distance(g_iKOrigin, g_iVOrigin) * 0.0254;
#else							  
	g_fHpKiller[pVictim] = get_entvar(pKiller, var_health);
	g_fApKiller[pVictim] = get_entvar(pKiller, var_armorvalue);	 
	g_fDistance[pVictim] = get_distance(g_iKOrigin, g_iVOrigin) * 0.0254; 
#endif	  
	g_iPlayerData[pVictim][killerid] = pKiller;
	get_user_name(pKiller, g_iPlayerData[pVictim][killername], charsmax(g_iPlayerData[][killername]));
#if defined INFO_KILLER
	new pKilledByBomb = get_member(pVictim, m_bKilledByBomb);
	if(g_iPlayerData[pVictim][killerid] != 0 && !pKilledByBomb)
		ClCmdSayHp(pVictim);
	if(g_iPlayerData[pVictim][damage] != 0)
		ClCmdSayMe(pVictim);
#endif 
}

public ClCmdSayMe(id)
{
#if defined NOT_ALIVE
	if(is_user_alive(id))
	{
		client_print(id, print_chat, ^"* %L", id, "SAYME_NOT_ALIVE"); 
		return PLUGIN_HANDLED;				   
	}	 
#endif
	switch(g_iPlayerData[id][damage])
	{
		case 0:client_print(id, print_chat, ^"* %L", id, "SAYME_HIT_NOONE");
		default:client_print(id, print_chat, ^"* %L", id, "SAYME_DMG_DEALT", g_iPlayerData[id][damage], id, g_szHitPlaces[g_iPlayerData[id][lasthit]]);
	}	 
	return PLUGIN_HANDLED;	  
}

public ClCmdSayHp(id)
{
	switch(g_iPlayerData[id][killerid])
	{
		case 0:client_print(id, print_chat, ^"* %L", id, "SAYME_NO_KILLER");
#if AMXX_VERSION_NUM == 183		   
		default:client_print(id, print_chat, ^"* %L", id, "SAYME_WHO_KILLS", g_iPlayerData[id][killername], g_iPlayerData[id][distance], g_iPlayerData[id][hpkiller], g_iPlayerData[id][apkiller]);
#else
		default:client_print(id, print_chat, ^"* %L", id, "SAYME_WHO_KILLS", g_iPlayerData[id][killername], g_fDistance[id], g_fHpKiller[id], g_fApKiller[id]);
#endif		  
	}
	return PLUGIN_HANDLED;
}