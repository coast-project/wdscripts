/*
 * Copyright (c) 2000 itopia
 * All Rights Reserved
 *
 * initialization of tmpl library
 *
 * $Id$
 */

#ifdef __GNUG__
	#pragma implementation
#endif

//--- c-library modules used ---------------------------------------------------
#if defined(WIN32)
	#include <windows.h>
	#include "ITOString.h"
	#include "SysLog.h"
#endif

//--- standard modules used ----------------------------------------------------

//--- interface include --------------------------------------------------------
#include "config_tmpl.h"

static char static_c_rcs_id[] = "itopia, ($Id$)";
static char	static_h_rcs_id[] = config_TMPL_H_ID;
#ifdef __GNUG__
	#define USE(name1,name2) static void use##name1() { if(!name1 && !name2) { use##name1(); } }
	USE(static_h_rcs_id,static_c_rcs_id)
	#undef USE
#endif

//--- used modules
#if defined(WIN32)
	#ifdef _DLL

// DllMain() is the entry-point function for this DLL.
BOOL WINAPI	DllMain(HANDLE hinstDLL,	// DLL module handle
	DWORD fdwReason,					// reason called
	LPVOID lpvReserved)					// reserved
{
	switch (fdwReason) {

		// The DLL is loading due to process
		// initialization or a call to LoadLibrary.
		case DLL_PROCESS_ATTACH:
			SysLog::Info("tmpl: DLL_PROCESS_ATTACH called");
			break;

		// The attached process creates a new thread.
		case DLL_THREAD_ATTACH:
			break;

		// The thread of the attached process terminates.
		case DLL_THREAD_DETACH:
			break;

		// The DLL unloading due to process termination or call to FreeLibrary
		case DLL_PROCESS_DETACH:
			SysLog::Info("tmpl: DLL_PROCESS_DETACH called");
			break;

		default:
			break;
	}

	return TRUE;
	UNREFERENCED_PARAMETER(hinstDLL);
	UNREFERENCED_PARAMETER(lpvReserved);
}

	#endif	// _DLL
#endif	// WIN32
