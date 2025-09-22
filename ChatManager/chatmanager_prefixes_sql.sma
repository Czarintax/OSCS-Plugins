#include <amxmodx>
#include <sqlx>
#include <chatmanager>

#pragma semicolon 1

#define PLUGIN_NAME "Chat Manager: Prefixes MySQL"
#define PLUGIN_VERSION "0.1b"
#define PLUGIN_AUTHOR "Denzer"

enum _:CVARS
{
    HOST[32],
    USER[16],
    PASS[32],
    DB[16],
    TABLE[32],
    ACCESS[6]
};

enum _:SQL
{
    SQL_TABLE,
    SQL_CLEAR,
    SQL_LOAD,
    SQL_INSERT,
    SQL_DELETE
};

enum _:FIELDS
{
    FIELD_ID,
    FIELD_PLAYER_NAME,
    FIELD_PLAYER_XASHID,
    FIELD_PREFIX,
    FIELD_EXPIRED
};

new g_Cvars[CVARS], g_sPrefix[MAX_PLAYERS + 1][32];
new Handle:g_hSqlTuple, Handle:g_hSqlConnection;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    InitCvars();
    InitCmds();
    InitSQL();
}

public client_putinserver(id)
{
    SQL_Load(id);
}

public plugin_end()
{
    SQL_FreeHandle(g_hSqlTuple);
    if(g_hSqlConnection) SQL_FreeHandle(g_hSqlConnection);
}

public plugin_natives()
{
	register_native("ChatManager_SetPrefix", "_ChatManager_SetPrefix")
}

public InitCvars()
{
    new pCvar;
    pCvar = create_cvar("cm_host", "127.0.0.1", FCVAR_PROTECTED, "Host");
    bind_pcvar_string(pCvar, g_Cvars[HOST], charsmax(g_Cvars[HOST]));

    pCvar = create_cvar("cm_user", "root", FCVAR_PROTECTED, "User");
    bind_pcvar_string(pCvar, g_Cvars[USER], charsmax(g_Cvars[USER]));

    pCvar = create_cvar("cm_pass", "P4-t(nR.em@:7>Up", FCVAR_PROTECTED, "Pass");
    bind_pcvar_string(pCvar, g_Cvars[PASS], charsmax(g_Cvars[PASS]));

    pCvar = create_cvar("cm_db", "amxx", FCVAR_PROTECTED, "DB");
    bind_pcvar_string(pCvar, g_Cvars[DB], charsmax(g_Cvars[DB]));

    pCvar = create_cvar("cm_table", "cm_prefixes", FCVAR_PROTECTED, "Table");
    bind_pcvar_string(pCvar, g_Cvars[TABLE], charsmax(g_Cvars[TABLE]));

    pCvar = create_cvar("cm_access", "l", FCVAR_PROTECTED, "Access");
    bind_pcvar_string(pCvar, g_Cvars[ACCESS], charsmax(g_Cvars[ACCESS]));

    AutoExecConfig();
}

public InitCmds()
{
    // "player_name" "player_authid" "prefix" "days"
    register_concmd("cm_set_prefix_sql", "CmdSetPrefix");
    // "player_authid"
    register_concmd("cm_reset_prefix_sql", "CmdResetPrefix");
}

public CmdSetPrefix(id)
{
    if(id && ~get_user_flags(id) & read_flags(g_Cvars[ACCESS]))
        return PLUGIN_HANDLED;

    new szArgs[256], szName[MAX_NAME_LENGTH], szAuth[MAX_AUTHID_LENGTH], szPrefix[32], szDays[6];
    read_args(szArgs, charsmax(szArgs));
    remove_quotes(szArgs);
    trim(szArgs);

    parse(szArgs,
        szName, charsmax(szName),
        szAuth, charsmax(szAuth),
        szPrefix, charsmax(szPrefix),
        szDays, charsmax(szDays));

    new iDays = str_to_num(szDays);

    if(!szAuth[0] || !szPrefix[0])
    {
        console_print(id, "[%s] Error. Syntax: cm_set_prefix_sql ^"name^" ^"authid^" ^"prefix^" ^"days^"", PLUGIN_NAME);
        return PLUGIN_HANDLED;
    }

    SQL_Insert(szName, szAuth, szPrefix, iDays);
    console_print(id, "[%s] Prefix set: %s | %s | %s | %d day(s)", PLUGIN_NAME, szName, szAuth, szPrefix, iDays);

    return PLUGIN_HANDLED;
}

public CmdResetPrefix(id)
{
    if(id && ~get_user_flags(id) & read_flags(g_Cvars[ACCESS]))
        return PLUGIN_HANDLED;

    new szAuth[MAX_AUTHID_LENGTH];
    read_args(szAuth, charsmax(szAuth));
    remove_quotes(szAuth);
    trim(szAuth);

    if(!szAuth[0])
    {
        console_print(id, "[%s] Error. Syntax: cm_reset_prefix_sql ^"authid^"", PLUGIN_NAME);
        return PLUGIN_HANDLED;
    }

    SQL_Delete(szAuth);
    console_print(id, "[%s] Data is deleted: %s", PLUGIN_NAME, szAuth);

    return PLUGIN_HANDLED;
}

