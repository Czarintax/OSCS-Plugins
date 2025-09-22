#include <amxmodx>
#include <amxmisc>

#define SUPERADMIN (ADMIN_RCON)		
	// Может пинать, кикать и тд игроков с иммунитетом. 
	// Закомментируйте если не требуется
#define TRANSFER_TYPE 3
	// 1 - обычный перевод игрока; 2 - тихий; 3 - сменить команду при следующем спавне игрока
	// "Тихий" перевод игрока в другую команду. Если игрок жив то просто сменит команду не убивая.
	// Одмины злоупотребляют такой шляпой, не рекомендуется к использованию
#define USE_REAPI
	// Использовать ReAPI модуль.
	// Для ReHLDS

#if defined USE_REAPI
	#include <reapi>
	
	#define rg_get_user_team(%0) 	get_member(%0, m_iTeam)
#else
	#include <cstrike>
	#include <hamsandwich>
	
	#define TeamName		CsTeams
	#define TEAM_UNASSIGNED 	CS_TEAM_UNASSIGNED
	#define TEAM_SPECTATOR 		CS_TEAM_SPECTATOR
	#define rg_set_user_team	cs_set_user_team
	#define rg_get_user_team(%0) 	cs_get_user_team(%0)
	#define RG_CBasePlayer_Spawn	Ham_Spawn
	#define RegisterHookChain(%0,%1,%2) RegisterHam(%0, "player", %1, %2)
#endif	
	
new g_iSlapSettings[] = 
{
	0, 	// 0 HP
	5, 	// 5 HP
	10,	// 10 HP
	99, // 99 HP
	-1 	// убить
}
new g_szTeams[][] = 
{
	"TERRORIST",
	"CT",
	"SPECTATOR"
}

enum _:MENUS
{
	SLAP,
	KICK,
	TEAM 
}
#if TRANSFER_TYPE == 2
enum _:DATA { Menu, Pos, Item, Silent };
#else
enum _:DATA { Menu, Pos, Item };
#endif
#if TRANSFER_TYPE == 3
new TeamName:g_iTeamTransfer[33];
#endif
new g_iMenu[33][DATA];
new g_arrPlayers[33][32];

public plugin_init()
{
	register_plugin("Players Menu", "1.7", "neugomon");
	register_dictionary("common.txt");
	register_dictionary("admincmd.txt");
	register_dictionary("plmenu.txt");
	
	register_clcmd("amx_kickmenu", "cmdKickMenu", ADMIN_KICK);
	register_clcmd("amx_slapmenu", "cmdSlapMenu", ADMIN_SLAY);
	register_clcmd("amx_teammenu", "cmdTeamMenu", ADMIN_BAN);
	
	register_menucmd(register_menuid("Players Menu"), 1023, "PlayersMenuHandler");
#if TRANSFER_TYPE == 3
	RegisterHookChain(RG_CBasePlayer_Spawn, "fwdPlayerSpawn_Pre", false);
#endif	
}

public cmdKickMenu(id, flags)
	return PreOpenMenu(id, flags, KICK);
	
public cmdSlapMenu(id, flags)
	return PreOpenMenu(id, flags, SLAP);
	
public cmdTeamMenu(id, flags)
	return PreOpenMenu(id, flags, TEAM);	
#if TRANSFER_TYPE == 3
public client_putinserver(id)
	g_iTeamTransfer[id] = TEAM_UNASSIGNED;

