#include <amxmodx>
#include <reapi>

enum _:DATA { Float:KILLS, DEATH, MONEY, TeamName:TEAM };

new g_szTempData[MAX_CLIENTS + 1][DATA];
new g_szAuthID[MAX_CLIENTS + 1][MAX_AUTHID_LENGTH];

new Trie:g_tPlayerScore;

new HookChain:hRestartRoundPre;

public plugin_end() {
	TrieDestroy(g_tPlayerScore);
}

public plugin_init() {
	register_plugin("Save score & money", "1.3.7", "Minni Mouse");

	RegisterHookChain(RG_RoundEnd, "refwd_RoundEnd_Post", .post = true);

	DisableHookChain((hRestartRoundPre = 
		RegisterHookChain(RG_CSGameRules_RestartRound, "refwd_RestartRound_Pre", .post = false))
	);

	g_tPlayerScore = TrieCreate();
}

public client_disconnected(pPlayer) {
	if(is_user_hltv(pPlayer) || is_user_bot(pPlayer)) {
		return;
	}

	if(g_szAuthID[pPlayer][0]) {
		g_szTempData[pPlayer][KILLS] = Float:get_entvar(pPlayer, var_frags);
		g_szTempData[pPlayer][DEATH] = get_member(pPlayer, m_iDeaths);
		g_szTempData[pPlayer][MONEY] = get_member(pPlayer, m_iAccount);
		g_szTempData[pPlayer][TEAM] = get_member(pPlayer, m_iTeam);

		TrieSetArray(g_tPlayerScore, g_szAuthID[pPlayer], g_szTempData[pPlayer], DATA);
	}
}

public client_putinserver(pPlayer) {
	if(is_user_hltv(pPlayer) || is_user_bot(pPlayer)) {
		return;
	}

	get_user_authid(pPlayer, g_szAuthID[pPlayer], charsmax(g_szAuthID[]));

	if(TrieGetArray(g_tPlayerScore, g_szAuthID[pPlayer], g_szTempData[pPlayer], DATA)) {
		set_entvar(pPlayer, var_frags, g_szTempData[pPlayer][KILLS]);
		set_member(pPlayer, m_iDeaths, g_szTempData[pPlayer][DEATH]);
		rg_add_account(pPlayer, g_szTempData[pPlayer][MONEY], AS_SET, false);
		
		if(!(get_user_flags(pPlayer) & ADMIN_MENU))
			rg_join_team(pPlayer, g_szTempData[pPlayer][TEAM]);
	}
	else {
		arrayset(_:g_szTempData[pPlayer], _:0.0, sizeof(g_szTempData[]));
	}
}

public refwd_RestartRound_Pre() {
	DisableHookChain(hRestartRoundPre);

	TrieClear(g_tPlayerScore);
}

public refwd_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	if(event == ROUND_GAME_COMMENCE || event == ROUND_GAME_RESTART) {
		EnableHookChain(hRestartRoundPre);
	}
}