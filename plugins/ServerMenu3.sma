#include < amxmodx >

#define VERSION	"3.0.0"
#define SERVERS_DIR			"addons/amxmodx/configs/ServerMenu.cfg"
#define PREFIX "[ServerMenu]"	// Chat prefix

#define MAX_NAME_LENGTH		32	// Zdroj: AMXX 1.8.3 'Dev Builds'
#define MAX_SRVNAME_LENGTH	64	// Maximálny pocet znakov pre názov servera
#define MAX_SRVRIP_LENGTH	32	// Maximálny pocet znakov pre IP adresu

enum _:xSERVER_LIST { xServerList_Name[ MAX_SRVNAME_LENGTH ], xServerList_Address[ MAX_SRVRIP_LENGTH ] };
enum _:xCVARS { xCvar_OnOff, xCvar_Follow, xCvar_ChatMessages };

new pCvars[ xCVARS ],
	g_LastIP,
	g_LocalIPaddID = -1, // premenna drziaca umiestnenie (v menu) IP servera, ktory je zhodny s tymto serverom
	Array:g_aServerCache;

public plugin_end( )
	ArrayDestroy( g_aServerCache );

public plugin_init( )
{
	register_plugin( "Server Menu V3", VERSION, "K@T4pULT" );
	register_dictionary( "smenuv3.txt" );

	register_concmd( "smenu_reload", "clcmd_Reload", ADMIN_BAN, "Reload Server Menu"  )

	new const clcmds_smenu[ ][ ] =
	{ //	Zoznam say prikazov, kludne si mozete nejaky pridat alebo odobrat:
		"say /server","say /servery","say /servers","say /servermenu","say_team /server",
		"say_team /servery","say_team /servers","say_team /servermenu","servermenu"
	};
	new const clcmds_follow[ ][ ] = { "say /follow", "say_team /follow" };
	new i=0, max = sizeof( clcmds_smenu );
	for( ; i < max; i++ )
		register_clcmd( clcmds_smenu[ i ], "menu_Servers" );

	max = sizeof( clcmds_follow );
	for( i=0; i < max; i++ )
		register_clcmd( clcmds_follow[ i ], "clcmd_Follow" );

	pCvars[ xCvar_OnOff ]			= register_cvar( "smenu_onoff", "1" );		// Zapnut plugin | 0:vypnuty | 1:zapnuty
	pCvars[ xCvar_Follow ]			= register_cvar( "smenu_follow", "1" );		// Prikaz follow | 0:vypnuty | 1:zapnuty
	pCvars[ xCvar_ChatMessages ]	= register_cvar( "smenu_chatmsg", "1" );	// Zobrazovat chat notifikacie | 0:vypnute | 1:zapnute

	if( !file_exists( SERVERS_DIR ) )
	{
		write_file( SERVERS_DIR, "// Zoznam serverov: #IP adresa, #Nazov servera" );
		write_file( SERVERS_DIR, "^"192.169.69.69:27069^" ^"TestServer #1^"" );
		write_file( SERVERS_DIR, "^"192.169.69.69:27169^" ^"TestServer #2^"" );
	}
	ReadServersFromFile( );
}

public ReadServersFromFile( )
{
	new fp = fopen( SERVERS_DIR, "r" );	
	if( !fp )
		return log_error( 27, "[ServerMenu] Chyba pri otvarani suboru!" ); // 27 = AMX_ERR_GENERAL

	g_LocalIPaddID = -1;
	g_aServerCache = ArrayCreate( xSERVER_LIST );
	new string_text[ MAX_SRVNAME_LENGTH + MAX_SRVRIP_LENGTH + 10 ], xBuffer[ xSERVER_LIST ], current_ip[ 21 ], x;
	get_user_ip( 0, current_ip, 20, 0 );
	while( !feof( fp ) )
	{
		fgets( fp, string_text, ( MAX_SRVNAME_LENGTH+MAX_SRVRIP_LENGTH+10 ) );
		if( !string_text[ 0 ] || string_text[ 0 ] == ';' || string_text[ 0 ] == '/' && string_text[ 1 ] == '/' )
			continue;

		parse( string_text, xBuffer[ xServerList_Address ], MAX_SRVRIP_LENGTH-1, xBuffer[ xServerList_Name ], MAX_SRVNAME_LENGTH-1 );
		remove_quotes( xBuffer[ xServerList_Name ] );		trim( xBuffer[ xServerList_Name ] );
		remove_quotes( xBuffer[ xServerList_Address ] );	trim( xBuffer[ xServerList_Address ] );
		ArrayPushArray( g_aServerCache, xBuffer );
		if( strcmp( xBuffer[ xServerList_Address ], current_ip, true ) == 0 )
			g_LocalIPaddID = x;

		x++;
	}
	fclose( fp );
	return 1;
}

public clcmd_Reload( id )
{
	if( !( get_user_flags( id ) & ADMIN_BAN ) )
		return PLUGIN_HANDLED;

	ArrayDestroy( g_aServerCache );
	if( ReadServersFromFile( ) )
		return client_print( id, print_console, "[ServerMenu] Reload prebehol uspesne." );

	return PLUGIN_HANDLED;
}

public clcmd_Follow( id )
{
	if( !get_pcvar_num( pCvars[ xCvar_OnOff ] ) )
		return PLUGIN_HANDLED;

	if( !get_pcvar_num( pCvars[ xCvar_Follow ] ) )
		return PLUGIN_HANDLED;

	return hl_menu_Servers( id, 0, g_LastIP );
}

public menu_Servers( id )
{
	new menuid = menu_create( "\yServer Menu \d(\r/server\d)", "hl_menu_Servers" );
//		Items of ServerMenu
	new string_buffer[ 32 ], xBuffer[ xSERVER_LIST ], i, numservers = ArraySize( g_aServerCache );
	for( i = 0; i < numservers; i++ )
	{
		ArrayGetArray( g_aServerCache, i, xBuffer );
		menu_additem( menuid, xBuffer[ xServerList_Name ], _, ( g_LocalIPaddID == i ? (1<<31) : 0 ) ); // Ak je to tento server zablokuje polozku: (1<<31)
	}
	menu_setprop( menuid, MPROP_NUMBER_COLOR, "\r" ); // farba cisel

	format( string_buffer, 31, "%L", id, "SMENU_BACK" );
	menu_setprop( menuid, MPROP_BACKNAME, string_buffer );

	format( string_buffer, 31, "%L", id, "SMENU_NEXT" );
	menu_setprop( menuid, MPROP_NEXTNAME, string_buffer );

	format( string_buffer, 31, "%L", id, "SMENU_CLOSE" );
	menu_setprop( menuid, MPROP_EXITNAME, string_buffer );
//		Display ServerMenu
	return menu_display( id, menuid );
}

public hl_menu_Servers( playerid, menuid, listitem )
{
	if( menuid ) // menuid != 0
		menu_destroy( menuid );

	if( listitem == MENU_EXIT || listitem == g_LocalIPaddID || listitem >= ArraySize( g_aServerCache ) )
		return PLUGIN_HANDLED; // Fixnutý problém s mozným prebugovávaním menuciek..

	g_LastIP = listitem;
	new xBuffer[ xSERVER_LIST ];
	ArrayGetArray( g_aServerCache, listitem, xBuffer );
	if( get_pcvar_num( pCvars[ xCvar_ChatMessages ] ) )
	{
#if AMXX_VERSION_NUM >= 183 /* V case tvorenia pluginu je AMXX 1.8.3 v sekcii 'Dev Builds', no da sa volne stiahnut ;) */
		client_print_color( 0, playerid, "^4%s^1 %L", PREFIX, LANG_PLAYER, "SMENU_LEAVE", get_player_name( playerid ), xBuffer[ xServerList_Name ] );
		if( get_pcvar_num( pCvars[ xCvar_Follow ] ) )
			client_print_color( 0, playerid, "^4%s^1 %L", PREFIX, LANG_PLAYER, "SMENU_FOLLOW" );
#else /* Toto uz pozna aj AMXX 1.8.2, no zial bez farieb ;( */
		client_print( 0, print_chat, "%L", LANG_PLAYER, "SMENU_LEAVE", get_player_name( playerid ), xBuffer[ xServerList_Name ] );
		if( get_pcvar_num( pCvars[ xCvar_Follow ] ) )
			client_print( 0, print_chat, "%L", LANG_PLAYER, "SMENU_FOLLOW" );
#endif
	}
	client_cmd( playerid, "^"reconnect^";^"Connect^" %s", xBuffer[ xServerList_Address ] );
	return PLUGIN_HANDLED;
}

stock get_player_name( index )
{ // stock version 1.0 by K@T4pULT
	new string_nick[ MAX_NAME_LENGTH ];
	get_user_name( index, string_nick, ( MAX_NAME_LENGTH-1 ) );
	return string_nick;
}