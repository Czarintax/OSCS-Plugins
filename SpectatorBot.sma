new const VERSION[] = "0.0.2";

#include <amxmodx>
#include <fakemeta>
#include <reapi>

// Имя бота
new const g_szBotName[][] = {
	^"^8t.me/oscsgroup",
	// Можете добавить несколько через запятую;
};

public plugin_init()
{
	register_plugin("Spectator Bot", VERSION, "b0t.");
}

public plugin_cfg()
{
	set_task(3.0, "TaskFunc__BotConnected");
}

public TaskFunc__BotConnected()
{
	for (new i, pBot; i < sizeof(g_szBotName); ++i)
	{
		pBot = engfunc(EngFunc_CreateFakeClient, g_szBotName[i]);

		if (!pBot)
		{
			set_fail_state("Failed to create bot!");
			return;
		}

		dllfunc(MetaFunc_CallGameEntity, "player", pBot);

		set_entvar(pBot, var_flags, FL_FAKECLIENT);
		set_member(pBot, m_iTeam, TeamName: TEAM_UNASSIGNED);
	}
}