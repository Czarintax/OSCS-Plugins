#include <amxmodx>

// Расскоментируйте #define TRUE_NAME_MAP, если необходимо получить истинное название текущей карты
// Полезно тем, у кого установлен плагин mode_2x2, дабы не задавать время для карт с приставкой _2x2
// Потребуется ReAPI

// #define TRUE_NAME_MAP // ReHLDS

#if defined TRUE_NAME_MAP
	#include <reapi>
#endif

#pragma semicolon 1

enum _:MAP_DATA {
	map_name[24],
	map_time
}

new const MAP_NAME_LIST[][MAP_DATA] = {
	{"de_dust2",			60},
	{"de_inferno",			45},
	{"de_nuke",				30},
	{"de_mirage",			40}
};

public plugin_init() {
	register_plugin("Time Maps", "1.0", "Javekson");
	set_task(3.0, "set_time_map", _);
}

public set_time_map() {
	new sMapName[32];
	
	#if defined TRUE_NAME_MAP
		rh_get_mapname(sMapName, charsmax(sMapName), MNT_TRUE);
	#else
		get_mapname(sMapName, charsmax(sMapName));
	#endif
	
	for(new i=0; i < sizeof(MAP_NAME_LIST); ++i) {
		if(equal(sMapName, MAP_NAME_LIST[i])) {
			set_cvar_num("mp_timelimit", MAP_NAME_LIST[i][map_time]); 
			break;
		}
	}
}