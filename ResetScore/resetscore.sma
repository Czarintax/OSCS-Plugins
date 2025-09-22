#include <amxmodx>

#define USE_REAPI
#define HIDE_CHAT_MSG
#define INFO_TEXT

#if defined USE_REAPI
	#include <reapi>
#else
	#include <fakemeta>
	const PDATA_SAFE = 2
	const OFFSET_CSDEATHS = 444
	const OFFSET_LINUX = 5
#endif
 
public plugin_init()
{
	register_plugin("ResetScore", "1.0", "Leo_[BH]"); // oscs fork
	register_dictionary("resetscore.txt");

	register_clcmd("say /rs", "reset_score");
	register_clcmd("say_team /rs", "reset_score");
	register_clcmd("say /reset", "reset_score");
	register_clcmd("say_team /reset", "reset_score");
	register_clcmd("say /resetscore", "reset_score");
	register_clcmd("say_team /resetscore", "reset_score");
}

public reset_score(id)
{
	if(!is_user_connected(id)) return PLUGIN_CONTINUE;

	static iFloodTime[33], systime;
	if(iFloodTime[id] > (systime = get_systime()))
	{
		client_print(id, print_center, ^"%L", id, "RS_CHAT_FLOOD", iFloodTime[id] - systime);
	}
	else if(!get_entvar(id, var_frags) && !get_member(id, m_iDeaths))
	{
	client_print(id, print_center, ^"%L", id, "RS_CHAT_ERROR");
	client_cmd(id, "spk ^"cleanup(t20) denied(t20)^"")
	
	iFloodTime[id] = systime + 20;
	}
	else
	{
	func_reset_score(id)
#if defined INFO_TEXT
	text_reset_score(id)
#endif
	iFloodTime[id] = systime + 20;
	}
	
#if defined HIDE_CHAT_MSG
	return PLUGIN_HANDLED;
#else
	return PLUGIN_CONTINUE;
#endif
}

public func_reset_score(id)
{
	#if defined USE_REAPI
	set_entvar(id, var_frags, 0.0);
	set_member(id, m_iDeaths, 0);
	#else
	set_pev(id, pev_frags, 0.0)
	fm_cs_set_user_deaths(id, 0)
	#endif
	
	message_begin(MSG_BROADCAST, 85);
	write_byte(id);
	write_short(0); 
	write_short(0); 
	write_short(0); 
	write_short(get_member(id, m_iTeam));
	message_end();
}

stock fm_cs_set_user_deaths(id, value)
{
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_CSDEATHS, value, OFFSET_LINUX)
}

#if defined INFO_TEXT
public text_reset_score(id)
{
	client_print(0, print_console, ^"%L", LANG_PLAYER, "RS_CHAT_MSG_ALL", id);
	client_print(id, print_center, "%L", LANG_PLAYER, "RS_CHAT_MSG_YOU");
	client_cmd(id, "spk ^"cleanup(t20) terminated(t20)^"");
}
#endif
