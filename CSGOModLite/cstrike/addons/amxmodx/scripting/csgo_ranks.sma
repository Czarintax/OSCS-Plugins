#include <amxmodx>
#include <sqlx>
#include <reapi>
#include <csgomod>

#define PLUGIN	"CS:GO Rank System"
#define AUTHOR	"O'Zone & Czarintax"

#define get_elo(%1,%2) (1.0 / (1.0 + floatpower(10.0, ((%1 - %2) / 400.0))))
#define set_elo(%1,%2,%3) (%1 + 7.5 * (%2 - %3))

#define TASK_HUD 7501
#define TASK_TIME 6701

#define MAX_RANKS 18

new const rankName[MAX_RANKS + 1][] = {
	"Unranked",
	"Silver I",
	"Silver II",
	"Silver III",
	"Silver IV",
	"Silver Elite",
	"Silver Elite Master",
	"Gold Nova I",
	"Gold Nova II",
	"Gold Nova III",
	"Gold Nova Master",
	"Master Guardian I",
	"Master Guardian II",
	"Master Guardian Elite",
	"Distinguished Master Guardian",
	"Legendary Eagle",
	"Legendary Eagle Master",
	"Supreme Master First Class",
	"Global Elite"
};

new const rankElo[MAX_RANKS + 1] = {
	-1,
	0,
	100,
	120,
	140,
	160,
	180,
	200,
	215,
	230,
	245,
	260,
	275,
	290,
	315,
	340,
	370,
	410,
	450
};
#if defined XASH3D
new const rankColor[MAX_RANKS + 1][] = {
	^"^7",
	^"^7",
	^"^7",
	^"^7",
	^"^7",
	^"^7",
	^"^7",
	^"^3",
	^"^3",
	^"^3",
	^"^3",
	^"^2",
	^"^2",
	^"^2",
	^"^2",
	^"^4",
	^"^4",
	^"^1",
	^"^6"
};
#endif
stock const yearSeconds[2] =
{
	31536000,	// Normal year
	31622400	// Leap year
};

stock const monthSeconds[12] =
{
	2678400, // January	  31
	2419200, // February  28
	2678400, // March	  31
	2592000, // April	  30
	2678400, // May		  31
	2592000, // June	  30
	2678400, // July	  31
	2678400, // August	  31
	2592000, // September 30
	2678400, // October	  31
	2592000, // November  30
	2678400	 // December  31
};

enum timeZones
{
	UT_TIMEZONE_SERVER,
	UT_TIMEZONE_MIT,
	UT_TIMEZONE_HAST,
	UT_TIMEZONE_AKST,
	UT_TIMEZONE_AKDT,
	UT_TIMEZONE_PST,
	UT_TIMEZONE_PDT,
	UT_TIMEZONE_MST,
	UT_TIMEZONE_MDT,
	UT_TIMEZONE_CST,
	UT_TIMEZONE_CDT,
	UT_TIMEZONE_EST,
	UT_TIMEZONE_EDT,
	UT_TIMEZONE_PRT,
	UT_TIMEZONE_CNT,
	UT_TIMEZONE_AGT,
	UT_TIMEZONE_BET,
	UT_TIMEZONE_CAT,
	UT_TIMEZONE_UTC,
	UT_TIMEZONE_WET,
	UT_TIMEZONE_WEST,
	UT_TIMEZONE_CET,
	UT_TIMEZONE_CEST,
	UT_TIMEZONE_EET,
	UT_TIMEZONE_EEST,
	UT_TIMEZONE_ART,
	UT_TIMEZONE_EAT,
	UT_TIMEZONE_MET,
	UT_TIMEZONE_NET,
	UT_TIMEZONE_PLT,
	UT_TIMEZONE_IST,
	UT_TIMEZONE_BST,
	UT_TIMEZONE_ICT,
	UT_TIMEZONE_CTT,
	UT_TIMEZONE_AWST,
	UT_TIMEZONE_JST,
	UT_TIMEZONE_ACST,
	UT_TIMEZONE_AEST,
	UT_TIMEZONE_SST,
	UT_TIMEZONE_NZST,
	UT_TIMEZONE_NZDT
}

stock const timeZoneOffset[timeZones] =
{
	-1,
	-39600,
	-36000,
	-32400,
	-28800,
	-28800,
	-25200,
	-25200,
	-21600,
	-21600,
	-18000,
	-18000,
	-14400,
	-14400,
	-12600,
	-10800,
	-10800,
	-3600,
	0,
	0,
	3600,
	3600,
	7200,
	7200,
	10800,
	7200,
	10800,
	12600,
	14400,
	18000,
	19800,
	21600,
	25200,
	28800,
	28800,
	32400,
	34200,
	36000,
	39600,
	43200,
	46800
};

stock timeZones:timeZone;
stock const daySeconds = 86400;
stock const hourSeconds = 3600;
stock const minuteSeconds = 60;

new const commandMenu[][] = { "say /statsmenu", "say_team /statsmenu" };
new const commandRank[][] = { "say /rank", "say_team /rank" };
new const commandRanks[][] = { "say /ranks", "say_team /ranks" };
new const commandTopRanks[][] = { "say /top15", "say_team /top15" };
new const commandTime[][] = { "say /time", "say_team /time", "time" };
new const commandTopTime[][] = { "say /ttop15", "say_team /ttop15" };
new const commandMedals[][] = { "say /medals", "say_team /medals" };
new const commandTopMedals[][] = { "say /mtop15", "say_team /mtop15" };
new const commandStats[][] = { "say /stats", "say_team /stats" };
new const commandTopStats[][] = { "say /stop15", "say_team /stop15" };
new const commandHud[][] = { "say /hud", "say_team /hud" };

enum _:playerInfo { KILLS, ASSISTS, DEATHS, HS, RANK, TIME, FIRST_VISIT, LAST_VISIT, BRONZE, SILVER, GOLD, MEDALS, BEST_STATS, BEST_KILLS,
	BEST_ASSISTS, BEST_HS, BEST_DEATHS, CURRENT_STATS, CURRENT_KILLS, CURRENT_ASSISTS, CURRENT_HS, CURRENT_DEATHS, PLAYER_HUD_RED, PLAYER_HUD_GREEN,
	PLAYER_HUD_BLUE, PLAYER_HUD_POSX, PLAYER_HUD_POSY, Float:ELO_RANK, NAME[32], SAFE_NAME[64], AUTH_ID[65] };
enum _:winners { THIRD, SECOND, FIRST };

new playerData[MAX_PLAYERS + 1][playerInfo], sprites[MAX_RANKS + 1], Handle:sql, bool:sqlConnected, bool:mapChange,
	bool:block, loaded, hudLoaded, visit, hud, bool:changeHud[MAX_PLAYERS + 1], hudSite[64], hudAccount, hudClan, hudOperation,
	unrankedKills, saveType, Float:winnerReward, planter;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_dictionary("time.txt");

	bind_pcvar_num(create_cvar("csgo_ranks_unranked_kills", "100"), unrankedKills);
	bind_pcvar_float(create_cvar("csgo_ranks_winner_reward", "10.0"), winnerReward);

	bind_pcvar_string(create_cvar("csgo_ranks_hud_site", ""), hudSite, charsmax(hudSite));
	bind_pcvar_num(create_cvar("csgo_ranks_hud_account", "0"), hudAccount);
	bind_pcvar_num(create_cvar("csgo_ranks_hud_clan", "0"), hudClan);
	bind_pcvar_num(create_cvar("csgo_ranks_hud_operation", "0"), hudOperation);

	bind_pcvar_num(get_cvar_pointer("csgo_save_type"), saveType);

	for (new i; i < sizeof commandMenu; i++) register_clcmd(commandMenu[i], "cmd_menu");
	for (new i; i < sizeof commandRank; i++) register_clcmd(commandRank[i], "cmd_rank");
	for (new i; i < sizeof commandRanks; i++) register_clcmd(commandRanks[i], "cmd_ranks");
	for (new i; i < sizeof commandTopRanks; i++) register_clcmd(commandTopRanks[i], "cmd_topranks");
	for (new i; i < sizeof commandTime; i++) register_clcmd(commandTime[i], "cmd_time");
	for (new i; i < sizeof commandTopTime; i++) register_clcmd(commandTopTime[i], "cmd_toptime");
	for (new i; i < sizeof commandMedals; i++) register_clcmd(commandMedals[i], "cmd_medals");
	for (new i; i < sizeof commandTopMedals; i++) register_clcmd(commandTopMedals[i], "cmd_topmedals");
	for (new i; i < sizeof commandStats; i++) register_clcmd(commandStats[i], "cmd_stats");
	for (new i; i < sizeof commandTopStats; i++) register_clcmd(commandTopStats[i], "cmd_topstats");
	for (new i; i < sizeof commandHud; i++) register_clcmd(commandHud[i], "change_hud");

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", 1);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", 0);
	RegisterHookChain(RG_CSGameRules_PlayerKilled, "CSGameRules_PlayerKilled_Post", 1);
	RegisterHookChain(RG_CGrenade_ExplodeBomb, "CGrenade_ExplodeBomb", 1);
	RegisterHookChain(RG_PlantBomb, "PlantBomb", 1);
	RegisterHookChain(RG_CGrenade_DefuseBombEnd, "CGrenade_DefuseBombEnd", 1);
	RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", 1);
	RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", 1);
	
	register_message(SVC_INTERMISSION, "message_intermission");

	register_event("StatusValue", "show_icon", "be", "1=2", "2!0");

	hud = CreateHudSyncObj();
}

