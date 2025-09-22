#include <amxmodx>
#include <reapi>

public plugin_init()
{
	register_plugin("Bomb Distance", "0.1", "Emma Jule");
	
	if ((any:get_member_game(m_bMapHasBombTarget) & ((-1) / 2)) == 0)
		pause("a");
	
	RegisterHookChain(RG_PlantBomb, "PlantBomb", .post = true);
}

public PlantBomb(id, Float:vecStart[3], Float:vecVelocity[3])
{
	#pragma unused vecStart, vecVelocity
	
	if (get_member_game(m_bRoundTerminating))
		return;
	
	new entity = GetHookChainReturn(ATYPE_INTEGER);
	
	if (is_nullent(entity))
		return;
	
	new Float:flOrigin[3]; get_entvar(entity, var_origin, flOrigin);
	
	new pArray[MAX_PLAYERS], pNum; get_players(pArray, pNum, "ace", "TERRORIST"); /* ignore dead, bots and T only */
	
	for (new i, pPlayer, Float:flPlayerOrigin[3]; i < pNum; i++)
	{
		pPlayer = pArray[i];
		
		if (pPlayer == id)
			continue; /* if (distance < 1) */
		
		get_entvar(pPlayer, var_origin, flPlayerOrigin);
		
		client_print(pPlayer, print_chat, ^"[C4] The bomb is placed^5 %.0f ^7meters from you.", vector_distance(flOrigin, flPlayerOrigin) * 0.0254);
	}
}