public fwdPlayerSpawn_Pre(const index)
{
	if(g_iTeamTransfer[index] != TEAM_UNASSIGNED)
	{
		if(is_user_connected(index))
			rg_set_user_team(index, g_iTeamTransfer[index]);
		g_iTeamTransfer[index] = TEAM_UNASSIGNED;
	}	
}
#endif
public PlayersMenuHandler(id, key)
{
	switch(key)
	{
	#if TRANSFER_TYPE == 2
		case 6:
		{
			switch(g_iMenu[id][Menu])
			{
				case KICK: KickHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 8 + key]);
				case SLAP: SlapHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 7 + key]);
				case TEAM:
				{
					g_iMenu[id][Silent] = !g_iMenu[id][Silent];
					BuildMenu(id, g_iMenu[id][Pos]);	
				}
			}
		}
	#endif	
		case 7:
		{
			switch(g_iMenu[id][Menu])
			{
				case KICK: KickHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 8 + key]);
				case SLAP:
				{
					if(++g_iMenu[id][Item] > charsmax(g_iSlapSettings))
						g_iMenu[id][Item] = 0;				
					BuildMenu(id, g_iMenu[id][Pos]);
				}
				case TEAM:
				{
					if(++g_iMenu[id][Item] > charsmax(g_szTeams))
						g_iMenu[id][Item] = 0;
					BuildMenu(id, g_iMenu[id][Pos]);	
				}
			}	
		}
		case 8: BuildMenu(id, ++g_iMenu[id][Pos]);
		case 9: if(g_iMenu[id][Pos]) BuildMenu(id, --g_iMenu[id][Pos]);
		default:
		{
			switch(g_iMenu[id][Menu])
			{
				case KICK: KickHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 8 + key]);
				case SLAP: SlapHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 7 + key]);
			#if TRANSFER_TYPE == 2	
				case TEAM: TeamHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 6 + key]);
			#else
				case TEAM: TeamHandler(id, g_arrPlayers[id][g_iMenu[id][Pos] * 7 + key]);
			#endif
			}
		}
	}
	return PLUGIN_HANDLED;
}

PreOpenMenu(id, flags, menu)
{
	if(get_user_flags(id) & flags)
	{
		g_iMenu[id][Pos] 	= 0;
		g_iMenu[id][Item] 	= 0;
		g_iMenu[id][Menu] 	= menu;
	#if TRANSFER_TYPE == 2	
		g_iMenu[id][Silent]	= 0;
	#endif	
		BuildMenu(id, g_iMenu[id][Pos]);
	}
	else	client_print(id, print_console, "%L", id, "NO_ACC_COM");
	return PLUGIN_HANDLED;
}