public plugin_cfg()
	set_task(0.1, "sql_init");

public plugin_end()
	SQL_FreeHandle(sql);

public csgo_reset_data()
{
	for (new i = 1; i <= MAX_PLAYERS; i++) rem_bit(i, loaded);

	sqlConnected = false;

	new tempData[128];

	formatex(tempData, charsmax(tempData), "DROP TABLE `csgo_ranks`; DROP TABLE `csgo_hud`;");

	SQL_ThreadQuery(sql, "ignore_handle", tempData);
}

public plugin_natives()
{
	register_native("csgo_add_kill", "_csgo_add_kill", 1);
	register_native("csgo_get_kills", "_csgo_get_kills", 1);
	register_native("csgo_add_assist", "_csgo_add_assist", 1);
	register_native("csgo_get_assists", "_csgo_get_assists", 1);
	register_native("csgo_get_rank", "_csgo_get_rank", 1);
	register_native("csgo_get_rank_name", "_csgo_get_rank_name", 1);
	register_native("csgo_get_current_rank_name", "_csgo_get_current_rank_name", 1);
	register_native("csgo_get_time", "_csgo_get_time", 1);
}

public plugin_precache()
{
	new spriteFile[32], bool:error;

	for (new i = 0; i <= MAX_RANKS; i++) {
		spriteFile[0] = '^0';

		formatex(spriteFile, charsmax(spriteFile), "sprites/csgo_ranks/%d.spr", i);

		if (!file_exists(spriteFile)) {
			log_to_file("csgo-error.log", "[CS:GO] Missing sprite file: ^"%s^"", spriteFile);

			error = true;
		} else {
			sprites[i] = precache_model(spriteFile);
		}
	}

	if (error) set_fail_state("Missing sprite files, loading the plugin is impossible! Check the logs in csgo_error.log!");
}

public sql_init()
{
	new host[64], user[64], pass[64], database[64], error[256], errorNum;

	get_cvar_string("csgo_sql_host", host, charsmax(host));
	get_cvar_string("csgo_sql_user", user, charsmax(user));
	get_cvar_string("csgo_sql_pass", pass, charsmax(pass));
	get_cvar_string("csgo_sql_db", database, charsmax(database));

	sql = SQL_MakeDbTuple(host, user, pass, database);

	new Handle:connectHandle = SQL_Connect(sql, errorNum, error, charsmax(error));

	if (errorNum) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] Init SQL Error: %s (%i)", error, errorNum);

		return;
	}

	new queryData[1024], bool:hasError;

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `csgo_ranks` (`name` VARCHAR(64), `authid` VARCHAR(65), `kills` INT NOT NULL DEFAULT 0, `assists` INT NOT NULL DEFAULT 0, `deaths` INT NOT NULL DEFAULT 0, `hs` INT NOT NULL DEFAULT 0, `rank` INT NOT NULL DEFAULT 0, `time` INT NOT NULL DEFAULT 0, ");
	add(queryData, charsmax(queryData), "`firstvisit` INT NOT NULL DEFAULT 0, `lastvisit` INT NOT NULL DEFAULT 0, `gold` INT NOT NULL DEFAULT 0, `silver` INT NOT NULL DEFAULT 0, `bronze` INT NOT NULL DEFAULT 0, `medals` INT NOT NULL DEFAULT 0, ");
	add(queryData, charsmax(queryData), "`bestkills` INT NOT NULL DEFAULT 0, `bestassists` INT NOT NULL DEFAULT 0, `bestdeaths` INT NOT NULL DEFAULT 0, `besths` INT NOT NULL DEFAULT 0, `beststats` INT NOT NULL DEFAULT 0, `elorank` double NOT NULL DEFAULT 0, PRIMARY KEY (name, authid));");

	new Handle:query = SQL_PrepareQuery(connectHandle, queryData);

	if (!SQL_Execute(query)) {
		SQL_QueryError(query, error, charsmax(error));

		log_to_file("csgo-error.log", "[CS:GO Ranks] Init SQL Error: %s", error);

		hasError = true;
	}

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `csgo_hud` (`name` VARCHAR(64), `authid` VARCHAR(65), `red` INT NOT NULL DEFAULT 0, `green` INT NOT NULL DEFAULT 0, `blue` INT NOT NULL DEFAULT 0, `x` INT NOT NULL DEFAULT 0, `y` INT NOT NULL DEFAULT 0, PRIMARY KEY (name, authid));");

	query = SQL_PrepareQuery(connectHandle, queryData);

	if (!SQL_Execute(query)) {
		SQL_QueryError(query, error, charsmax(error));

		log_to_file("csgo-error.log", "[CS:GO Ranks] Init SQL Error: %s", error);

		hasError = true;
	}

	SQL_FreeHandle(query);
	SQL_FreeHandle(connectHandle);

	if (!hasError) {
		sqlConnected = true;
	}
}

public client_putinserver(id)
{
	for (new i = KILLS; i <= CURRENT_HS; i++) playerData[id][i] = 0;

	playerData[id][ELO_RANK] = _:100.0;

	playerData[id][PLAYER_HUD_RED] = 0;
	playerData[id][PLAYER_HUD_GREEN] = 255;
	playerData[id][PLAYER_HUD_BLUE] = 0;
	playerData[id][PLAYER_HUD_POSX] = 70;
	playerData[id][PLAYER_HUD_POSY] = 6;

	rem_bit(id, loaded);
	rem_bit(id, hudLoaded);
	rem_bit(id, visit);

	if (is_user_bot(id) || is_user_hltv(id)) return;

	get_user_authid(id, playerData[id][AUTH_ID], charsmax(playerData[][AUTH_ID]));
	get_user_name(id, playerData[id][NAME], charsmax(playerData[][NAME]));

	mysql_escape_string(playerData[id][NAME], playerData[id][SAFE_NAME], charsmax(playerData[][SAFE_NAME]));

	set_task(0.1, "load_data", id);
}

public client_disconnected(id)
{
	save_data(id, mapChange ? 2 : 1);

	remove_task(id);
	remove_task(id + TASK_HUD);
	remove_task(id + TASK_TIME);
}

public load_data(id)
{
	if (!sqlConnected) {
		set_task(1.0, "load_data", id);

		return;
	}

	new playerId[1], queryData[128];

	playerId[0] = id;

	switch (saveType) {
		case SAVE_NAME: formatex(queryData, charsmax(queryData), "SELECT * FROM `csgo_ranks` WHERE name = ^"%s^" LIMIT 1;", playerData[id][SAFE_NAME]);
		case SAVE_AUTH_ID: formatex(queryData, charsmax(queryData), "SELECT * FROM `csgo_ranks` WHERE `authid` = ^"%s^" LIMIT 1;", playerData[id][AUTH_ID]);
	}

	SQL_ThreadQuery(sql, "load_data_handle", queryData, playerId, sizeof(playerId));
}

