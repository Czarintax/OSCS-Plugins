#include <amxmodx>
#include <reapi>

// afk_samples
new const SAMPLE_WARNING[] = "sound/events/tutor_msg.wav";	// warning
new const SAMPLE_PUNISHMENT[] = "sound/events/friend_died.wav";	// punishment

new g_iCvarMaxWarnings,
	g_iCvarMinPlayers,
	g_iCvarPunishment,
	g_iCvarSamples,
	g_iCvarBombTransfer,
	g_iCvarVIPConditions,
	g_iCvarLeftNotification,
	g_iCvarSpecMaxPlayers,
	g_iCvarSpecMaxWarns,
	g_iCvarSpecMaxPenalty,
	g_iCvarSpecSaveMoney,
	g_iCvarCheckAgressy,
	
	Float:g_fCvarTime,
	Float:g_fCvarSpecTime,
	
	g_szCvarReason[64],
	g_szCvarSpecReason[64],
	g_szCvarImmunity[16],
	g_szCvarImmunitySpec[16],
	g_szCvarMusic[128];

new g_iAccess;
new g_iAccessSpec;

new g_iWarnings[33];
new bool:g_bNotTakeMoney[33];

new Float:g_fLastMovementTime[33];
new Float:g_fLastMovement;

native bool:is_vote_started();

public plugin_precache()
{
	register_plugin("AFK Control", "1.0.3", "Emma Jule");
	
	bind_pcvar_float(create_cvar("afk_time", "10.0", .description = "Время в секундах после которого игрок получит предупреждение за простой", .has_min = true, .min_val = 5.0, .has_max = true, .max_val = 60.0), g_fCvarTime);
	bind_pcvar_num(create_cvar("afk_min_players", "10", .description = "Минимальное кол-во допустимых игроков на сервере для работы плагина"), g_iCvarMinPlayers);
	bind_pcvar_num(create_cvar("afk_max_warns", "3", .description = "Максимальное кол-во предупреждений за простой", .has_min = true, .min_val = 1.0), g_iCvarMaxWarnings);
	bind_pcvar_num(create_cvar("afk_punishment_method", "0", .description = "Вариант наказания за простой (1 - кик | 0 - перевод в наблюдатели)"), g_iCvarPunishment);
	bind_pcvar_num(create_cvar("afk_samples", "1", .description = "Звуковые оповещения во время событий! (меняются в исходнике)"), g_iCvarSamples);
	bind_pcvar_num(create_cvar("afk_bomb_transfer_mode", "2", .description = "Что делать с бомбой если чел AFK:^n0 - ничего^n1 - выкинуть напротив как оружие^n2 - перевести другому игроку (если возможно)"), g_iCvarBombTransfer);
	bind_pcvar_num(create_cvar("afk_vip_conditions", "0", .description = "Предотвратить досрочную победу террористов если VIP перевело в наблюдение"), g_iCvarVIPConditions);
	bind_pcvar_num(create_cvar("afk_left_notification", "0", .description = "Если в команде остались одни AFK то мы покажем об этом в чат"), g_iCvarLeftNotification);
	bind_pcvar_num(create_cvar("afk_check_agressy", "0", .description = "Последующие проверки вдвое сокращают интервал времени между ними!"), g_iCvarCheckAgressy);
	bind_pcvar_num(create_cvar("afk_spec_max_players", "30", .description = "Если онлайн больше чем этот квар кикаем наблюдателей чтобы зашли люди"), g_iCvarSpecMaxPlayers);
	bind_pcvar_num(create_cvar("afk_spec_max_warns", "3", .description = "Максимальное кол-во предупреждений для наблюдателей при работе за высокий онлайн", .has_min = true, .min_val = 1.0), g_iCvarSpecMaxWarns);
	bind_pcvar_num(create_cvar("afk_spec_max_penalty", "5", .description = "Сколько максимум можно выкинуть зрителей за раз", .has_min = true, .min_val = 1.0), g_iCvarSpecMaxPenalty);
	bind_pcvar_num(create_cvar("afk_spec_money", "1", .description = "Сохранить деньги игрока если его выкинуло в спектаторы"), g_iCvarSpecSaveMoney);
	bind_pcvar_float(create_cvar("afk_spec_time", "0.0", .description = "Время для предупреждения зрителя при полном сервере!^n0.0 - в начале каждого раунда^1.0 и выше через указанный интервал времени", .has_min = true, .has_max = true, .max_val = 180.0), g_fCvarSpecTime);
	bind_pcvar_string(create_cvar("afk_reason", "AFK", .description = "Причина удаления за простой"), g_szCvarReason, charsmax(g_szCvarReason));
	bind_pcvar_string(create_cvar("afk_spec_reason", "AFK", .description = "Причина кика за наблюдение при полном сервере"), g_szCvarSpecReason, charsmax(g_szCvarSpecReason));
	bind_pcvar_string(create_cvar("afk_spec_immunity", "a", .description = "Флаг админа для иммунитета за долгое наблюдение!"), g_szCvarImmunitySpec, charsmax(g_szCvarImmunitySpec));
	bind_pcvar_string(create_cvar("afk_immunity", "a", .description = "Флаг админа для иммунитета за простой!"), g_szCvarImmunity, charsmax(g_szCvarImmunity));
	bind_pcvar_string(create_cvar("afk_play_alert", "", .description = "Последнее звуковое предупреждение (в MP3 формате) которое сработает если свернута игра"), g_szCvarMusic, charsmax(g_szCvarMusic));
	
	AutoExecConfig(.name = "afk_control");
	
	precache_sound(SAMPLE_WARNING[6]);
	precache_sound(SAMPLE_PUNISHMENT[6]);
	
	if (g_szCvarMusic[0])
		precache_generic(fmt("sound/%s", g_szCvarMusic));
}

