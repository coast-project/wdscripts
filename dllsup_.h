/*
 * Copyright (c) 1999-2000 itopia
 * All Rights Reserved
 *
 * $Id$
 */

#ifndef _CONFIG_TMPL_H
#define _CONFIG_TMPL_H

#define config_TMPL_H_ID "itopia, ($Id$)"

// WIN32 settings for Windows NT
#if defined(WIN32)
	#ifdef _DLL
		#ifdef TMPL_IMPL
			#define EXPORTDECL_TMPL	__declspec(dllexport)
		#else
			#define EXPORTDECL_TMPL	__declspec(dllimport)
		#endif
	#else
		#define EXPORTDECL_TMPL
	#endif
#else
	#define EXPORTDECL_TMPL
#endif

#endif