public load_data_handle(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return;
	}

	new id = playerId[0];

	if (SQL_NumRows(query)) {
		playerData[id][KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
		playerData[id][ASSISTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "assists"));
		playerData[id][DEATHS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "deaths"));
		playerData[id][HS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "hs"));
		playerData[id][RANK] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "rank"));
		playerData[id][TIME] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "time"));
		playerData[id][FIRST_VISIT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "firstvisit"));
		playerData[id][LAST_VISIT] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "lastvisit"));
		playerData[id][BRONZE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "bronze"));
		playerData[id][SILVER] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "silver"));
		playerData[id][GOLD] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "gold"));
		playerData[id][MEDALS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "medals"));
		playerData[id][BEST_STATS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "beststats"));
		playerData[id][BEST_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "bestkills"));
		playerData[id][BEST_ASSISTS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "bestassists"));
		playerData[id][BEST_DEATHS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "bestdeaths"));
		playerData[id][BEST_HS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "besths"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "elorank"), playerData[id][ELO_RANK]);

		check_rank(id, 1);
	} else {
		new queryData[256], firstVisit = get_systime();

		formatex(queryData, charsmax(queryData), "INSERT INTO `csgo_ranks` (`name`, `authid`, `firstvisit`, `elorank`) VALUES (^"%s^", ^"%s^", '%i', '%i') ON DUPLICATE KEY UPDATE name=name", playerData[id][SAFE_NAME], playerData[id][AUTH_ID], firstVisit, rankElo[2]);

		SQL_ThreadQuery(sql, "ignore_handle", queryData);
	}

	set_bit(id, loaded);

	new playerId[1], queryData[128];

	playerId[0] = id;

	switch (saveType) {
		case SAVE_NAME: formatex(queryData, charsmax(queryData), "SELECT * FROM `csgo_hud` WHERE name = ^"%s^" LIMIT 1;", playerData[id][SAFE_NAME]);
		case SAVE_AUTH_ID: formatex(queryData, charsmax(queryData), "SELECT * FROM `csgo_hud` WHERE `authid` = ^"%s^" LIMIT 1;", playerData[id][AUTH_ID]);
	}

	SQL_ThreadQuery(sql, "load_hud_handle", queryData, playerId, sizeof(playerId));
}

public load_hud_handle(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return;
	}

	new id = playerId[0];

	if (SQL_NumRows(query)) {
		playerData[id][PLAYER_HUD_RED] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "red"));
		playerData[id][PLAYER_HUD_GREEN] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "green"));
		playerData[id][PLAYER_HUD_BLUE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "blue"));
		playerData[id][PLAYER_HUD_POSX] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "x"));
		playerData[id][PLAYER_HUD_POSY] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "y"));
	} else {
		new queryData[512];

		formatex(queryData, charsmax(queryData), "INSERT INTO `csgo_hud` (`name`, `authid`, `red`, `green`, `blue`, `x`, `y`) VALUES (^"%s^", ^"%s^", '%i', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE name=name",
			playerData[id][SAFE_NAME], playerData[id][AUTH_ID], playerData[id][PLAYER_HUD_RED], playerData[id][PLAYER_HUD_GREEN], playerData[id][PLAYER_HUD_BLUE], playerData[id][PLAYER_HUD_POSX], playerData[id][PLAYER_HUD_POSY]);

		SQL_ThreadQuery(sql, "ignore_handle", queryData);
	}
#if defined XASH3D
	if (!task_exists(id + TASK_HUD)) set_task(1.0, "display_hud", id + TASK_HUD, .flags = "b");
#else
	if (!task_exists(id + TASK_HUD)) set_task(0.1, "display_hud", id + TASK_HUD, .flags = "b");
#endif
	set_bit(id, hudLoaded);
}

stock save_data(id, end = 0)
{
	if (!get_bit(id, loaded)) return;

	new queryData[512], queryDataStats[128], queryDataMedals[128], playerId[1], time = playerData[id][TIME] + get_user_time(id);

	playerId[0] = id;

	playerData[id][CURRENT_STATS] = playerData[id][CURRENT_KILLS] * 3 + playerData[id][CURRENT_HS] * 2 + playerData[id][CURRENT_ASSISTS] - playerData[id][CURRENT_DEATHS] * 2;

	if (playerData[id][CURRENT_STATS] > playerData[id][BEST_STATS]) {
		formatex(queryDataStats, charsmax(queryDataStats), ", `bestkills` = %d, `besths` = %d, `bestassists` = %d, `bestdeaths` = %d, `beststats` = %d",
			playerData[id][CURRENT_KILLS], playerData[id][CURRENT_ASSISTS], playerData[id][CURRENT_HS], playerData[id][CURRENT_DEATHS], playerData[id][CURRENT_STATS]);
	}

	new medals = playerData[id][GOLD] * 3 + playerData[id][SILVER] * 2 + playerData[id][BRONZE];

	if (medals > playerData[id][MEDALS]) {
		formatex(queryDataMedals, charsmax(queryDataMedals), ", `gold` = %d, `silver` = %d, `bronze` = %d, `medals` = %d",
			playerData[id][GOLD], playerData[id][SILVER], playerData[id][BRONZE], medals);
	}

	switch (saveType) {
		case SAVE_NAME: {
			formatex(queryData, charsmax(queryData), "UPDATE `csgo_ranks` SET `authid` = ^"%s^", `kills` = %i, `assists` = %i, `deaths` = %i, `hs` = %i, `rank` = %i, `elorank` = %f, `time` = %i, `lastvisit` = %i%s%s WHERE name = ^"%s^" AND `time` <= %i",
				playerData[id][AUTH_ID], playerData[id][KILLS], playerData[id][ASSISTS], playerData[id][DEATHS], playerData[id][HS], playerData[id][RANK], playerData[id][ELO_RANK], time, get_systime(), queryDataStats, queryDataMedals, playerData[id][SAFE_NAME], time);
		}
		case SAVE_AUTH_ID: {
			formatex(queryData, charsmax(queryData), "UPDATE `csgo_ranks` SET `name` = ^"%s^", `kills` = %i, `assists` = %i, `deaths` = %i, `hs` = %i, `rank` = %i, `elorank` = %f, `time` = %i, `lastvisit` = %i%s%s WHERE authid = ^"%s^" AND `time` <= %i",
				playerData[id][SAFE_NAME], playerData[id][KILLS], playerData[id][ASSISTS], playerData[id][DEATHS], playerData[id][HS], playerData[id][RANK], playerData[id][ELO_RANK], time, get_systime(), queryDataStats, queryDataMedals, playerData[id][AUTH_ID], time);
		}
	}

	switch(end) {
		case 0, 1: SQL_ThreadQuery(sql, "ignore_handle", queryData, playerId, sizeof(playerId));
		case 2: {
			static error[128], errorNum, Handle:sqlConnection, Handle:query;

			sqlConnection = SQL_Connect(sql, errorNum, error, charsmax(error));

			if (!sqlConnection) return;

			query = SQL_PrepareQuery(sqlConnection, queryData);

			if (!SQL_Execute(query)) {
				errorNum = SQL_QueryError(query, error, charsmax(error));

				log_to_file("csgo-error.log", "Save Query Nonthreaded failed. [%d] %s", errorNum, error);

				SQL_FreeHandle(query);
				SQL_FreeHandle(sqlConnection);

				return;
			}

			SQL_FreeHandle(query);
			SQL_FreeHandle(sqlConnection);
		}
	}

	if (end) rem_bit(id, loaded);
}

public ignore_handle(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) {
			log_to_file("csgo-error.log", "[CS:GO] Could not connect to SQL database. [%d] %s", errorNum, error);
		} else if (failState == TQUERY_QUERY_FAILED) {
			log_to_file("csgo-error.log", "[CS:GO] Query failed. [%d] %s", errorNum, error);
		}
	}

	return PLUGIN_CONTINUE;
}

stock check_rank(id, check = 0)
{
	playerData[id][RANK] = 0;

	if (playerData[id][KILLS] < unrankedKills) return;

	while (playerData[id][RANK] < MAX_RANKS && playerData[id][ELO_RANK] >= rankElo[playerData[id][RANK] + 1]) {
		playerData[id][RANK]++;
	}

	if (!check) save_data(id);
}

