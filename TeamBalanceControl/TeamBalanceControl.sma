#include <amxmodx>
#include <reapi>

#define rg_get_user_team(%0)	get_member(%0, m_iTeam)

enum _:Teams
{
	TeamTT = 1,
	TeamCT
}

new const VERSION[]  = "1.3.9";
new const g_szConfigFile[] = "TeamBalanceControl.cfg";
const PLAYER_DIFF 	 = 2;
const CHECK_INTERVAL = 15;

new bool:g_bFirstSpawn = true;
new bool:g_bPlayerToTransfer[MAX_PLAYERS + 1];

new Float:g_fPlayerSkill[MAX_PLAYERS + 1], g_iPlayerHs[MAX_PLAYERS + 1], g_iPlayerKills[MAX_PLAYERS + 1], g_iPlayerDeaths[MAX_PLAYERS + 1];
new Float:g_fJoinTime[MAX_PLAYERS +1];

new g_eTeamScore[Teams  + 1];

new g_pSkillDifference, g_pScoreDifference, g_pMinPlayers, g_pAdminNotify, g_pAdminFlag, g_pPlayerNotify, g_pSoundNotify, g_pNoRound;
new g_iNoRound;

public plugin_init()
{
	register_plugin("Team Balance Control", VERSION, "gyxoBka");
	register_cvar("team_balance", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
	
	register_logevent("LogEvent_JoinTeam", 3, "1=joined team");
	register_event("TeamScore", "EventScore", "a");
	
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", .post = true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", .post = false);
	
	register_dictionary("TeamBalanceControl.txt");
	
	g_pSkillDifference = register_cvar("tbc_skilldiff", "45");
	g_pScoreDifference = register_cvar("tbc_scorediff", "4");
	g_pMinPlayers = register_cvar("tbc_minplayers", "8");
	g_pAdminNotify = register_cvar("tbc_admnotify", "1");
	g_pAdminFlag = register_cvar("tbc_admflag", "a");
	g_pPlayerNotify = register_cvar("tbc_plnotify", "1");
	g_pSoundNotify = register_cvar("tbc_sndnotify", "1");
	g_pNoRound = register_cvar("tbc_noround", "0");
}

public plugin_cfg()
{
	new szFilePath[64];
	get_localinfo("amxx_configsdir", szFilePath, charsmax(szFilePath));
	formatex(szFilePath, charsmax(szFilePath), "%s/%s",szFilePath, g_szConfigFile);
	server_cmd("exec %s", szFilePath);
	
	g_iNoRound = get_pcvar_num(g_pNoRound);
}

public CSGameRules_RestartRound_Pre()
{
	if(get_member_game(m_bCompleteReset)) 
	{
		arrayset(g_eTeamScore, 0, Teams  + 1);
		arrayset(g_iPlayerHs, 0, MAX_PLAYERS + 1);
		arrayset(g_iPlayerKills, 0, MAX_PLAYERS + 1);
		arrayset(g_iPlayerDeaths, 0, MAX_PLAYERS + 1);
		arrayset(g_bPlayerToTransfer, 0, MAX_PLAYERS + 1);
	}
	
	if(g_bFirstSpawn)
	{
		g_bFirstSpawn = false;
		return;
	}
	
	CheckTeamsToEqualNum();
	
	if(!g_iNoRound)
	{
		new iDifference;
		static iNextCheck;
		
		iNextCheck--;
		
		CheckTeamsScore(iDifference);
		
		if(iNextCheck <= 0 && iDifference >= get_pcvar_num(g_pScoreDifference))
		{
			if(iNextCheck == 0)
			{
				iNextCheck = (iDifference/2) + 1;
			}
			
			new Float:fSkillTT, Float:fSkillCT, iCTNum, iTTNum;
			CalculateSkills(fSkillTT, fSkillCT, iCTNum, iTTNum);
			
			new iMinPlayers = get_pcvar_num(g_pMinPlayers);
			if(iMinPlayers < 6)
			{
				iMinPlayers = 6;
			}

			if(iCTNum + iTTNum >= iMinPlayers)
			{
				CheckTeamSkill(fSkillTT, fSkillCT);
			}
		}
	}
	
	arrayset(g_bPlayerToTransfer, 0, MAX_PLAYERS + 1);
}

public client_putinserver(id)
{
	g_bPlayerToTransfer[id] = false;
	g_fJoinTime[id] = 0.0;
}

public client_disconnected(id)
{
	g_bPlayerToTransfer[id] = false;
	g_fJoinTime[id] = 0.0;
}

public LogEvent_JoinTeam()
{
	new szLogPlayer[80], szName[32], id;
	read_logargv(0, szLogPlayer, charsmax(szLogPlayer));
	parse_loguser(szLogPlayer, szName, charsmax(szName));
	id = get_user_index(szName);
	
	g_fJoinTime[id] = get_gametime();
}