BuildMenu(id, pos)
{
	new szMenu[512];
	new len;
	new start;
	new end;
	new keys = MENU_KEY_0;
	new pnum;
	new pages;
	get_players(g_arrPlayers[id], pnum, "h");
	
	switch(g_iMenu[id][Menu])
	{
		case KICK:
		{
			len = formatex(szMenu, charsmax(szMenu), ^"\y%L^0\R%d/%d%s", id, "KICK_MENU", pos + 1, pages, "^n^n");
			
			start = pos * 8;
			end   = start + 8;
			pages = (pnum / 8 + ((pnum % 8) ? 1 : 0));
		}
		case SLAP:
		{
			len = formatex(szMenu, charsmax(szMenu), ^"\y%L^0\R%d/%d%s", id, "SLAP_SLAY_MENU", pos + 1, pages, "^n^n");
			
			start = pos * 7;
			end   = start + 7;
			pages = (pnum / 7 + ((pnum % 7) ? 1 : 0));
		}
		case TEAM:
		{
			len = formatex(szMenu, charsmax(szMenu), ^"\y%L^0\R%d/%d%s", id, "TEAM_MENU", pos + 1, pages, "^n^n");
		#if TRANSFER_TYPE == 2	
			start = pos * 6;
			end   = start + 6;
			pages = (pnum / 6 + ((pnum % 6) ? 1 : 0));
		#else
			start = pos * 7;
			end   = start + 7;
			pages = (pnum / 7 + ((pnum % 7) ? 1 : 0));
		#endif
		}
	}
	
	if(start >= pnum)
		start = g_iMenu[id][Pos] = 0;
	if(end > pnum) 
		end = pnum;

#if defined SUPERADMIN
	new bool:flagSuperId = bool:(get_user_flags(id) & SUPERADMIN);
#endif	
	for(new i = start, szName[MAX_NAME_LENGTH], team[15], tm, flags, a, pl; i < end; i++)
	{
		pl = g_arrPlayers[id][i];
		get_user_name(pl, szName, charsmax(szName));
		
		if(g_iMenu[id][Menu] == SLAP)
		{
			if(!is_user_alive(pl))
			{
				len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s^n", ++a, szName);
				continue;
			}	
		}
		
		flags = get_user_flags(pl);
	#if defined SUPERADMIN
		if(!flagSuperId && id != pl && flags & ADMIN_IMMUNITY)
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", ++a, szName, "IMMUNE");
			continue;
		}
	#else
		if(id != pl && flags & ADMIN_IMMUNITY)
		{
			len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", ++a, szName, "IMMUNE");
			continue;
		}
	#endif
		switch(g_iMenu[id][Menu])
		{
			case TEAM: 
			{
				tm = any:rg_get_user_team(pl);
				switch(tm)
				{
					case 1: team = "TE";
					case 2: team = "CT";
					case 3: team = "SPEC";
				}
			
				if(tm == g_iMenu[id][Item]+1)
				{
					if(flags & ADMIN_MENU)
						len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", ++a, szName, (id != pl) ? "ADMIN" : "YOU", team);
					else 	len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", ++a, szName, team);
				}
				else
				{
					keys |= (1 << a++);
					if(flags & ADMIN_MENU)
						len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", a, szName, (id != pl) ? "ADMIN" : "YOU", team);
					else 	len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", a, szName, team);
				}
			}
			default:
			{
				keys |= (1 << a++);
				if(flags & ADMIN_MENU)
					len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s \y\R%s^n", a, szName, (id != pl) ? "ADMIN" : "YOU");
				else 	len += formatex(szMenu[len], charsmax(szMenu) - len, "%d. %s^n", a, szName);
			}
		}
		
	}
	
	switch(g_iMenu[id][Menu])
	{
		case SLAP:
		{
			if(g_iMenu[id][Item] == charsmax(g_iSlapSettings) && g_iSlapSettings[g_iMenu[id][Item]] == -1) 
				len += formatex(szMenu[len], charsmax(szMenu) - len, "^n8. %L^n", id, "SLAY");
			else 
				len += formatex(szMenu[len], charsmax(szMenu) - len, "^n8. %L^n", id, "SLAP_WITH_DMG", g_iSlapSettings[g_iMenu[id][Item]]);
			keys |= MENU_KEY_8;	
		}
		case TEAM:
		{
		#if TRANSFER_TYPE == 2	
			new spec = (g_iMenu[id][Item] == charsmax(g_szTeams));
			len += formatex(szMenu[len], charsmax(szMenu) - len, "^n7. %L: %L^n8. %s^n", id, "TRANSF_SILENT", id, g_iMenu[id][Silent] ? "YES" : "NO", g_szTeams[g_iMenu[id][Item]]);
			keys |= spec ? MENU_KEY_8 : MENU_KEY_7|MENU_KEY_8;
		#else
			len += formatex(szMenu[len], charsmax(szMenu) - len, "^n8. %L^n", id, "TRANSF_TO", g_szTeams[g_iMenu[id][Item]]);
			keys |= MENU_KEY_8;
		#endif	
		}
	}

	if(end != pnum)
	{
		formatex(szMenu[len], charsmax(szMenu) - len, "^n9. %L...^n0. %L", id, "MORE", id, pos ? "BACK" : "EXIT");
		keys |= MENU_KEY_9;
	}
	else formatex(szMenu[len], charsmax(szMenu) - len, "^n0. %L", id, pos ? "BACK" : "EXIT");
	
	show_menu(id, keys, szMenu, -1, "Players Menu");
	return PLUGIN_HANDLED;
}

KickHandler(id, player)
{
	new authid[MAX_AUTHID_LENGTH]; 	get_user_authid(id, authid, charsmax(authid));
	new authid2[MAX_AUTHID_LENGTH]; get_user_authid(player, authid2, charsmax(authid2));
	new name[MAX_NAME_LENGTH];  	get_user_name(id, name, charsmax(name));
	new name2[MAX_NAME_LENGTH]; 	get_user_name(player, name2, charsmax(name2));

	log_amx("Kick: ^"%s<%d><%s><>^" kick ^"%s<%d><%s><>^"", name, get_user_userid(id), authid, name2, get_user_userid(player), authid2);
	show_activity_key("ADMIN_KICK_1", "ADMIN_KICK_2", name, name2);
	engclient_print(player, engprint_console, "%L: %s", player, "ADMIN", name);
	server_cmd("kick #%d", get_user_userid(player));
}