public display_hud(id)
{
	id -= TASK_HUD;
#if defined XASH3D
	if (!is_entity(id) || !is_user_connected(id)/* || is_user_bot(id)*/ || !get_bit(id, hudLoaded) || !csgo_get_hud(id)) {
		ShowSyncHudMsg(id, hud, " ");
		
		return PLUGIN_CONTINUE;
	}
	
	static address[64], clan[64], operation[64], statTrak[64], account[64], weaponStatTrak = -1, target;

	target = id;

	if (!is_user_alive(id)) {
		target = get_entvar(id, var_iuser2);
		
		set_hudmessage(255, 255, 255, 0.7, 0.25, 3, 0.0, 1.0, 0.0, 0.0, 3);
	}
	else
		set_hudmessage(playerData[id][PLAYER_HUD_RED], playerData[id][PLAYER_HUD_GREEN], playerData[id][PLAYER_HUD_BLUE], float(playerData[id][PLAYER_HUD_POSX]) / 100.0, float(playerData[id][PLAYER_HUD_POSY]) / 100.0, changeHud[id] ? 1 : 3, 0.0, 1.0, 0.0, 0.0, 3);

	if (!target || !get_bit(target, loaded)) {
		ShowSyncHudMsg(id, hud, " ");
		
		return PLUGIN_CONTINUE;
	}
#else
	if (!is_entity(id) || !is_user_connected(id) || is_user_bot(id) || !get_bit(id, hudLoaded) || !csgo_get_hud(id)) return PLUGIN_CONTINUE;
	
	static address[64], clan[64], operation[64], statTrak[64], account[64], weaponStatTrak = -1, target;

	target = id;

	if (!is_user_alive(id)) {
		target = get_entvar(id, var_iuser2);

		set_hudmessage(255, 255, 255, 0.7, 0.25, 0, 0.0, 0.3, 0.0, 0.0, 3);
	}
	else
		set_hudmessage(playerData[id][PLAYER_HUD_RED], playerData[id][PLAYER_HUD_GREEN], playerData[id][PLAYER_HUD_BLUE], float(playerData[id][PLAYER_HUD_POSX]) / 100.0, float(playerData[id][PLAYER_HUD_POSY]) / 100.0, changeHud[id] ? 1 : 0, 0.0, 0.3, 0.0, 0.0, 3);

	if (!target || !get_bit(target, loaded)) return PLUGIN_CONTINUE;
#endif
	static seconds, minutes, hours;

	seconds = (playerData[target][TIME] + get_user_time(target))
	minutes = 0;
	hours = 0;

	while (seconds >= 60) {
		seconds -= 60;
		minutes++;
	}

	while (minutes >= 60) {
		minutes -= 60;
		hours++;
	}

	csgo_get_user_clan_name(target, clan, charsmax(clan));
	csgo_get_user_operation_text(target, operation, charsmax(operation));

	if (hudAccount) {
		if (csgo_get_user_svip(target)) {
			formatex(account, charsmax(account), "%L", id, "CSGO_RANKS_HUD_SUPERVIP");
		} else if (csgo_get_user_vip(target)) {
			formatex(account, charsmax(account), "%L", id, "CSGO_RANKS_HUD_VIP");
		} else {
			formatex(account, charsmax(account), "%L", id, "CSGO_RANKS_HUD_DEFAULT");
		}
	} else {
		account = "";
	}

	if (hudClan) {
		format(clan, charsmax(clan), "%L", id, "CSGO_RANKS_HUD_CLAN", clan);
	} else {
		clan = "";
	}
	
	if (hudOperation) {
		format(operation, charsmax(operation), "%L", id, "CSGO_RANKS_HUD_OPERATION", operation);
	} else {
		operation = "";
	}
	
	if (strlen(hudSite)) {
		formatex(address, charsmax(address), "%L", id, "CSGO_RANKS_HUD_SITE", hudSite);
	} else {
		address = "";
	}

	weaponStatTrak = csgo_get_weapon_stattrak(target, get_user_weapon(target));

	if (weaponStatTrak > -1) {
		format(statTrak, charsmax(statTrak), "%L", id, "CSGO_RANKS_HUD_STATTRAK", weaponStatTrak);
	} else {
		statTrak = "";
	}

	if (!playerData[target][RANK]) {
		ShowSyncHudMsg(id, hud, "%L", id, "CSGO_RANKS_HUD_NO_RANK", address, account, clan, rankName[playerData[target][RANK]], playerData[target][KILLS], unrankedKills, statTrak, csgo_get_money(target), operation, hours, minutes, seconds);
	} else if (playerData[target][RANK] < MAX_RANKS) {
		ShowSyncHudMsg(id, hud, "%L", id, "CSGO_RANKS_HUD_RANK", address, account, clan, rankName[playerData[target][RANK]], playerData[target][ELO_RANK], rankElo[playerData[target][RANK] + 1], statTrak, csgo_get_money(target), operation, hours, minutes, seconds);
	} else {
		ShowSyncHudMsg(id, hud, "%L", id, "CSGO_RANKS_HUD_MAX_RANK", address, account, clan, rankName[playerData[target][RANK]], playerData[target][ELO_RANK], statTrak, csgo_get_money(target), operation, hours, minutes, seconds);
	}

	return PLUGIN_CONTINUE;
}

public CBasePlayer_Spawn_Post(id)
{
	if (!is_user_alive(id))
		return HC_CONTINUE;
#if defined XASH3D
	if (task_exists(id + TASK_HUD)) {
		remove_task(id + TASK_HUD);
		ClearSyncHud(id, hud);
	
		set_hudmessage(id, 0, 0, float(playerData[id][PLAYER_HUD_POSX]) / 100.0, float(playerData[id][PLAYER_HUD_POSY]) / 100.0, 0, 0.0, 0.0, 0.0, 0.0, 3);
		show_hudmessage(id , " ");
		
		set_task(1.0, "display_hud", id + TASK_HUD, .flags="b");
	} else
		set_task(1.0, "display_hud", id + TASK_HUD, .flags="b");
#else
	if (!task_exists(id + TASK_HUD)) set_task(0.1, "display_hud", id + TASK_HUD, .flags="b");
#endif
	if (!get_bit(id, visit)) set_task(3.0, "check_time", id + TASK_TIME);

	save_data(id);
	
	return HC_CONTINUE;
}

public CSGameRules_RestartRound_Pre()
{
	if (get_member_game(m_bCompleteReset) || mapChange)
		return HC_CONTINUE;

	new bestId, bestFrags, tempFrags, bestDeaths, tempDeaths;
	
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) continue;

		tempFrags = floatround(Float:get_entvar(id, var_frags));
		tempDeaths = get_member(id, m_iDeaths);

		if (tempFrags > 0 && tempFrags > bestFrags) {
			bestFrags = tempFrags;
			bestDeaths = tempDeaths;
			bestId = id;
		}
	}

	if (is_user_connected(bestId) && bestFrags) {
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_connected(i) || is_user_hltv(i) || is_user_bot(i)) continue;
#if defined XASH3D
			client_print(i, print_chat, ^"%L", i, "CSGO_RANKS_CURRENT_LEADER", bestId, bestFrags, bestDeaths);
#else
			client_print_color(i, bestId, "%L", i, "CSGO_RANKS_CURRENT_LEADER", bestId, bestFrags, bestDeaths);
#endif
		}
	}
	
	return HC_CONTINUE;
}

public CSGameRules_PlayerKilled_Post(victim, killer)
{
	if (block) return HC_CONTINUE;
#if defined XASH3D	
	if (task_exists(victim + TASK_HUD)) {
		remove_task(victim + TASK_HUD);
		ClearSyncHud(victim, hud);
	
		set_hudmessage(victim, 0, 0, float(playerData[victim][PLAYER_HUD_POSX]) / 100.0, float(playerData[victim][PLAYER_HUD_POSY]) / 100.0, 0, 0.0, 0.0, 0.0, 0.0, 3);
		show_hudmessage(victim , " ");
		
		set_task(1.0, "display_hud", victim + TASK_HUD, .flags="b");
	}
#endif
	if (victim != killer)
	{
		playerData[victim][CURRENT_DEATHS]++;
		playerData[victim][DEATHS]++;

		playerData[killer][CURRENT_KILLS]++;
		playerData[killer][KILLS]++;

		if (get_member(victim, m_bHeadshotKilled)) {
			playerData[killer][CURRENT_HS]++;
			playerData[killer][HS]++;
		}

		if (csgo_get_min_players()) {
			playerData[killer][ELO_RANK] = _:set_elo(playerData[killer][ELO_RANK], 1.0, get_elo(playerData[victim][ELO_RANK], playerData[killer][ELO_RANK]));
			playerData[victim][ELO_RANK] = floatmax(1.0, set_elo(playerData[victim][ELO_RANK], 0.0, get_elo(playerData[killer][ELO_RANK], playerData[victim][ELO_RANK])));
		}
		
		check_rank(killer);
		check_rank(victim);
#if defined XASH3D
		client_print(victim, print_chat, ^"%L", victim, "CSGO_RANKS_KILLED", killer, floatround(Float:get_entvar(killer, var_health)));
#else
		client_print_color(victim, killer, "%L", victim, "CSGO_RANKS_KILLED", killer, floatround(Float:get_entvar(killer, var_health)));
#endif
	}

	new tCount, ctCount, lastT, lastCT;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_alive(i)) continue;

		new TeamName:team = get_member(i, m_iTeam);
		
		switch (team) {
			case TEAM_TERRORIST: {
				tCount++;
				lastT = i;
			} case TEAM_CT: {
				ctCount++;
				lastCT = i;
			}
		}
	}

	if (tCount == 1 && ctCount == 1) {
		new nameT[32], nameCT[32];

		get_user_name(lastT, nameT, charsmax(nameT));
		get_user_name(lastCT, nameCT, charsmax(nameCT));

		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_connected(i) || is_user_hltv(i) || is_user_bot(i)) continue;
			
			set_hudmessage(255, 128, 0, -1.0, 0.30, 0, 5.0, 5.0, 0.5, 0.15);
			show_hudmessage(i, "%L", i, "CSGO_RANKS_VS_NAMES", nameT, nameCT);
		}
	} else if (tCount == 1 && ctCount > 1) {
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_connected(i) || is_user_hltv(i) || is_user_bot(i)) continue;

			set_hudmessage(255, 128, 0, -1.0, 0.30, 0, 5.0, 5.0, 0.5, 0.15);
			show_hudmessage(i, "%L", i, "CSGO_RANKS_VS_NUMBERS", tCount, ctCount);
		}
	} else if (tCount > 1 && ctCount == 1) {
		for (new i = 1; i <= MAX_PLAYERS; i++) {
			if (!is_user_connected(i) || is_user_hltv(i) || is_user_bot(i)) continue;

			set_hudmessage(255, 128, 0, -1.0, 0.30, 0, 5.0, 5.0, 0.5, 0.15);
			show_hudmessage(i, "%L", i, "CSGO_RANKS_VS_NUMBERS", ctCount, tCount);
		}
	}
	
	return HC_CONTINUE;
}

