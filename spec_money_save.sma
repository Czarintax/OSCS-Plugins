#include <amxmodx>
#include <reapi>

public plugin_init() {
    register_plugin("Spec Money Save", "0.2", "F@nt0M");
    RegisterHookChain(RG_CBasePlayer_AddAccount, "CBasePlayer_AddAccount", 0);
}

public CBasePlayer_AddAccount(const id, amount, RewardType:type) {
    #pragma unused amount

    if (type == RT_PLAYER_SPEC_JOIN) {
    	return HC_SUPERCEDE;
    }

    return (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR) ? HC_SUPERCEDE : HC_CONTINUE;
}