public EventScore() 
{ 
	new szTeam[1];
	read_data(1, szTeam, 1);

	if(szTeam[0] == 'C') g_eTeamScore[TeamCT] = read_data(2);
	else g_eTeamScore[TeamTT] = read_data(2);
}

public CBasePlayer_Killed_Post(const iVictim, iKiller, iGib)
{
	if(!g_iNoRound)
	{
		if(get_member(iVictim, m_bHeadshotKilled))
		{
			g_iPlayerHs[iKiller]++;
		}
		
		g_iPlayerKills[iKiller]++;
		g_iPlayerDeaths[iVictim]++;
	}
	else
	{
		static iKills; 
		iKills++;
		
		if(!(iKills % CHECK_INTERVAL))
		{
			CheckTeamsToEqualNum();
		}
	}
}

CheckTeamsScore(&iDifference)
{
	if(g_eTeamScore[TeamCT] > g_eTeamScore[TeamTT])
	{
		iDifference = g_eTeamScore[TeamCT] - g_eTeamScore[TeamTT];
	}
	
	if(g_eTeamScore[TeamTT] > g_eTeamScore[TeamCT])
	{
		iDifference = g_eTeamScore[TeamTT] - g_eTeamScore[TeamCT];
	}
}

CalculateSkills(&Float:fSkillTT, &Float:fSkillCT, &iCTNum, &iTTNum)
{
	new iKills, iDeaths, iHs;
	new iHsCT, iKillsCT, iDeathsCT;
	new iHsTT, iKillsTT, iDeathsTT;
	
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(rg_get_user_team(id))
		{
			case TEAM_CT:
			{
				iCTNum++
				
				iHs = g_iPlayerHs[id];
				iKills = g_iPlayerKills[id];
				iDeaths = g_iPlayerDeaths[id];
				
				iHsCT += iHs;
				iKillsCT += iKills;
				iDeathsCT += iDeaths;
				
				g_fPlayerSkill[id] = get_skill(iKills, iDeaths, iHs);
			}
			case TEAM_TERRORIST:
			{
				iTTNum++
				
				iHs = g_iPlayerHs[id];
				iKills = g_iPlayerKills[id];
				iDeaths = g_iPlayerDeaths[id];
				
				iHsTT += iHs;
				iKillsTT += iKills;
				iDeathsTT += iDeaths;
				
				g_fPlayerSkill[id] = get_skill(iKills, iDeaths, iHs);
			}
			default: continue;
		}
	}
	
	fSkillCT = get_skill(iKillsCT, iDeathsCT, iHsCT);
	fSkillTT = get_skill(iKillsTT, iDeathsTT, iHsTT);
}

CheckTeamSkill(Float:fSkillTT, Float:fSkillCT)
{
	new Float:fCTResult, Float:fTTResult;
	new Float:fPercent, Float:fTemp;
	new Float:fDifference = get_pcvar_float(g_pSkillDifference);
	if(fSkillTT > fSkillCT)
	{
		fPercent = fSkillCT/100.0;
		fTemp = fSkillTT/fPercent;
		fTTResult = fTemp - 100.0;
		if(fTTResult > fDifference)
		{
			// Balance is needed
			BalanceTeamBySkill(TeamTT);
		}
	}
	else if(fSkillCT > fSkillTT)
	{
		fPercent = fSkillTT/100.0;
		fTemp = fSkillCT/fPercent;
		fCTResult = fTemp - 100.0;
		if(fCTResult > fDifference)
		{
			// Balance is needed
			BalanceTeamBySkill(TeamCT);
		}
	}
	else return; // Balance isn't needed, because teams are equal
}