public CGrenade_ExplodeBomb(const this, tracehandle, const bitsDamageType)
{
	if (!csgo_get_min_players()) return;

	playerData[planter][KILLS] += 3;
	playerData[planter][ELO_RANK] += 3.0;

	check_rank(planter);
}

public PlantBomb(id, Float:vecStart[3], Float:vecVelocity[3])
{
	planter = id;
}

public CGrenade_DefuseBombEnd(const this, const id, bool:bDefused)
{
	if (!csgo_get_min_players() || !bDefused) return;

	playerData[id][KILLS] += 3;
	playerData[id][ELO_RANK] += 3.0;

	check_rank(id);
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{
	if(status != WINSTATUS_CTS && status != WINSTATUS_TERRORISTS) {
		return HC_CONTINUE;
	}
	
	if (!csgo_get_min_players()) {
		return HC_CONTINUE;
	}
	
	new players[MAX_PLAYERS], num;
	
	switch(status) {
		case WINSTATUS_CTS: get_players(players, num, "ae", "TERRORIST");
		case WINSTATUS_TERRORISTS: get_players(players, num, "ae", "CT");
	}
	
	for(new i; i < num; i++) {
		new Float:elo = 3.0;
		
		playerData[players[i]][ELO_RANK] -= elo;

		check_rank(players[i]);
	}
	
	return HC_CONTINUE;
}

public CBasePlayer_AddAccount(const id, amount, RewardType:type, bool:bTrackChange)
{
	if (type == RT_HOSTAGE_RESCUED)
	{
		if (csgo_get_min_players())
		{
			playerData[id][KILLS] += 3;
			playerData[id][ELO_RANK] += 3.0;

			check_rank(id);
		}
	}
	
	return HC_CONTINUE;
}

public check_time(id)
{
	id -= TASK_TIME;

	if (get_bit(id, visit)) return;

	if (!get_bit(id, loaded)) {
		set_task(3.0, "check_time", id + TASK_TIME);

		return;
	}

	set_bit(id, visit);

	new time = get_systime(), visitYear, Year, visitMonth, Month, visitDay, Day, visitHour, visitMinutes, visitSeconds;

	unix_to_time(time, visitYear, visitMonth, visitDay, visitHour, visitMinutes, visitSeconds, UT_TIMEZONE_SERVER);
#if defined XASH3D
	client_print(id, print_chat, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_HOUR", visitHour, visitMinutes, visitDay, visitMonth, visitYear);

	if (playerData[id][FIRST_VISIT] == playerData[id][LAST_VISIT]) client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_FIRST", id);
	else {
		unix_to_time(playerData[id][LAST_VISIT], Year, Month, Day, visitHour, visitMinutes, visitSeconds, UT_TIMEZONE_SERVER);

		if (visitYear == Year && visitMonth == Month && visitDay == Day) client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_TODAY", id, visitHour, visitMinutes);
		else if (visitYear == Year && visitMonth == Month && (visitDay - 1) == Day) client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_YESTERDAY", id, visitHour, visitMinutes);
		else client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_BEFORE", id, visitHour, visitMinutes, Day, Month, Year);
	}
#else
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_HOUR", visitHour, visitMinutes, visitDay, visitMonth, visitYear);

	if (playerData[id][FIRST_VISIT] == playerData[id][LAST_VISIT]) client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_FIRST", id);
	else {
		unix_to_time(playerData[id][LAST_VISIT], Year, Month, Day, visitHour, visitMinutes, visitSeconds, UT_TIMEZONE_SERVER);

		if (visitYear == Year && visitMonth == Month && visitDay == Day) client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_TODAY", id, visitHour, visitMinutes);
		else if (visitYear == Year && visitMonth == Month && (visitDay - 1) == Day) client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_YESTERDAY", visitHour, visitMinutes);
		else client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_VISIT_BEFORE", visitHour, visitMinutes, Day, Month, Year);
	}
#endif	
}

public cmd_menu(id)
{
	new menuData[64];

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TITLE");

	new menu = menu_create(menuData, "cmd_menu_handle");

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_RANKS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_RANK");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TOP_RANKS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TIME");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TOP_TIME");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_STATS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TOP_STATS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_MEDALS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_MENU_TOP_MEDALS");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_MENU_PREVIOUS");
	menu_setprop(menu, MPROP_BACKNAME, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_MENU_NEXT");
	menu_setprop(menu, MPROP_NEXTNAME, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, menuData);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public cmd_menu_handle(id, menu, item)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	switch (item) {
		case 0: cmd_ranks(id);
		case 1: cmd_rank(id);
		case 2: cmd_topranks(id);
		case 3: cmd_time(id);
		case 4: cmd_toptime(id);
		case 5: cmd_stats(id);
		case 6: cmd_topstats(id);
		case 7: cmd_medals(id);
		case 8: cmd_topmedals(id);
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public cmd_ranks(id)
{
	new motdTitle[32], motdFile[32];

	formatex(motdTitle, charsmax(motdTitle), "%L", id, "CSGO_RANKS_MOTD_TITLE");
	formatex(motdFile, charsmax(motdFile), "%L", id, "CSGO_RANKS_MOTD_FILE");

	show_motd(id, motdFile, motdTitle);

	return PLUGIN_HANDLED;
}

public cmd_rank(id)
{
#if defined XASH3D
	client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_CURRENT_RANK", id, rankName[playerData[id][RANK]]);

	if (playerData[id][RANK] < MAX_RANKS && playerData[id][RANK] > 0) {
		client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_NEXT_RANK", id, rankElo[playerData[id][RANK] + 1] - playerData[id][ELO_RANK], rankName[playerData[id][RANK] + 1]);
	}
#else
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_CURRENT_RANK", rankName[playerData[id][RANK]]);

	if (playerData[id][RANK] < MAX_RANKS && playerData[id][RANK] > 0) {
		client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_NEXT_RANK", id, rankElo[playerData[id][RANK] + 1] - playerData[id][ELO_RANK], rankName[playerData[id][RANK] + 1]);
	}
#endif
	return PLUGIN_HANDLED;
}

public cmd_topranks(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;

	format(queryData, charsmax(queryData), "SELECT name, elorank, rank FROM `csgo_ranks` WHERE rank > 0 ORDER BY elorank DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_topranks", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}
#if defined XASH3D
public show_topranks(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], points[16], Float:elo, rank, topLength, place;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_RANKS");
	formatex(points, charsmax(points), "%L", id, "CSGO_RANKS_TOP_ELO");

	topLength = format(topData, charsmax(topData), ^"^0%1s ^3%s - %s%s", "#", nick, name, "^n");

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		SQL_ReadResult(query, 1, elo);

		rank = SQL_ReadResult(query, 2);
		topLength += format(topData[topLength], charsmax(topData) - topLength, ^"^0%1i ^7%s ^0[^7 %s%L ^0] ^2%.2f ^7%s%s", place, name/*, ranks*/, rankColor[rank], id, rankName[rank], elo, points, "^n");

		SQL_NextRow(query);
	}
	
	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_RANKS");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#else
public show_topranks(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], ranks[16], points[16], Float:elo, rank, topLength, place;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(ranks, charsmax(ranks), "%L", id, "CSGO_RANKS_TOP_RANK");
	formatex(points, charsmax(points), "%L", id, "CSGO_RANKS_TOP_ELO");

	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %13s %4s^n", "#", nick, ranks, points);

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		SQL_ReadResult(query, 1, elo);

		rank = SQL_ReadResult(query, 2);

		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1s %12.2f^n", place, name, rankName[rank], elo);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %2s %12.2f^n", place, name, rankName[rank], elo);

		SQL_NextRow(query);
	}

	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_RANKS");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#endif
public cmd_time(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) as count FROM `csgo_ranks`) a CROSS JOIN (SELECT COUNT(*) as rank FROM `csgo_ranks` WHERE `time` > '%i' ORDER BY `time` DESC) b", playerData[id][TIME] + get_user_time(id));

	SQL_ThreadQuery(sql, "show_time", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_time(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = playerId[0];

	new rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1), seconds = (playerData[id][TIME] + get_user_time(id)), minutes, hours;

	while (seconds >= 60) {
		seconds -= 60;
		minutes++;
	}

	while (minutes >= 60) {
		minutes -= 60;
		hours++;
	}
#if defined XASH3D
	client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_TIME_INFO", hours, minutes, seconds);
	client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_TIME_TOP", rank, players);
#else
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_TIME_INFO", hours, minutes, seconds);
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_TIME_TOP", rank, players);
#endif
	return PLUGIN_HANDLED;
}

