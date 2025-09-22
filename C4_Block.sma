#include <amxmodx>
#include <reapi>

public plugin_init() {
	register_plugin("C4_Block", "1.0.0", "SNauPeR");
	RegisterHookChain(RG_CSGameRules_GiveC4, "CSGameRules_GiveC4_Pre");
}

public CSGameRules_GiveC4_Pre() {
	new Players[32], Count;
	get_players(Players, Count, "ach");
	if(Count < 4) {
		//client_print_color(0, print_team_red, "Бомба ^3не может быть выдана^1, когда один игрок на сервере");
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}