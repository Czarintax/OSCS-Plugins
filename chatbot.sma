#include <amxmodx>

#define VERSION "1.2"

/*```````````````````````````*/
/*       CONFIGURATION       */
/*```````````````````````````*/

	//#define BLOCKWORDS
	//#define HIDE_SLASH
	#define DELAY 300.0 
	#define PRINTDELAY 0.2
	//#define PRINTTOALL // ( Default : Off )

/* ``````````````````````````*/

new szArg[192];
enum _:VARTYPE {
	text[32], response[192]
}
/* ````````````  PUBLIC AD MESSAGES HERE ``````````` */
new adszArgs[][] = 
{
	^"^6t.me/oscsgroup"
}
/* `````````````````````````````````````````````````` */

/* ````````````` TEXT AND RESPONSE HERE  ```````````` */

new variables[][VARTYPE] =
{
	{ "telegram", ^"^6t.me/oscsgroup" }
}

/* `````````````````````````````````````````````````` */
/* `````````````` WORDS TO BLOCK HERE ``````````````` */

#if defined BLOCKWORDS

new BlockWords[][] = 
{
	""
}

/* ```````````````````````````````````````````````````*/
#endif

public plugin_init() {

	register_plugin("Chat Bot", VERSION, "DiGiTaL")
	register_cvar("chatbot", VERSION, FCVAR_SERVER|FCVAR_SPONLY)
	register_clcmd("say", "handleSay")
	register_clcmd("say_team", "handleSay")
	set_task(DELAY, "show_ads",_,_,_, "b")
}

public show_ads() {

	static numMsg
	new players[32], num, x
	get_players(players, num);
	
	for(new i;i<num;i++) {
		x = players[i];
		client_print(x, print_chat, ^"%s", adszArgs[numMsg > charsmax(adszArgs) ? (numMsg = 0) : numMsg]);
	}
	numMsg++;
}

public handleSay(id) {

	read_args(szArg, charsmax(szArg))
	remove_quotes(szArg)
	#if defined HIDE_SLASH
	if(szArg[0] == '/') return PLUGIN_HANDLED_MAIN
	else if(szArg[0] == '!') return PLUGIN_HANDLED_MAIN
	#endif
	#if defined BLOCKWORDS
	new bool:isWord = false;
	for(new i; i < sizeof BlockWords;i++) {

		if(containi(szArg, BlockWords[i]) != -1) {

			replace_string(szArg, charsmax(szArg), BlockWords[i], "", false)
			isWord = true;		
		} 
	}

	if(isWord) { 

		new enCmd[32]
		read_argv(0, enCmd, charsmax(enCmd))  
		engclient_cmd(id, enCmd, szArg)    
	}
	#endif
	set_task(PRINTDELAY, "PrintT", id)
	return PLUGIN_CONTINUE
}

public PrintT(id)
{
	for(new i=0; i < sizeof variables;i++)
	{
		if(containi(szArg, variables[i][text]) != -1)
		{
			#if defined PRINTTOALL
			client_print(0, print_chat, ^"%s", variables[i][response])
			#else 
			client_print(id, print_chat, ^"%s", variables[i][response])
			#endif
		}
	}
}