public cmd_toptime(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;

	format(queryData, charsmax(queryData), "SELECT name, time FROM `csgo_ranks` ORDER BY time DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_toptime", queryData, playerId, sizeof(playerId));
}
#if defined XASH3D
public show_toptime(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], hTitle[16], topLength, place, seconds, minutes, hours;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_TIME");
	formatex(hTitle, charsmax(hTitle), "%L", id, "TIME_ELEMENT_HOURS");

	topLength = format(topData, charsmax(topData), ^"^0%1s ^3%s%s", "#"/*, nick*/, name, "^n");

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		seconds = SQL_ReadResult(query, 1);
		minutes = 0;
		hours = 0;

		while (seconds >= 60) {
			seconds -= 60;
			minutes++;
		}

		while (minutes >= 60) {
			minutes -= 60;
			hours++;
		}
		
		topLength += format(topData[topLength], charsmax(topData) - topLength, ^"^0%1i ^7[ ^1%i ^3%s ^7] %s%s", place, hours, hTitle, name, "^n");

		SQL_NextRow(query);
	}
	
	show_motd(id, topData);

	return PLUGIN_HANDLED;
}
#else
public show_toptime(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], time[16], topLength, place, seconds, minutes, hours;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(time, charsmax(time), "%L", id, "CSGO_RANKS_TOP_TIME");

	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %9s^n", "#", nick, time);

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		seconds = SQL_ReadResult(query, 1);
		minutes = 0;
		hours = 0;

		while (seconds >= 60) {
			seconds -= 60;
			minutes++;
		}

		while (minutes >= 60) {
			minutes -= 60;
			hours++;
		}

		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %0ih %1imin %1is^n", place, name, hours, minutes, seconds);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1ih %1imin %1is^n", place, name, hours, minutes, seconds);

		SQL_NextRow(query);
	}

	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_TIME");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#endif
public cmd_medals(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) as count FROM `csgo_ranks`) a CROSS JOIN (SELECT COUNT(*) as rank FROM `csgo_ranks` WHERE `medals` > '%i' ORDER BY `medals` DESC) b", playerData[id][MEDALS]);

	SQL_ThreadQuery(sql, "show_medals", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_medals(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = playerId[0], rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1);
#if defined XASH3D
	client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_INFO", playerData[id][GOLD], playerData[id][SILVER], playerData[id][BRONZE]);
	client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_TOP", rank, players);
#else
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_INFO", playerData[id][GOLD], playerData[id][SILVER], playerData[id][BRONZE]);
	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_TOP", rank, players);
#endif
	return PLUGIN_HANDLED;
}

public cmd_topmedals(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;

	format(queryData, charsmax(queryData), "SELECT name, gold, silver, bronze, medals FROM `csgo_ranks` ORDER BY medals DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_topmedals", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}
#if defined XASH3D
public show_topmedals(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], sumTitle[16], goldTitle[16], silverTitle[16], bronzeTitle[16], topLength, place, gold, silver, bronze, medals;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_MEDALS")
	formatex(sumTitle, charsmax(sumTitle), "%L", id, "CSGO_RANKS_TOP_SUM");
	formatex(goldTitle, charsmax(goldTitle), "%L", LANG_SERVER, "CSGO_RANKS_TOP_GOLD");
	formatex(silverTitle, charsmax(silverTitle), "%L", LANG_SERVER, "CSGO_RANKS_TOP_SILVER");
	formatex(bronzeTitle, charsmax(bronzeTitle), "%L", LANG_SERVER, "CSGO_RANKS_TOP_BRONZE");
	
	topLength = format(topData, charsmax(topData), ^"^0%1s ^3%s - %s%s", "#", nick, name, "^n");

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		gold = SQL_ReadResult(query, 1);
		silver = SQL_ReadResult(query, 2);
		bronze = SQL_ReadResult(query, 3);
		medals = SQL_ReadResult(query, 4);
		topLength += format(topData[topLength], charsmax(topData) - topLength, ^"^0%1i ^7%s ^0[ ^1%d ^3%s, ^1%d ^3%s, ^1%d ^3%s ^0] ( ^3%s: ^1%d ^0)%s", place, name, gold, goldTitle, silver, silverTitle, bronze, bronzeTitle, sumTitle, medals, "^n");
		
		SQL_NextRow(query);
	}

	show_motd(id, topData);

	return PLUGIN_HANDLED;
}
#else
public show_topmedals(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nameTitle[16], sumTitle[16], goldTitle[16], silverTitle[16], bronzeTitle[16], topLength, place, gold, silver, bronze, medals;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nameTitle, charsmax(nameTitle), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(sumTitle, charsmax(sumTitle), "%L", id, "CSGO_RANKS_TOP_SUM");
	formatex(goldTitle, charsmax(goldTitle), "%L", id, "CSGO_RANKS_TOP_GOLD");
	formatex(silverTitle, charsmax(silverTitle), "%L", id, "CSGO_RANKS_TOP_SILVER");
	formatex(bronzeTitle, charsmax(bronzeTitle), "%L", id, "CSGO_RANKS_TOP_BRONZE");

	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %6s %8s %8s %5s^n", "#", nameTitle, goldTitle, silverTitle, bronzeTitle, sumTitle);

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		gold = SQL_ReadResult(query, 1);
		silver = SQL_ReadResult(query, 2);
		bronze = SQL_ReadResult(query, 3);
		medals = SQL_ReadResult(query, 4);

		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %2d %7d %8d %7d^n", place, name, gold, silver, bronze, medals);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %3d %7d %8d %7d^n", place, name, gold, silver, bronze, medals);

		SQL_NextRow(query);
	}

	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_MEDALS");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#endif
