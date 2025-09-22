#include <amxmodx>
#include <reapi>

#define rg_get_user_team(%0)	 get_member(%0, m_iTeam)

public plugin_init() {
	register_plugin("Block Change Team", "1.0.0", "F@nt0M");
	
	RegisterHookChain(RG_ShowVGUIMenu, "ShowVGUIMenu_Pre", false);
	RegisterHookChain(RG_HandleMenu_ChooseTeam, "HandleMenu_ChooseTeam_Pre", false);
}

public ShowVGUIMenu_Pre(const id, const VGUIMenu:menuType)
{
	if (menuType != VGUI_Menu_Team || get_member(id, m_bJustConnected) ||
	get_user_flags(id) & ADMIN_MENU || rg_get_user_team(id) == TEAM_SPECTATOR) {
		return HC_CONTINUE;
	}
	client_cmd(id, "menu");
	set_member(id, m_iMenu, 0);
	return HC_SUPERCEDE;
}

public HandleMenu_ChooseTeam_Pre(const id)
{
	if (get_member(id, m_bJustConnected) || rg_get_user_team(id) == TEAM_SPECTATOR ||get_user_flags(id) & ADMIN_MENU) {
		return HC_CONTINUE;
	}
	SetHookChainReturn(ATYPE_INTEGER, false);
	return HC_SUPERCEDE;
}