public plugin_init()
{
	register_dictionary("reapi_afk.txt");
	
	RegisterHookChain(RG_CBasePlayer_DropIdlePlayer, "CBasePlayer_DropIdlePlayer", false);
	RegisterHookChain(RG_HandleMenu_ChooseAppearance, "HandleMenu_ChooseAppearance", true);
	
	if (g_iCvarLeftNotification > 0) {
		RegisterHookChain(RG_CSGameRules_CheckWinConditions, "CSGameRules_CheckWinConditions", true);
	}
	
	if (g_iCvarSpecSaveMoney > 0) {
		RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", false);
	}
	
	if (g_fCvarSpecTime < 1.0) {
		register_event("HLTV", "@check_spectators", "a", "1=0", "2=0");
	} else {
		set_task(g_fCvarSpecTime, "@check_spectators", .flags = "b");
	}
}

public plugin_pause()
{
	set_cvar_num("mp_autokick", 0);
}

public plugin_unpause()
{
	set_cvar_num("mp_autokick", 1);
}

public OnConfigsExecuted()
{
	set_cvar_num("mp_autokick", 1);
	set_cvar_num("mp_max_teamkills", 0);
	set_cvar_float("mp_autokick_timeout", g_fCvarTime);
	
	// afk_bomb_transfer_mode
	if (g_iCvarBombTransfer > 0 && get_member_game(m_bMapHasBombTarget))
	{
		set_cvar_float("mp_afk_bomb_drop_time", 0.0);
	}
	
	// afk_vip_conditions
	if (g_iCvarVIPConditions > 0 && !get_member_game(m_bMapHasVIPSafetyZone))
	{
		g_iCvarVIPConditions = 0;
	}
	
	// afk_immunity
	g_iAccess = read_flags(g_szCvarImmunity);
	g_iAccessSpec = read_flags(g_szCvarImmunitySpec);
}

public client_connect(id)
{
	g_fLastMovementTime[id] = get_gametime();
}

public client_disconnected(id)
{
	g_iWarnings[id] = 0;
	g_bNotTakeMoney[id] = false;
}