public cmd_stats(id)
{
	new queryData[192], playerId[1];

	playerId[0] = id;

	playerData[id][CURRENT_STATS] = playerData[id][CURRENT_KILLS]*3 + playerData[id][CURRENT_HS]*2 + playerData[id][CURRENT_ASSISTS] - playerData[id][CURRENT_DEATHS]*2;

	formatex(queryData, charsmax(queryData), "SELECT rank, count FROM (SELECT COUNT(*) as count FROM `csgo_ranks`) a CROSS JOIN (SELECT COUNT(*) as rank FROM `csgo_ranks` WHERE `beststats` > '%i' ORDER BY `beststats` DESC) b",
		playerData[id][CURRENT_STATS] > playerData[id][BEST_STATS] ? playerData[id][CURRENT_STATS] : playerData[id][BEST_STATS]);

	SQL_ThreadQuery(sql, "show_stats", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}

public show_stats(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = playerId[0], rank = SQL_ReadResult(query, 0) + 1, players = SQL_ReadResult(query, 1);
#if defined XASH3D
	if (playerData[id][CURRENT_STATS] > playerData[id][BEST_STATS]) client_print(id, print_chat, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_INFO", playerData[id][CURRENT_KILLS], playerData[id][CURRENT_HS], playerData[id][CURRENT_ASSISTS], playerData[id][CURRENT_DEATHS]);
	else client_print(id, print_chat, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_INFO", playerData[id][BEST_KILLS], playerData[id][BEST_HS], playerData[id][BEST_ASSISTS], playerData[id][BEST_DEATHS]);

	client_print(id, print_chat, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_TOP", rank, players);
#else
	if (playerData[id][CURRENT_STATS] > playerData[id][BEST_STATS]) client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_INFO", playerData[id][CURRENT_KILLS], playerData[id][CURRENT_HS], playerData[id][CURRENT_ASSISTS], playerData[id][CURRENT_DEATHS]);
	else client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_INFO", playerData[id][BEST_KILLS], playerData[id][BEST_HS], playerData[id][BEST_ASSISTS], playerData[id][BEST_DEATHS]);

	client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_STATS_TOP", rank, players);
#endif
	return PLUGIN_HANDLED;
}

public cmd_topstats(id)
{
	new queryData[128], playerId[1];

	playerId[0] = id;

	format(queryData, charsmax(queryData), "SELECT name, bestkills, besths, bestassists, bestdeaths FROM `csgo_ranks` ORDER BY beststats DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_topstats", queryData, playerId, sizeof(playerId));

	return PLUGIN_HANDLED;
}
#if defined XASH3D
public show_topstats(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], topLength, place, kills, headShots, assists, deaths;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_STATS");

	topLength = format(topData, charsmax(topData), ^"^0%1s ^3%s - %s%s", "#", nick, name, "^n");

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		kills = SQL_ReadResult(query, 1);
		headShots = SQL_ReadResult(query, 2);
		assists = SQL_ReadResult(query, 3);
		deaths = SQL_ReadResult(query, 4);
		topLength += format(topData[topLength], charsmax(topData) - topLength, ^"^0%1i ^7%s ^0[ ^3K: ^5%d ^7/ ^3A: ^2%d ^7/ ^3D: ^1%d ^0] ( ^2%i ^3HS ^0)%s", place, name, kills, assists, deaths, headShots, "^n");

		SQL_NextRow(query);
	}
	
	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_STATS");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#else
public show_topstats(failState, Handle:query, error[], errorNum, playerId[], dataSize)
{
	if (failState) {
		log_to_file("csgo-error.log", "[CS:GO Ranks] SQL error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	static topData[2048], name[32], nick[16], killsTitle[16], assistsTitle[16], deathsTitle[16], topLength, place, kills, headShots, assists, deaths;

	topLength = 0, place = 0;

	new id = playerId[0];

	formatex(nick, charsmax(nick), "%L", id, "CSGO_RANKS_TOP_NICK");
	formatex(killsTitle, charsmax(killsTitle), "%L", id, "CSGO_RANKS_TOP_KILLS");
	formatex(assistsTitle, charsmax(assistsTitle), "%L", id, "CSGO_RANKS_TOP_ASSISTS");
	formatex(deathsTitle, charsmax(deathsTitle), "%L", id, "CSGO_RANKS_TOP_DEATHS");

	topLength = format(topData, charsmax(topData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	topLength += format(topData[topLength], charsmax(topData) - topLength, "%1s %-22.22s %19s %12s %4s^n", "#", nick, killsTitle, assistsTitle, deathsTitle);

	while (SQL_MoreResults(query)) {
		place++;

		SQL_ReadResult(query, 0, name, charsmax(name));

		replace_all(name, charsmax(name), "<", "");
		replace_all(name, charsmax(name), ">", "");

		kills = SQL_ReadResult(query, 1);
		headShots = SQL_ReadResult(query, 2);
		assists = SQL_ReadResult(query, 3);
		deaths = SQL_ReadResult(query, 4);

		if (place >= 10) topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %1d (%i HS) %12d %12d^n", place, name, kills, headShots, assists, deaths);
		else topLength += format(topData[topLength], charsmax(topData) - topLength, "%1i %-22.22s %2d (%i HS) %12d %12d^n", place, name, kills, headShots, assists, deaths);

		SQL_NextRow(query);
	}

	formatex(name, charsmax(name), "%L", id, "CSGO_RANKS_TOP15_STATS");

	show_motd(id, topData, name);

	return PLUGIN_HANDLED;
}
#endif
public show_icon(id)
{
	new target = read_data(2);

	if (!is_entity(id) || !is_entity(target) || !is_user_alive(id) || !is_user_alive(target)) return;

	new rank = playerData[target][RANK];

	if (get_member(id, m_iTeam) == get_member(target, m_iTeam)) {
		create_attachment(id, target, 45, sprites[rank], 15);
	}
}

public message_intermission()
{
	mapChange = true;

	new playerName[32], medal[16], winnersId[3], winnersFrags[3], tempFrags, swapFrags, swapId;

	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) continue;

		tempFrags = floatround(Float:get_entvar(id, var_frags));

		if (tempFrags > winnersFrags[THIRD]) {
			winnersFrags[THIRD] = tempFrags;
			winnersId[THIRD] = id;

			if (tempFrags > winnersFrags[SECOND]) {
				swapFrags = winnersFrags[SECOND];
				swapId = winnersId[SECOND];
				winnersFrags[SECOND] = tempFrags;
				winnersId[SECOND] = id;
				winnersFrags[THIRD] = swapFrags;
				winnersId[THIRD] = swapId;

				if (tempFrags > winnersFrags[FIRST]) {
					swapFrags = winnersFrags[FIRST];
					swapId = winnersId[FIRST];
					winnersFrags[FIRST] = tempFrags;
					winnersId[FIRST] = id;
					winnersFrags[SECOND] = swapFrags;
					winnersId[SECOND] = swapId;
				}
			}
		}
	}

	if (!winnersId[FIRST]) return PLUGIN_CONTINUE;

	for (new i = 2; i >= 0; i--) {
		switch (i) {
			case THIRD: playerData[winnersId[i]][BRONZE]++;
			case SECOND: playerData[winnersId[i]][SILVER]++;
			case FIRST: {
				playerData[winnersId[i]][GOLD]++;

				csgo_add_money(winnersId[i], winnerReward);
			}
		}

		save_data(winnersId[i], 1);
	}

	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) continue;
#if defined XASH3D
		client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST");
#else
		client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST");
#endif
		for (new i = 2; i >= 0; i--) {
			switch (i) {
				case THIRD: formatex(medal, charsmax(medal), "%L", id, "CSGO_RANKS_MEDALS_BRONZE");
				case SECOND: formatex(medal, charsmax(medal), "%L", id, "CSGO_RANKS_MEDALS_SILVER");
				case FIRST: formatex(medal, charsmax(medal), "%L", id, "CSGO_RANKS_MEDALS_GOLD");
			}

			get_user_name(winnersId[i], playerName, charsmax(playerName));
#if defined XASH3D
			if (i == FIRST) {
				client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST_MVP", playerName, winnersFrags[i], medal);
			} else {
				client_print(id, print_chat, ^"%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST_EVP", playerName, winnersFrags[i], medal);
			}
#else
			if (i == FIRST) {
				client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST_MVP", playerName, winnersFrags[i], medal);
			} else {
				client_print_color(id, id, "%s %L", CHAT_PREFIX, id, "CSGO_RANKS_MEDALS_BEST_EVP", playerName, winnersFrags[i], medal);
			}
#endif
		}
	}

	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) continue;

		save_data(id, 1);
	}

	return PLUGIN_CONTINUE;
}

public change_hud(id)
{
	if (!is_user_connected(id) || !get_bit(id, hudLoaded)) return PLUGIN_HANDLED;

	if (is_user_alive(id))
	{
		if (!changeHud[id])
			changeHud[id] = true;
#if defined XASH3D	
		if (task_exists(id + TASK_HUD)) {
			remove_task(id + TASK_HUD);
			ClearSyncHud(id, hud);
	
			set_hudmessage(0, 0, 0, float(playerData[id][PLAYER_HUD_POSX]) / 100.0, float(playerData[id][PLAYER_HUD_POSY]) / 100.0, 0, 0.0, 0.0, 0.0, 0.0, 3);
			show_hudmessage(id , " ");
			
			set_task(0.1, "display_hud", id + TASK_HUD, .flags="b");
		}
#endif
	}
	
	new menuData[64], menu;

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_TITLE");

	menu = menu_create(menuData, "change_hud_handle");

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_RED", playerData[id][PLAYER_HUD_RED]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_GREEN", playerData[id][PLAYER_HUD_GREEN]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_BLUE", playerData[id][PLAYER_HUD_BLUE]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_X", playerData[id][PLAYER_HUD_POSX]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_Y", playerData[id][PLAYER_HUD_POSY]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_RANKS_HUD_SETTINGS_DEFAULT");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "%L", id, "CSGO_MENU_EXIT");
	menu_setprop(menu, MPROP_EXITNAME, menuData);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public change_hud_handle(id, menu, item)
{
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		
		if (is_user_alive(id))
		{
			if (changeHud[id])
				changeHud[id] = false;
#if defined XASH3D			
			if (task_exists(id + TASK_HUD)) {
				remove_task(id + TASK_HUD);
				ClearSyncHud(id, hud);
	
				set_hudmessage(0, 0, 0, float(playerData[id][PLAYER_HUD_POSX]) / 100.0, float(playerData[id][PLAYER_HUD_POSY]) / 100.0, 0, 0.0, 0.0, 0.0, 0.0, 3);
				show_hudmessage(id , " ");
			
				set_task(1.0, "display_hud", id + TASK_HUD, .flags="b");
			}
#endif
		}		
		return PLUGIN_HANDLED;
	}

	switch (item) {
		case 0: if ((playerData[id][PLAYER_HUD_RED] += 15) > 255) playerData[id][PLAYER_HUD_RED] = 0;
		case 1: if ((playerData[id][PLAYER_HUD_GREEN] += 15) > 255) playerData[id][PLAYER_HUD_GREEN] = 0;
		case 2: if ((playerData[id][PLAYER_HUD_BLUE] += 15) > 255) playerData[id][PLAYER_HUD_BLUE] = 0;
		case 3: if ((playerData[id][PLAYER_HUD_POSX] += 3) > 100) playerData[id][PLAYER_HUD_POSX] = 0;
		case 4: if ((playerData[id][PLAYER_HUD_POSY] += 3) > 100) playerData[id][PLAYER_HUD_POSY] = 0;
		case 5: {
			playerData[id][PLAYER_HUD_RED] = 0;
			playerData[id][PLAYER_HUD_GREEN] = 255;
			playerData[id][PLAYER_HUD_BLUE] = 0;
			playerData[id][PLAYER_HUD_POSX] = 70;
			playerData[id][PLAYER_HUD_POSY] = 6;
		}
	}

	menu_destroy(menu);

	save_hud(id);

	change_hud(id);

	return PLUGIN_CONTINUE;
}