public InitSQL()
{
    g_hSqlTuple = SQL_MakeDbTuple(g_Cvars[HOST], g_Cvars[USER], g_Cvars[PASS], g_Cvars[DB]);
    SQL_SetCharset(g_hSqlTuple, "utf-8");

    new iError, szError[128];
    g_hSqlConnection = SQL_Connect(g_hSqlTuple, iError, szError, charsmax(szError));

    if(g_hSqlConnection == Empty_Handle)
        set_fail_state("%s %d", szError, iError);

    server_print("[%s] SQL connection was successfully established with the server.", PLUGIN_NAME);

    new szQuery[512];
    new cData[1]; cData[0] = SQL_TABLE;
    formatex(szQuery, charsmax(szQuery), "\
        CREATE TABLE IF NOT EXISTS `%s` \
        ( \
            `id`                INT(11) NOT NULL auto_increment PRIMARY KEY, \
            `player_name`       VARCHAR(32) DEFAULT 'N/A', \
            `player_authid`    VARCHAR(64) DEFAULT 'N/A', \
            `prefix`            VARCHAR(32) DEFAULT 'N/A', \
            `expired`           TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP \
        );", g_Cvars[TABLE]);
    SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
    SQL_Clear();
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime)
{
    if(iFailState != TQUERY_SUCCESS)
    {
        log_amx("SQL Error #%d - %s", iErrnum, szError);
        return;
    }

    switch(cData[0])
    {
        case SQL_TABLE, SQL_CLEAR, SQL_INSERT, SQL_DELETE: {}
        case SQL_LOAD:
        {
            new id = cData[1];

            if(!is_user_connected(id))
                return;

            if(SQL_NumResults(hQuery))
            {
                SQL_ReadResult(hQuery, FIELD_PREFIX, g_sPrefix[id], charsmax(g_sPrefix[]));
                //replace_color_tag(g_sPrefix[id]);
                cm_set_prefix(id, g_sPrefix[id]);
            }
            else
                g_sPrefix[id] = "";
        }
    }
}

