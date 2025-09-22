#include <amxmodx>
#include <reapi>

public plugin_init()
{
	register_plugin("[ReAPI] No Team Flash lite", "0.0.3", "Vaqtincha")

	RegisterHookChain(RG_PlayerBlind, "PlayerBlind", .post = false)
}

public PlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha, Float:color[3])
{
	if (index != attacker && get_member(index, m_iTeam) == get_member(attacker, m_iTeam))
	{
		set_member(index, m_blindAlpha, 0);
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}