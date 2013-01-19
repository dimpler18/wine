/*
 * Copyright (c) 2006 Robert Reif
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 *
 */

#ifndef __WINE_ADVAPI32MISC_H
#define __WINE_ADVAPI32MISC_H

#include "ntsecapi.h"
#include "winsvc.h"

const char * debugstr_sid(PSID sid) DECLSPEC_HIDDEN;
BOOL ADVAPI_IsLocalComputer(LPCWSTR ServerName) DECLSPEC_HIDDEN;
BOOL ADVAPI_GetComputerSid(PSID sid) DECLSPEC_HIDDEN;

BOOL lookup_local_wellknown_name(const LSA_UNICODE_STRING*, PSID, LPDWORD, LPWSTR, LPDWORD, PSID_NAME_USE, BOOL*) DECLSPEC_HIDDEN;
BOOL lookup_local_user_name(const LSA_UNICODE_STRING*, PSID, LPDWORD, LPWSTR, LPDWORD, PSID_NAME_USE, BOOL*) DECLSPEC_HIDDEN;
WCHAR *SERV_dup(const char *str) DECLSPEC_HIDDEN;
NTSTATUS SERV_QueryServiceObjectSecurity(SC_HANDLE, SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, DWORD, LPDWORD) DECLSPEC_HIDDEN;

#endif /* __WINE_ADVAPI32MISC_H */