public CBasePlayer_DropIdlePlayer(const id, const szReason[])
{
	// map_manager
	if (is_vote_started())
		return HC_SUPERCEDE;
	
	// afk_min_players
	if (get_playersnum() < g_iCvarMinPlayers)
		return HC_SUPERCEDE;
	
	// afk_immunity
	if (g_iAccess > ADMIN_ALL && (get_user_flags(id) & g_iAccess))
		return HC_SUPERCEDE;
	
	new Float:fNewTime = get_gametime();
	if (fNewTime - (g_fLastMovementTime[id] + 1.0) > g_fCvarTime)
	{
		g_iWarnings[id] = 0;
	}
	
	g_fLastMovementTime[id] = fNewTime;
	
	// afk_bomb_transfer_mode
	if (g_iCvarBombTransfer > 0 && get_member(id, m_bHasC4) && rg_get_alive_terrorists() > 1 && (g_iCvarBombTransfer == 1 || g_iCvarBombTransfer == 2 && !rg_transfer_c4(id)))
	{
		rg_drop_item(id, "weapon_c4");
	}
	
	// Warning
	if (++g_iWarnings[id] < g_iCvarMaxWarnings)
	{
		// afk_play_alert
		if (g_szCvarMusic[0] && (g_iWarnings[id] == g_iCvarMaxWarnings - 1))
		{
			client_cmd(id, "mp3 play ^"%s^"", g_szCvarMusic);
		}
		// afk_samples
		else if (g_iCvarSamples)
		{
			rg_send_audio(id, SAMPLE_WARNING);
		}
		
		client_print(id, print_chat, "%L %L", LANG_SERVER, "AFK_PREFIX", LANG_PLAYER, "AFK_WARNS", g_iWarnings[id], g_iCvarMaxWarnings);
	}
	// Punish
	else
	{
		// afk_punishment_method
		if (g_iCvarPunishment)
		{
			//client_print(0, print_chat, "%L %L", LANG_SERVER, "AFK_PREFIX", LANG_PLAYER, "AFK_KICKED", id, g_szCvarReason);
			SetHookChainArg(2, ATYPE_STRING, g_szCvarReason);
			return HC_CONTINUE;
		}
		
		// afk_vip_conditions
		if (g_iCvarVIPConditions > 0 && get_member(id, m_bIsVIP))
		{
			set_member(id, m_bIsVIP, false);
			set_member_game(m_pVIP, 0);
			set_member_game(m_iConsecutiveVIP, 10);
		}
		
		g_iWarnings[id] = 0;
		g_bNotTakeMoney[id] = true;
		
		rg_join_team(id, TEAM_SPECTATOR);
		set_member(id, m_bTeamChanged, false);
		
		// afk_samples
		if (g_iCvarSamples)
		{
			rg_send_audio(id, SAMPLE_PUNISHMENT);
		}
		
		client_print(0, print_console, "%L", LANG_PLAYER, "AFK_TRANSFERED", id, g_szCvarReason);
	}
	
	new Float:fTime = g_fCvarTime;
	if (g_iCvarCheckAgressy)
		fTime /= 2.0;
	
	RequestFrame("@UpdatefLastMovement", id);
	g_fLastMovement = Float: get_member(id, m_fLastMovement);
	set_member(id, m_flIdleCheckTime, fNewTime + fTime);
	
	return HC_SUPERCEDE;
}

@UpdatefLastMovement(const id)
{
	set_member(id, m_fLastMovement, g_fLastMovement);
}

@check_spectators()
{
	new players = get_playersnum();
	if (players < g_iCvarSpecMaxPlayers)
		return;
	
	new pData[MAX_PLAYERS][2], iCount;
	new iMaxPlayers = min(players - g_iCvarSpecMaxPlayers, g_iCvarSpecMaxPenalty);
	for (new i = 1, TeamName:team, Float:time = get_gametime(); i <= MaxClients; i++)
	{
		if (!is_user_connected(i))
			continue;
		
		if (is_user_bot(i) || is_user_hltv(i))
			continue;
		
		team = get_member(i, m_iTeam);
		if (TEAM_UNASSIGNED < team < TEAM_SPECTATOR && get_member(i, m_iMenu) != Menu_ChooseAppearance)
			continue;
		
		// afk_spec_immunity
		if (g_iAccessSpec > ADMIN_ALL && (get_user_flags(i) & g_iAccessSpec))
			continue;
		
		// afk_spec_time
		if (time - g_fLastMovementTime[i] < g_fCvarSpecTime)
			continue;
		
		// td: pCvar
		if (time - g_fLastMovementTime[i] > 300.0)
			g_iWarnings[i] = 0;
		
		g_iWarnings[i]++;
		g_fLastMovementTime[i] = time;
		
		if (g_iWarnings[i] < g_iCvarSpecMaxWarns && team != TEAM_UNASSIGNED)
			continue;
		
		// afk_play_alert
		if (g_szCvarMusic[0] && (g_iWarnings[i] == g_iCvarSpecMaxWarns - 1))
			client_cmd(i, "mp3 play ^"%s^"", g_szCvarMusic);
		
		pData[iCount][0] = i;
		pData[iCount][1] = g_iWarnings[i] + ((team == TEAM_UNASSIGNED && g_iWarnings[i] > 1) ? g_iCvarSpecMaxWarns : 0);
		
		if (++iCount == iMaxPlayers)
			break;
	}
	
	if (iCount < 1)
		return;
	
	SortCustom2D(pData, iCount, "@arraysort");
	// players -= g_iCvarSpecMaxPlayers;
	while (--iCount >= 0)
	{
		// if (pData[iCount][WARNINGS] > 0)
		{
			//client_print(0, print_chat, "%L %L", LANG_PLAYER, "AFK_PREFIX", LANG_PLAYER, "AFK_KICKED", pData[iCount][0], g_szCvarSpecReason);
			//rh_drop_client(pData[iCount][0], g_szCvarSpecReason);
			server_cmd("kick #%d ^"%s^"", get_user_userid(pData[iCount][0]), g_szCvarSpecReason);
		}
	}
}