CheckTeamsToEqualNum()
{
	new iNums[Teams  + 1];
	new iTTNum, iCTNum;
	new iPlayers[Teams  + 1][32];
	new iNumToSwap, iTeamToSwap;
	
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(rg_get_user_team(id))
		{
			case TEAM_CT: iPlayers[TeamCT][iNums[TeamCT]++] = id;
			case TEAM_TERRORIST: iPlayers[TeamTT][iNums[TeamTT]++] = id;
			default: continue;
		}
	}
	
	iTTNum = iNums[TeamTT];
	iCTNum = iNums[TeamCT];
	
	//Узнаем сколько игроков нужно перевести
	if(iTTNum > iCTNum)
	{
		iNumToSwap = ( iTTNum - iCTNum ) / 2;
		iTeamToSwap = TeamTT;
	}
	else if(iCTNum > iTTNum)
	{
		iNumToSwap = (iCTNum - iTTNum) / 2;
		iTeamToSwap = TeamCT;
	}
	else return PLUGIN_CONTINUE;	// Balance isn't needed, because teams are equal
	
	if(!iNumToSwap) return PLUGIN_CONTINUE;		// Balance isn't needed
	
	new iPlayer, iNum, iLastPlayer;
	iNum = iNums[iTeamToSwap];
	
	do
	{
		--iNumToSwap;
		
		for(new i; i < iNum; i++)
		{
			iPlayer = iPlayers[iTeamToSwap][i];
			
			if(g_bPlayerToTransfer[iPlayer]) continue;
			
			if(g_fJoinTime[iPlayer] >= g_fJoinTime[iLastPlayer])
			iLastPlayer = iPlayer;
		}
		
		if(!iLastPlayer) return PLUGIN_CONTINUE;
		
		g_bPlayerToTransfer[iLastPlayer] = true;
		TransferPlayer(iLastPlayer);
		iLastPlayer = 0;
	}
	while(iNumToSwap)
	
	return PLUGIN_CONTINUE;
}

BalanceTeamBySkill(const iLeadingTeam)
{
	new iNum[Teams  + 1];
	new iCTPlayers[32], iTTPlayers[32];
	
	for(new id = 1; id <= MaxClients; id++)
	{
		if(!is_user_connected(id)) continue;
		
		switch(rg_get_user_team(id))
		{
			case TEAM_CT: iCTPlayers[iNum[TeamCT]++] = id;
			case TEAM_TERRORIST: iTTPlayers[iNum[TeamTT]++] = id;
			default: continue;
		}
	}
	
	new iPlayerPos[Teams + 1][32];

	OrderPlayers(iNum[TeamCT], TeamCT, iCTPlayers, iPlayerPos);
	OrderPlayers(iNum[TeamTT], TeamTT, iTTPlayers, iPlayerPos);
	
	new iLeadNum = iNum[iLeadingTeam];
	new Float:fCoeff = GetTeamCoeff(iLeadNum);
	new iLeadPos, iLosePos;
	new iLoseTeam = iLeadingTeam == TeamTT ? TeamCT : TeamTT;
	new iStartLosePos = iNum[iLoseTeam] - 1;
	new iStartLeadPos = floatround(iLeadNum/fCoeff, floatround_floor);
	
	new iTeamLeadId, iTeamLoseId;
	new iTransferedNum;
	
	new bool:TransferIsNeeded = true;

	while(TransferIsNeeded)
	{
		iLeadPos = iLeadNum - (iStartLeadPos + iTransferedNum);
		iLosePos = iStartLosePos - iTransferedNum;
		
		if(iLeadPos < 0) break;
		
		iTeamLeadId = iPlayerPos[iLeadingTeam][iLeadPos];
		iTeamLoseId = iPlayerPos[iLoseTeam][iLosePos];
		
		if(g_bPlayerToTransfer[iTeamLoseId])
		{
			iTeamLoseId = iPlayerPos[iLoseTeam][--iLosePos];
		}
		
		iPlayerPos[iLeadingTeam][iLeadPos] = iTeamLoseId;
		iPlayerPos[iLoseTeam][iLosePos] = iTeamLeadId;
		
		TransferPlayer(iTeamLeadId);
		TransferPlayer(iTeamLoseId);
		
		TransferIsNeeded = CheckSkillsChanges(iPlayerPos, iNum, iLeadingTeam, iLoseTeam, iTransferedNum);
	}
	
	return PLUGIN_CONTINUE;
}

bool:CheckSkillsChanges(iPlayerPos[Teams  + 1][32], iNum[Teams  + 1], const iLeadTeam, const iLoseTeam, &iTransferedNum)
{
	new iRankPos, iPlayer;
	new iHsLead, iKillsLead, iDeathsLead;
	new iHsLose, iKillsLose, iDeathsLose;
	
	do
	{
		iPlayer = iPlayerPos[iLeadTeam][iRankPos++];
		
		iHsLead += g_iPlayerHs[iPlayer];
		iKillsLead += g_iPlayerKills[iPlayer];
		iDeathsLead += g_iPlayerDeaths[iPlayer];
		
	}
	while(iNum[iLeadTeam] > iRankPos)
	
	iRankPos = 0;
	
	do
	{
		iPlayer = iPlayerPos[iLoseTeam][iRankPos++];
		
		iHsLose += g_iPlayerHs[iPlayer];
		iKillsLose += g_iPlayerKills[iPlayer];
		iDeathsLose += g_iPlayerDeaths[iPlayer];
		
	}
	while(iNum[iLoseTeam] > iRankPos)
	
	new Float:fSkillLead = get_skill(iKillsLead, iDeathsLead, iHsLead);
	new Float:fSkillLose = get_skill(iKillsLose, iDeathsLose, iHsLose);
	
	new Float:fPercent = fSkillLose/100.0;
	new Float:fTemp = fSkillLead/fPercent;
	new Float:fTeamResult = fTemp - 100.0;
	
	if(fTeamResult > get_pcvar_float(g_pSkillDifference) && iTransferedNum <= PLAYER_DIFF)
	{
		// Need balance too
		iTransferedNum++;
		return true;
	}
	
	return false;
}