public save_hud(id)
{
	if (!get_bit(id, hudLoaded)) return;

	new tempData[256];

	switch (saveType) {
		case SAVE_NAME: {
			formatex(tempData, charsmax(tempData), "UPDATE `csgo_hud` SET `red` = '%i', `green` = '%i', `blue` = '%i', `x` = '%i', `y` = '%i', `authid` = ^"%s^" WHERE `name` = ^"%s^"",
				playerData[id][PLAYER_HUD_RED], playerData[id][PLAYER_HUD_GREEN], playerData[id][PLAYER_HUD_BLUE], playerData[id][PLAYER_HUD_POSX], playerData[id][PLAYER_HUD_POSY], playerData[id][AUTH_ID], playerData[id][NAME]);
		}
		case SAVE_AUTH_ID: {
			formatex(tempData, charsmax(tempData), "UPDATE `csgo_hud` SET `red` = '%i', `green` = '%i', `blue` = '%i', `x` = '%i', `y` = '%i', `name` = ^"%s^" WHERE `authid` = ^"%s^"",
				playerData[id][PLAYER_HUD_RED], playerData[id][PLAYER_HUD_GREEN], playerData[id][PLAYER_HUD_BLUE], playerData[id][PLAYER_HUD_POSX], playerData[id][PLAYER_HUD_POSY], playerData[id][NAME], playerData[id][AUTH_ID]);
		}
	}

	SQL_ThreadQuery(sql, "ignore_handle", tempData);
}

public _csgo_add_kill(id)
{
	playerData[id][CURRENT_KILLS]++;
	playerData[id][KILLS]++;
}

public _csgo_add_assist(id)
{
	playerData[id][CURRENT_ASSISTS]++;
	playerData[id][ASSISTS]++;
}

public _csgo_get_kills(id)
	return playerData[id][KILLS];

public _csgo_get_assists(id)
	return playerData[id][ASSISTS];
	
public _csgo_get_deaths(id)
	return playerData[id][DEATHS];
	
public _csgo_get_hs(id)
	return playerData[id][HS];

public _csgo_get_rank(id)
	return playerData[id][RANK];
	
public _csgo_get_time(id)
	return playerData[id][TIME];

public _csgo_get_rank_name(rank, dataReturn[], dataLength)
{
	param_convert(2);

	formatex(dataReturn, dataLength, "%L", LANG_PLAYER, rankName[rank]);
}

public _csgo_get_current_rank_name(id, dataReturn[], dataLength)
{
	param_convert(2);

	formatex(dataReturn, dataLength, "%L", id, rankName[playerData[id][RANK]]);
}

stock create_attachment(id, target, offset, sprite, life)
{
	if (!is_entity(id) || !is_entity(target) || !is_user_alive(id) || !is_user_alive(target)) return;

	message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id);
	write_byte(TE_PLAYERATTACHMENT);
	write_byte(target);
	write_coord(offset);
	write_short(sprite);
	write_short(life);
	message_end();
}

stock unix_to_time(timestamp, &year, &month, &day, &hour, &minute, &second, timeZones:tztimeZone=UT_TIMEZONE_UTC)
{
	new temp;

	year = 1970;
	month = 1;
	day = 1;
	hour = 0;

	if (tztimeZone == UT_TIMEZONE_SERVER) {
		tztimeZone = get_timezone();
	}

	timestamp += timeZoneOffset[tztimeZone];

	while (timestamp > 0) {
		temp = is_leap_year(year);

		if ((timestamp - yearSeconds[temp]) >= 0) {
			timestamp -= yearSeconds[temp];
			year++;
		} else {
			break;
		}
	}

	while (timestamp > 0) {
		temp = seconds_in_month(year, month);

		if ((timestamp - temp) >= 0) {
			timestamp -= temp;
			month++;
		} else {
			break;
		}
	}

	while (timestamp > 0) {
		if ((timestamp - daySeconds) >= 0) {
			timestamp -= daySeconds;
			day++;
		} else {
			break;
		}
	}

	while (timestamp > 0) {
		if ((timestamp - hourSeconds) >= 0) {
			timestamp -= hourSeconds;
			hour++;
		} else {
			break;
		}
	}

	minute = (timestamp / 60);
	second = (timestamp % 60);
}

stock time_to_unix(const year, const month, const day, const hour, const minute, const second, timeZones:tztimeZone=UT_TIMEZONE_UTC)
{
	new i, timestamp;

	for (i = 1970; i < year; i++) {
		timestamp += yearSeconds[is_leap_year(i)];
	}

	for (i = 1; i < month; i++) {
		timestamp += seconds_in_month(year, i);
	}

	timestamp += ((day - 1) * daySeconds);
	timestamp += (hour * hourSeconds);
	timestamp += (minute * minuteSeconds);
	timestamp += second;

	if (tztimeZone == UT_TIMEZONE_SERVER) {
		tztimeZone = get_timezone();
	}

	return (timestamp + timeZoneOffset[tztimeZone]);
}

stock timeZones:get_timezone()
{
	if (timeZone) return timeZone;

	new timeZones:zone, offset, temp, year, month, day, hour, minute, second;
	date(year, month, day);
	time(hour, minute, second);

	temp = time_to_unix(year, month, day, hour, minute, second, UT_TIMEZONE_UTC);
	offset = temp - get_systime();

	for (zone = timeZones:0; zone < timeZones; zone++) {
		if (offset == timeZoneOffset[zone]) break;
	}

	return (timeZone = zone);
}

stock seconds_in_month(const year, const month)
{
	return ((is_leap_year(year) && (month == 2)) ? (monthSeconds[month - 1] + daySeconds) : monthSeconds[month - 1]);
}

stock is_leap_year(const year)
{
	return (((year % 4) == 0) && (((year % 100) != 0) || ((year % 400) == 0)));
}