public HandleMenu_ChooseAppearance(const id, const slot)
{
	g_iWarnings[id] = 0;
	g_bNotTakeMoney[id] = false;
	g_fLastMovementTime[id] = 0.0;
	
	return HC_CONTINUE;
}

// afk_spec_money
public CBasePlayer_AddAccount(const id, amount, RewardType:type, bool:bTrackChange)
{
	// UNDONE: Recursion
	return (g_bNotTakeMoney[id] && type == RT_PLAYER_SPEC_JOIN && amount == 0);
}

// afk_left_notification
public CSGameRules_CheckWinConditions()
{
	if (get_member_game(m_bNeededPlayers) || get_gametime() < Float: get_member_game(m_flRestartRoundTime))
		return HC_CONTINUE;
	
	new leftCount[TeamName];
	for (new i = 1, TeamName:team; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		team = get_member(i, m_iTeam);
		
		// One or more players is active
		if (leftCount[team] == -1)
			continue;
		
		if (rg_is_user_afk(i))
			leftCount[team]++;
		else
			leftCount[team] = -1;
	}
	
	if (leftCount[TEAM_TERRORIST] > 0)
	{
		// set_hudmessage(150, 0, 0, 0.18, 0.77, 0, 0.0, 3.5, 0.4, 1.02);
		// show_hudmessage(0, "%L", LANG_PLAYER, "AFK_TERRORIST_LEFT", leftCount[TEAM_TERRORIST]);
		
		client_print(0, print_chat, "%L %L", LANG_PLAYER, "AFK_PREFIX", LANG_PLAYER, "AFK_TERRORIST_LEFT", leftCount[TEAM_TERRORIST]);
	}
	
	if (leftCount[TEAM_CT] > 0)
	{
		// set_hudmessage(0, 150, 150, 0.66, 0.77, 0, 0.0, 3.5, 0.4, 1.02);
		// show_hudmessage(0, "%L", LANG_PLAYER, "AFK_CT_LEFT", leftCount[TEAM_CT]);
		
		client_print(0, print_chat, "%L %L", LANG_PLAYER, "AFK_PREFIX", LANG_PLAYER, "AFK_CT_LEFT", leftCount[TEAM_CT]);
	}
	
	return HC_CONTINUE;
}

@arraysort(const element1[], const element2[])
{
	return (element1[1] > element2[1]) ? 1 : (element1[1] < element2[1]) ? -1 : 0;
	// return strcmp(element2[1], element1[1]);
}

stock rg_get_alive_terrorists()
{
	new iNumAliveT;
	// rg_initialize_player_counts(iNumAliveT, _, _, _);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!is_user_alive(i))
			continue;
		
		if (get_member(i, m_iTeam) != TEAM_TERRORIST)
			continue;
		
		if (rg_is_user_afk(i))
			continue;
		
		iNumAliveT++;
	}
	
	return iNumAliveT;
}

stock rg_is_user_afk(id, &iWarnings = 0)
{
	if (get_gametime() - Float: get_member(id, m_fLastMovement) >= g_fCvarTime)
	{
		iWarnings = g_iWarnings[id];
		return true;
	}
	
	return false;
}
