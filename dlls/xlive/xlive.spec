1 stdcall -noname XWSAStartup(long long)
2 stdcall -noname XWSACleanup()
3 stdcall -noname XSocketCreate(long long long long)
4 stdcall -noname XSocketClose (long)
5 stdcall -noname XSocketShutdown (long long)
6 stdcall -noname XSocketIOCTLSocket(long long long)
7 stdcall -noname XSocketSetSockOpt(long long long long long)
8 stdcall -noname XSocketGetSockOpt(long long long long long)
9 stdcall -noname XSocketGetSockName (long long long)
10 stdcall -noname XSocketGetPeerName (long long long)
11 stdcall -noname XSocketBind (long long long)
12 stdcall -noname XSocketConnect (long long long)
13 stdcall -noname XSocketListen (long long)
14 stdcall -noname XSocketAccept (long long long)
15 stdcall -noname XSocketSelect (long long long long long)
16 stdcall -noname XWSAGetOverlappedResult (long long long long long)
17 stdcall -noname XWSACancelOverlappedIO (long)
18 stdcall -noname XSocketRecv (long long long long)
19 stdcall -noname XWSARecv (long long long long long long long)
20 stdcall -noname XSocketRecvFrom (long long long long long long)
21 stdcall -noname XWSARecvFrom (long long long long long long long long long)
22 stdcall -noname XSocketSend (long long long long)
23 stdcall -noname XWSASend (long long long long long long long)
24 stdcall -noname XSocketSendTo (long long long long long long)
25 stdcall -noname XWSASendTo (long long long long long long long long long)
26 stdcall -noname XSocketInet_Addr (long)
27 stdcall -noname XWSAGetLastError()
28 stdcall -noname XWSASetLastError(long)
29 stdcall -noname XWSACreateEvent()
30 stdcall -noname XWSACloseEvent(long)
31 stdcall -noname XWSASetEvent (long)
32 stdcall -noname XWSAResetEvent (long)
33 stdcall -noname XWSAWaitForMultipleEvents(long long long long long)
34 stdcall -noname __XWSAFDIsSet (long long)
35 stdcall -noname XWSAEventSelect (long long long)
37 stdcall -noname XSocketNTOHS(long)
38 stdcall -noname NetDll_ntohs(long)
39 stdcall -noname XSocketNTOHL(long)
40 stdcall -noname NetDll_htons(long)
51 stdcall -noname XNetStartup(long)
52 stdcall -noname XNetCleanup()
53 stdcall -noname XNetRandom (long long)
54 stdcall -noname XNetCreateKey (long long)
55 stdcall -noname XNetRegisterKey (long long)
56 stdcall -noname XNetUnregisterKey (long)
57 stdcall -noname XNetXnAddrToInAddr (long long long)
58 stdcall -noname XNetServerToInAddr (long long long)
60 stdcall -noname XNetInAddrToXnAddr (long long long)
62 stdcall -noname XNetInAddrToString (long long long)
63 stdcall -noname XNetUnregisterInAddr (long)
64 stdcall -noname XNetXnAddrToMachineId (long long)
65 stdcall -noname XNetConnect (long)
66 stdcall -noname XNetGetConnectStatus (long)
67 stdcall -noname XNetDnsLookup (long long long)
68 stdcall -noname XNetDnsRelease (long long long)
69 stdcall -noname XNetQosListen (long long long long long)
70 stdcall -noname XNetQosLookup (long long long long long long long long long long long long)
71 stdcall -noname NetDll_XNetQosServiceLookup (long long long)
72 stdcall -noname XNetQosRelease (long)
73 stdcall -noname XNetGetTitleXnAddr (long)
75 stdcall -noname XNetGetEthernetLinkStatus ()
76 stdcall -noname XNetGetBroadcastVersionStatus (long)
77 stdcall -noname XNetQosGetListenStats (long long)
78 stdcall -noname XNetGetOpt (long long long)
79 stdcall -noname XNetSetOpt (long long long)
81 stdcall -noname XNetReplaceKey (long long)
82 stdcall -noname XNetGetXnAddrPlatform (long long)
83 stdcall -noname XNetGetSystemLinkPort (long)
84 stdcall -noname XNetSetSystemLinkPort (long)
472 stdcall -noname XCustomSetAction (long long long)
473 stdcall -noname XCustomGetLastActionPress (long long long)
474 stdcall -noname XCustomSetDynamicActions (long long long long long)
476 stdcall -noname XCustomGetLastActionPressEx (long long long long long long)
477 stdcall -noname XCustomUnregisterDynamicActions ()
478 stdcall -noname XCustomRegisterDynamicActions ()
479 stdcall -noname XCustomGetCurrentGamercard (long long)
651 stdcall -noname XNotifyGetNext(long long long long)
652 stdcall -noname XNotifyPositionUI(long)
653 stdcall -noname XNotifyDelayUI(long)
1082 stdcall -noname XGetOverlappedExtendedError(long)
1083 stdcall -noname XGetOverlappedResult(long long long)
5000 stdcall -noname XLiveInitialize(long)
5001 stdcall -noname XliveInput(long)
5002 stdcall -noname XLiveRender()
5003 stdcall -noname XLiveUninitialize()
5005 stdcall -noname XLiveOnCreateDevice(long long)
5006 stdcall -noname XLiveOnDestroyDevice()
5007 stdcall -noname XLiveOnResetDevice(long)
5008 stdcall -noname XHVCreateEngine(long long long)
5010 stdcall -noname XLiveRegisterDataSection (long long long)
5011 stdcall -noname XLiveUnregisterDataSection (long)
5012 stdcall -noname XLiveUpdateHashes (long long)
5016 stdcall -noname XLivePBufferAllocate (long long)
5017 stdcall -noname XLivePBufferFree (long)
5018 stdcall -noname XLivePBufferGetByte (long long long)
5019 stdcall -noname XLivePBufferSetByte (long long long)
5020 stdcall -noname XLivePBufferGetDWORD (long long long)
5021 stdcall -noname XLivePBufferSetDWORD (long long long)
5022 stdcall -noname XLiveGetUpdateInformation (long)
5023 stdcall -noname XNetGetCurrentAdapter(long long)
5024 stdcall -noname XLiveUpdateSystem (long)
5025 stdcall -noname XLiveGetLiveIdError(long long long long)
5026 stdcall -noname XLiveSetSponsorToken (long long)
5027 stdcall -noname XLiveUninstallTitle (long)
5028 stdcall -noname XLiveLoadLibraryEx (long long long)
5029 stdcall -noname XLiveFreeLibrary (long)
5030 stdcall -noname XLivePreTranslateMessage(long)
5031 stdcall -noname XLiveSetDebugLevel(long long)
5032 stdcall -noname XLiveVerifyArcadeLicense (long long)
5034 stdcall -noname XLiveProtectData(long long long long long)
5035 stdcall -noname XLiveUnprotectData(long long long long long)
5036 stdcall -noname XLiveCreateProtectedDataContext (long long)
5037 stdcall -noname XLiveQueryProtectedDataInformation (long long)
5038 stdcall -noname XLiveCloseProtectedDataContext (long)
5039 stdcall -noname XLiveVerifyDataFile(long)
5206 stdcall -noname XShowMessagesUI (long)
5208 stdcall -noname XShowGameInviteUI(long long long long)
5209 stdcall -noname XShowMessageComposeUI(long long long long)
5210 stdcall -noname XShowFriendRequestUI(long long long)
5212 stdcall -noname XShowCustomPlayerListUI(long long long long long long long long long long long long)
5214 stdcall -noname XShowPlayerReviewUI (long long long)
5215 stdcall -noname XShowGuideUI (long)
5216 stdcall -noname XShowKeyboardUI (long long long long long long long long)
5230 stdcall -noname XLocatorServerAdvertise (long long long long long long long long long long long long long long long)
5231 stdcall -noname XLocatorServerUnAdvertise (long long)
5233 stdcall -noname XLocatorGetServiceProperty (long long long long)
5234 stdcall -noname XLocatorCreateServerEnumerator (long long long long long long long long long long)
5235 stdcall -noname XLocatorCreateServerEnumeratorByIDs (long long long long long long long long)
5236 stdcall -noname XLocatorServiceInitialize(long long)
5237 stdcall -noname XLocatorServiceUnInitialize (long)
5238 stdcall -noname XLocatorCreateKey(long long)
5250 stdcall -noname XShowAchievementsUI(long)
5251 stdcall -noname XCloseHandle(long)
5252 stdcall -noname XShowGamerCardUI(long long long)
5254 stdcall -noname XLiveCancelOverlapped(long)
5255 stdcall -noname XEnumerateBack(long long long long long)
5256 stdcall -noname XEnumerate(long long long long long)
5257 stdcall -noname XLiveManageCredentials (long long long long)
5258 stdcall -noname XLiveSignout(long)
5259 stdcall -noname XLiveSignin(long long long long)
5260 stdcall -noname XShowSigninUI(long long)
5261 stdcall -noname XUserGetXUID(long long)
5262 stdcall -noname XUserGetSigninState(long)
5263 stdcall -noname XUserGetName(long long long)
5264 stdcall -noname XUserAreUsersFriends (long long long long long)
5265 stdcall -noname XLiveUserCheckPrivilege(long long long)
5266 stdcall -noname XShowMessageBoxUI(long long long long long long long long long)
5267 stdcall -noname XUserGetSigninInfo(long long long)
5270 stdcall -noname XNotifyCreateListener(long long)
5271 stdcall -noname XShowPlayersUI(long)
5273 stdcall -noname XUserReadGamerpictureByKey (long long long long long long)
5274 stdcall -noname XUserAwardGamerPicture (long long long long)
5275 stdcall -noname XShowFriendsUI (long)
5276 stdcall -noname XUserSetProperty(long long long long)
5277 stdcall -noname XUserSetContext(long long long)
5278 stdcall -noname XUserWriteAchievements(long long long)
5279 stdcall -noname XUserReadAchievementPicture(long long long long long long long)
5280 stdcall -noname XUserCreateAchievementEnumerator(long long long long long long long long long)
5281 stdcall -noname XUserReadStats(long long long long long long long long)
5282 stdcall -noname XUserReadGamerPicture (long long long long long long)
5284 stdcall -noname XUserCreateStatsEnumeratorByRank (long long long long long long long)
5285 stdcall -noname XUserCreateStatsEnumeratorByRating(long long long long long long long long)
5286 stdcall -noname XUserCreateStatsEnumeratorByXuid (long long long long long long long long)
5287 stdcall -noname XUserResetStatsView(long long long)
5288 stdcall -noname XUserGetProperty(long long long long)
5289 stdcall -noname XUserGetContext(long long long)
5290 stdcall -noname XUserGetReputationStars(long)
5291 stdcall -noname XUserResetStatsViewAllUsers(long long)
5292 stdcall -noname XUserSetContextEx (long long long long)
5293 stdcall -noname XUserSetPropertyEx(long long long long long)
5294 stdcall -noname XLivePBufferGetByteArray(long long long long)
5295 stdcall -noname XLivePBufferSetByteArray(long long long long)
5296 stdcall -noname XLiveGetLocalOnlinePort(long)
5297 stdcall -noname XLiveInitializeEx(long long)
5298 stdcall -noname XLiveGetGuideKey(long)
5299 stdcall -noname XShowGuideKeyRemapUI(long)
5300 stdcall -noname XSessionCreate(long long long long long long long long)
5303 stdcall -noname XStringVerify (long long long long long long long)
5304 stdcall -noname XStorageUploadFromMemoryGetProgress(long long long long)
5305 stdcall -noname XStorageUploadFromMemory (long long long long long)
5306 stdcall -noname XStorageEnumerate (long long long long long long long)
5307 stdcall -noname XStorageDownloadToMemoryGetProgress(long long long long)
5308 stdcall -noname XStorageDelete(long long long)
5309 stdcall -noname XStorageBuildServerPathByXuid(long long long long long long long long)
5310 stdcall -noname XOnlineStartup()
5311 stdcall -noname XOnlineCleanup()
5312 stdcall -noname XFriendsCreateEnumerator (long long long long long)
5313 stdcall -noname XPresenceInitialize(long)
5314 stdcall -noname XUserMuteListQuery (long long long long)
5315 stdcall -noname XInviteGetAcceptedInfo (long long)
5316 stdcall -noname XInviteSend (long long long long long)
5317 stdcall -noname XSessionWriteStats (long long long long long long)
5318 stdcall -noname XSessionStart (long long long)
5319 stdcall -noname XSessionSearchEx (long long long long long long long long long long long)
5320 stdcall -noname XSessionSearchByID(long long long long long long)                                         
5321 stdcall -noname XSessionSearch(long long long long long long long long long long)
5322 stdcall -noname XSessionModify (long long long long long)
5323 stdcall -noname XSessionMigrateHost (long long long long)
5324 stdcall -noname XOnlineGetNatType()
5325 stdcall -noname XSessionLeaveLocal (long long long long)
5326 stdcall -noname XSessionJoinRemote(long long long long long)
5327 stdcall -noname XSessionJoinLocal (long long long long long)
5328 stdcall -noname XSessionGetDetails (long long long long)
5329 stdcall -noname XSessionFlushStats (long long)
5330 stdcall -noname XSessionDelete (long long)
5331 stdcall -noname XUserReadProfileSettings(long long long long long long long)
5332 stdcall -noname XSessionEnd (long long)
5333 stdcall -noname XSessionArbitrationRegister (long long long long long long long)
5334 stdcall -noname XOnlineGetServiceInfo(long long)
5335 stdcall -noname XTitleServerCreateEnumerator (long long long long)
5336 stdcall -noname XSessionLeaveRemote (long long long long)
5337 stdcall -noname XUserWriteProfileSettings(long long long long)
5338 stdcall -noname XPresenceSubscribe(long long long)
5339 stdcall -noname XUserReadProfileSettingsByXuid(long long long long long long long long long)
5340 stdcall -noname XPresenceCreateEnumerator(long long long long long long long)
5341 stdcall -noname XPresenceUnsubscribe(long long long)
5342 stdcall -noname XSessionModifySkill(long long long long)
5343 stdcall -noname XLiveCalculateSkill (long long long long long)
5344 stdcall -noname XStorageBuildServerPath (long long long long long long long)
5345 stdcall -noname XStorageDownloadToMemory (long long long long long long long)
5346 stdcall -noname XUserEstimateRankForRating(long long long long long)
5347 stdcall -noname XLiveProtectedLoadLibrary(long long long long long)
5348 stdcall -noname XLiveProtectedCreateFile(long long long long long long long long long)
5349 stdcall -noname XLiveProtectedVerifyFile (long long long)
5350 stdcall -noname XLiveContentCreateAccessHandle(long long long long long long)
5351 stdcall -noname XLiveContentInstallPackage(long long long)
5352 stdcall -noname XLiveContentUninstall (long long long)
5354 stdcall -noname XLiveContentVerifyInstalledPackage(long long)
5355 stdcall -noname XLiveContentGetPath(long long long long)
5356 stdcall -noname XLiveContentGetDisplayName(long long long long)
5357 stdcall -noname XLiveContentGetThumbnail(long long long long)
5358 stdcall -noname XLiveContentInstallLicense(long long long)
5359 stdcall -noname XLiveGetUPnPState(long)
5360 stdcall -noname XLiveContentCreateEnumerator(long long long long)
5361 stdcall -noname XLiveContentRetrieveOffersByDate (long long long long long long)
5365 stdcall -noname XShowMarketplaceUI (long long long long)
5372 stdcall -noname XLIVE_5372(long long long long long long)