SlapHandler(id, player)
{
	new authid[MAX_AUTHID_LENGTH]; 	get_user_authid(id, authid, charsmax(authid));
	new authid2[MAX_AUTHID_LENGTH]; get_user_authid(player, authid2, charsmax(authid2));
	new name[MAX_NAME_LENGTH];		get_user_name(id, name, charsmax(name));
	new name2[MAX_NAME_LENGTH];		get_user_name(player, name2, charsmax(name2));

	if(g_iMenu[id][Item] == charsmax(g_iSlapSettings) && g_iSlapSettings[g_iMenu[id][Item]] == -1) 
	{
		log_amx("Cmd: ^"%s<%d><%s><>^" slay ^"%s<%d><%s><>^"", name, get_user_userid(id), authid, name2, get_user_userid(player), authid2);
		show_activity_key("ADMIN_SLAY_1", "ADMIN_SLAY_2", name, name2);
		user_kill(player, 0);
	}
	else 
	{
		new item = g_iMenu[id][Item];
		log_amx("Cmd: ^"%s<%d><%s><>^" slap with %d damage ^"%s<%d><%s><>^"", name, get_user_userid(id), authid, g_iSlapSettings[item], name2, get_user_userid(player), authid2);
		show_activity_key("ADMIN_SLAP_1", "ADMIN_SLAP_2", name, name2, g_iSlapSettings[item]);
		user_slap(player, (get_user_health(player) > g_iSlapSettings[item]) ? g_iSlapSettings[item] : 0);
		
		BuildMenu(id, g_iMenu[id][Pos]);
	}
}

TeamHandler(id, player)
{	
	if(is_user_connected(player))
	{
		new authid[MAX_AUTHID_LENGTH]; 	get_user_authid(id, authid, charsmax(authid));
		new authid2[MAX_AUTHID_LENGTH]; get_user_authid(player, authid2, charsmax(authid2));
		new name[MAX_NAME_LENGTH];  	get_user_name(id, name, charsmax(name));
		new name2[MAX_NAME_LENGTH]; 	get_user_name(player, name2, charsmax(name2));
		log_amx("Cmd: ^"%s<%d><%s><>^" transfer ^"%s<%d><%s><>^" (team ^"%s^")", name, get_user_userid(id), authid, name2, get_user_userid(player), authid2, g_szTeams[g_iMenu[id][Item]]);
		show_activity_key("ADMIN_TRANSF_1", "ADMIN_TRANSF_2", name, name2, g_szTeams[g_iMenu[id][Item]]);
		
		switch(rg_get_user_team(player))
		{
			case 1, 2:
			{
			#if TRANSFER_TYPE == 1
				UserKillForTransfer(player);
				rg_set_user_team(player, g_iMenu[id][Item] + 1);
			#endif
			#if TRANSFER_TYPE == 2
				if(!g_iMenu[id][Silent] || g_iMenu[id][Item] == charsmax(g_szTeams))
					UserKillForTransfer(player);
				rg_set_user_team(player, g_iMenu[id][Item] + 1);
			#endif
			#if TRANSFER_TYPE == 3
				g_iTeamTransfer[player] = any:(g_iMenu[id][Item] + 1);
				if(g_iTeamTransfer[player] == TEAM_SPECTATOR)
				{
					UserKillForTransfer(player);
					rg_set_user_team(player, g_iTeamTransfer[player]);
					g_iTeamTransfer[player] = TEAM_UNASSIGNED;
				}
			#endif
			}
			default:
			{
			#if defined USE_REAPI
				rg_join_team(player, any:(g_iMenu[id][Item] + 1));
			#else
				engclient_cmd(player, "jointeam", (g_iMenu[id][Item] + 1) == 1 ? "1" : "2");
			#endif
			}
		}
	}	
	BuildMenu(id, g_iMenu[id][Pos]); // дичь
}

stock UserKillForTransfer(id) 
{ 
	if(is_user_alive(id)) 
		user_kill(id, 1); 
}