public SQL_Clear()
{
    new szQuery[256];
    new cData[1]; cData[0] = SQL_CLEAR;

    formatex(szQuery, charsmax(szQuery), "\
        DELETE \
        FROM   `%s` \
        WHERE  `expired` <= now()", g_Cvars[TABLE]);
    SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Load(id)
{
    new szQuery[256];
    new cData[2]; cData[0] = SQL_LOAD, cData[1] = id;
    new szAuth[MAX_AUTHID_LENGTH]; get_user_authid(id, szAuth, charsmax(szAuth));

    formatex(szQuery, charsmax(szQuery), "\
        SELECT * \
        FROM `%s` \
        WHERE `player_authid` = '%s'", g_Cvars[TABLE], szAuth);
    SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

SQL_Insert(szName[] = "", szAuth[], szPrefix[], iDays)
{
    new szQuery[512], szDays[32];
    new cData[1]; cData[0] = SQL_INSERT;

    if(iDays)
        formatex(szDays, charsmax(szDays), "now() + interval %d day", iDays);

    formatex(szQuery, charsmax(szQuery), "\
        INSERT INTO `%s` \
        ( \
            `player_name`, \
            `player_authid`, \
            `prefix`, \
            `expired` \
        ) \
        VALUES \
        ( \
            '%s', \
            '%s', \
            '%s', \
            %s \
        )", g_Cvars[TABLE], szName, szAuth, szPrefix, !iDays ? "NULL" : szDays);
    SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Delete(szAuth[])
{
    new szQuery[256];
    new cData[1]; cData[0] = SQL_DELETE;

    formatex(szQuery, charsmax(szQuery), "\
        DELETE \
        FROM   `%s` \
        WHERE  `player_authid` = '%s'", g_Cvars[TABLE], szAuth);
    SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}
/*
replace_color_tag(string[])
{
    new len = 0;
    for (new i; string[i] != EOS; i++) {
        if (string[i] == '!') {
            switch (string[++i]) {
                case 'd': string[len++] = 0x01;
                case 't': string[len++] = 0x03;
                case 'g': string[len++] = 0x04;
                case EOS: break;
                default: string[len++] = string[i];
            }
        } else {
            string[len++] = string[i];
        }
    }
    string[len] = EOS;
}
*/
public _ChatManager_SetPrefix(iPluginID, iParamCount) {
		enum { player = 1, authid, prefix, minutes, caller }

		if(!g_hSqlTuple && !g_eCvar[CVAR__LOCAL_MODE]) {
			return -1
		}

		new pPlayer = get_param(player)

		new szAuthID[MAX_AUTHID_LENGTH]
		get_string(authid, szAuthID, chx(szAuthID))

		new szPrefix[12]
		get_string(prefix, szPrefix, chx(szPrefix))

		new iMinutes = get_param(minutes)
		new iCaller = get_param(caller)

		new iRequestID

		if(g_eCvar[CVAR__LOCAL_MODE]) {
			iRequestID = 1
		}
		else {
			iRequestID = random_num(2, 999999)
		}

		new szName[MAX_NAME_LENGTH * 3] = "unknown"
		new szIP[MAX_IP_LENGTH]

		new bitFlagsToSet = read_flags(szFlags)

		if(is_user_connected(pPlayer)) {
			get_user_name(pPlayer, szName, chx(szName))
			get_user_ip(pPlayer, szIP, chx(szIP), .without_port = 1)
			set_user_flags(pPlayer, bitFlagsToSet)
		}

		log_to_file( ADD_ACCESS_LOG_FILENAME, "Adding flags '%s' for %i minutes (caller %i) to <%s><%s><%s><query %i>",
			szFlags, iMinutes, iCaller, szName, szAuthID, szIP, iRequestID );

		if(g_eCvar[CVAR__LOCAL_MODE]) {
			iRequestID = func_AddToUsers(szAuthID, szFlags, szName, iMinutes, iRequestID)

			if(iRequestID != -1) {
				// get_user_userid() is safe to use for disconnected (returns -1)
				func_CallAccessAddedFwd(get_user_userid(pPlayer), iCaller)
			}

			return iRequestID
		}

		new iRowIdToExtend, iQueryType

		for(new i; i < g_iAccCount; i++) {
			ArrayGetArray(g_aAccounts, i, g_eUserData)

			if( !(g_eUserData[ACCOUNT_DATA__AUTH_FLAGS] & FLAG_AUTHID) ) {
				continue
			}

			if(
				szAuthID[12] != g_eUserData[ACCOUNT_DATA__AUTHID][12] // VALVE_XASH_057ea1b40be40469ae9366af21d9557f
					||
				!equal(szAuthID, g_eUserData[ACCOUNT_DATA__AUTHID])
			) {
				continue
			}

			if(bitFlagsToSet == g_eUserData[ACCOUNT_DATA__ACCESS_FLAGS]) {
				iRowIdToExtend = g_eUserData[ACCOUNT_DATA__ROWID]
				break
			}
		}

		if(iRowIdToExtend) {
			if(!g_eUserData[ACCOUNT_DATA__EXPIRE]) {
				log_to_file( ADD_ACCESS_LOG_FILENAME,
					"Query %i, row #%i match and unlimited, no action required",
					iRequestID, iRowIdToExtend
				);

				// get_user_userid() is safe to use for disconnected (returns -1)
				func_CallAccessAddedFwd(get_user_userid(pPlayer), iCaller)

				return 0
			}

			log_to_file( ADD_ACCESS_LOG_FILENAME, "Query %i, row #%i match, do UPDATE",
				iRequestID, iRowIdToExtend );

			new iExpireTime

			if(iMinutes) {
				iExpireTime = g_eUserData[ACCOUNT_DATA__EXPIRE] + (iMinutes * SECONDS_IN_MINUTE)
			}

			formatex( g_szQuery, chx(g_szQuery),
				"UPDATE `amx_amxadmins` SET `expired` = %i WHERE `id` = %i LIMIT 1",

				iExpireTime, iRowIdToExtend
			);

			iQueryType = QUERY__UPDATE_ROW
		}
		else {
			log_to_file( ADD_ACCESS_LOG_FILENAME, "Query %i, do INSERT",
				iRequestID, iRowIdToExtend );

			mysql_escape_string(szName, chx(szName))

			new iSysTime = get_systime()

			new iExpireTime, iDays

			if(iMinutes) {
				iExpireTime = iSysTime + (iMinutes * SECONDS_IN_MINUTE)
				iDays = (iMinutes * SECONDS_IN_MINUTE) / SECONDS_IN_DAY
			}

			formatex( g_szQuery, chx(g_szQuery),
				"INSERT INTO `amx_amxadmins` \
					(`username`,`access`,`flags`,`authid`,`nickname`,`ashow`,`created`,`expired`,`days`,`ingame`) \
						VALUES \
					('%s','%s','ce','%s','%s',0,%i,%i,%i,1)",

				szAuthID, szFlags, szAuthID, szName, iSysTime, iExpireTime, iDays
			);

			iQueryType = QUERY__INSERT_ROW_1
		}

		g_eSqlData[SQL_DATA__REQUEST_ID] = iRequestID
		g_eSqlData[SQL_DATA__CALLER] = iCaller
		g_eSqlData[SQL_DATA__PLAYER_USERID] = get_user_userid(pPlayer) // safe to use for disconnected (returns -1)

		func_MakeQuery(iQueryType)

		return iRequestID
}