OrderPlayers(const iNum, const iTeam, iPlayers[], iPlayerPos[Teams  + 1][32])
{
	new iMaxSkillId, Float:fMax, iMaxPos, iPlayer, iTemp;
	
	while(iNum > iTemp)
	{
		for(new i = 0; i < iNum; i++)
		{
			iPlayer = iPlayers[i];
			if(!iPlayer) 
			{
				continue;
			}
			if(g_fPlayerSkill[iPlayer] >= fMax)
			{
				fMax = g_fPlayerSkill[iPlayer];
				iMaxSkillId = iPlayer;
				iMaxPos = i;
			}
		}
		if(iMaxSkillId > 0) 		// for safety
		{
			iPlayerPos[iTeam][iTemp++] = iMaxSkillId;
			iPlayers[iMaxPos] = 0;
			iMaxSkillId = 0;
			fMax = 0.0;
		}
		else
		{
			log_to_file("TeamBalanceControl.txt", "Smthg was wrong, when tried to pos players");
			log_to_file("TeamBalanceControl.txt", "TeamNum: %d  iPos: %d", iNum, iTemp);
			return PLUGIN_CONTINUE;
		}
	}
	
	return PLUGIN_CONTINUE;
}

Float:GetTeamCoeff(const iTeamNum)
{
	new Float:fTemp;
	
	switch(iTeamNum)
	{
		case 4..10: fTemp = 2.0;
		case 11: fTemp = 2.2;
		case 12: fTemp = 2.4;
		case 13..16: fTemp = 2.5;
	}
	
	return fTemp;
}

TransferPlayer(const id)
{
	new TeamName:iTeam;
		
	if(is_user_connected(id))
	{
		iTeam = rg_get_user_team(id);

		if(TEAM_TERRORIST <= iTeam <= TEAM_CT)
		{
			set_player_team(id, iTeam == TEAM_TERRORIST ? TEAM_CT : TEAM_TERRORIST);
			
			if(is_user_bot(id)) return;
			
			new szName[32];
			get_user_name(id, szName, charsmax(szName));
			
			if(get_pcvar_num(g_pPlayerNotify) == 1)
			{
				set_hudmessage(244, 118, 88, 0.19, -0.29, 2, _, 5.0, 0.07, .channel = 3);
				show_hudmessage(id, "%L %L", id, "TB_INFO",/* szName,*/ id, iTeam == TEAM_TERRORIST ? "TB_CT" : "TB_TT");
			}
			else if(get_pcvar_num(g_pPlayerNotify) == 2)
			{
				client_print(id, print_chat, "%L %L %L", id, "TB_PREFIX", id, "TB_INFO",/* szName,*/ id, iTeam == TEAM_TERRORIST ? "TB_CT" : "TB_TT");
			}
			
			if(get_pcvar_num(g_pSoundNotify))
			{
				rg_send_audio(id, "buttons/button2.wav");
			}
			
			if(get_pcvar_num(g_pAdminNotify))
			{
				new szFlags[15];
				get_pcvar_string(g_pAdminFlag, szFlags, charsmax(szFlags));
				
				for(new i = 1; i <= MaxClients; i++)
				{
					if(i == id) continue;
					
					if(get_user_flags(i) & read_flags(szFlags))
						client_print(i, print_console, "%L %L", i, "TB_ADMIN_INFO", szName, i, iTeam == TEAM_TERRORIST ? "TB_CT" : "TB_TT");
				}
			}
		}
	}
}

set_player_team(const id, TeamName:iTeam)
{
	switch(iTeam)
	{
		case TEAM_TERRORIST: 
		{
			if(get_member(id, m_bHasDefuser))
			{
				rg_give_defusekit(id, false);
			}
		}
		case TEAM_CT:
		{
			if(get_member(id, m_bHasC4))
			{
				rg_drop_item(id, "weapon_c4");
			}
		}
	}
	
	rg_set_user_team(id, iTeam, MODEL_AUTO, true);
	rg_reset_user_model(id, true);
}

Float:get_skill(iKills, iDeaths, iHeadShots)
{
	new Float:fSkill;
	if(iDeaths == 0) 
	{
		iDeaths = 1;
	}
	fSkill = (float(iKills)+ float(iHeadShots))/float(iDeaths);
	
	return fSkill;
}