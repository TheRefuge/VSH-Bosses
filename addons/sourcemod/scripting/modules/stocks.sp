#define ATTRIB_LESSHEALING				734

stock void Client_AddHealth(int iClient, int iAdditionalHeal, int iMaxOverHeal=0)
{
	int iMaxHealth = SDK_GetMaxHealth(iClient);
	int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	int iTrueMaxHealth = iMaxHealth+iMaxOverHeal;
	
	float flHealingRate = 1.0;
	TF2_FindAttribute(iClient, ATTRIB_LESSHEALING, flHealingRate);
	
	if (iHealth < iTrueMaxHealth)
	{
		iHealth += RoundToNearest(float(iAdditionalHeal) * flHealingRate);
		if (iHealth > iTrueMaxHealth) iHealth = iTrueMaxHealth;
		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	}
}

stock bool IsPointsClear(const float vecPos1[3], const float vecPos2[3])
{
	TR_TraceRayFilter(vecPos1, vecPos2, MASK_PLAYERSOLID, RayType_EndPoint, TraceRay_DontHitPlayersAndObjects);
	return !TR_DidHit();
}

stock bool TraceRay_DontHitEntity(int iEntity, int iMask, int iData)
{
	return iEntity != iData;
}

stock bool TraceRay_DontHitPlayersAndObjects(int iEntity, int iMask, int iData)
{
	if (0 < iEntity <= MaxClients)
		return false;
	
	char sClassname[256];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	return StrContains(sClassname, "obj_") != 0;
}

stock bool TraceRay_HitEnemyPlayersAndObjects(int iEntity, int iMask, int iClient)
{
	if (0 < iEntity <= MaxClients)
		return GetClientTeam(iEntity) != GetClientTeam(iClient);
	
	char sClassname[256];
	GetEntityClassname(iEntity, sClassname, sizeof(sClassname));
	return StrContains(sClassname, "obj_") == 0 && GetEntProp(iEntity, Prop_Send, "m_iTeamNum") != GetClientTeam(iClient);
}

stock bool TF2_CreateEntityGlow(int iEntity, char[] sModel, int iColor[4] = {255, 255, 255, 255})
{
	int iGlow = CreateEntityByName("tf_taunt_prop");
	if (iGlow != -1)
	{
		SetEntityModel(iGlow, sModel);
		
		DispatchSpawn(iGlow);
		ActivateEntity(iGlow);
		
		SetEntityRenderMode(iGlow, RENDER_TRANSCOLOR);
		SetEntityRenderColor(iGlow, 0, 0, 0, 0);
		
		int iGlowManager = TF2_CreateGlow(iGlow, iColor);
		SDK_AlwaysTransmitEntity(iGlow);
		SDK_AlwaysTransmitEntity(iGlowManager);
		
		// Set effect flags.
		int iFlags = GetEntProp(iGlow, Prop_Send, "m_fEffects");
		SetEntProp(iGlow, Prop_Send, "m_fEffects", iFlags | EF_BONEMERGE); // EF_BONEMERGE
		
		SetVariantString("!activator");
		AcceptEntityInput(iGlow, "SetParent", iEntity);
		
		SetEntPropEnt(iGlow, Prop_Send, "m_hOwnerEntity", iGlowManager);
		return true;
	}
	
	return false;
}

stock int TF2_CreateGlow(int iEnt, int iColor[4])
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));

	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);

	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "entity_glow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);

	AcceptEntityInput(ent, "Enable");
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);

	SetVariantColor(iColor);
	AcceptEntityInput(ent, "SetGlowColor");

	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", iEnt);

	return ent;
}

stock bool TF2_FindAttribute(int iEntity, int iAttrib, float &flVal)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iEntity, iAttrib);
	if (addAttrib != Address_Null)
	{
		flVal = TF2Attrib_GetValue(addAttrib);
		return true;
	}
	return false;
}

stock bool TF2_WeaponFindAttribute(int iWeapon, int iAttrib, float &flVal)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iWeapon, iAttrib);
	if (addAttrib == Address_Null)
	{
		int iItemDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iAttributes[16];
		float flAttribValues[16];

		int iMaxAttrib = TF2Attrib_GetStaticAttribs(iItemDefIndex, iAttributes, flAttribValues);
		for (int i = 0; i < iMaxAttrib; i++)
		{
			if (iAttributes[i] == iAttrib)
			{
				flVal = flAttribValues[i];
				return true;
			}
		}
		return false;
	}
	flVal = TF2Attrib_GetValue(addAttrib);
	return true;
}

stock bool TF2_IsUbercharged(int iClient)
{
	return (TF2_IsPlayerInCondition(iClient, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(iClient, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(iClient, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(iClient, TFCond_UberchargedCanteen));
}

stock int TF2_GetItemSlot(int iIndex, TFClassType nClass)
{
	int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, nClass);
	if (iSlot >= 0)
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (nClass)
		{
			case TFClass_Engineer:
			{
				switch (iSlot)
				{
					case 4: iSlot = WeaponSlot_BuilderEngie; // Toolbox
					case 5: iSlot = WeaponSlot_PDABuild; // Construction PDA
					case 6: iSlot = WeaponSlot_PDADestroy; // Destruction PDA
				}
			}
			case TFClass_Spy:
			{
				switch (iSlot)
				{
					case 1: iSlot = WeaponSlot_Primary; // Revolver
					case 4: iSlot = WeaponSlot_Secondary; // Sapper
					case 5: iSlot = WeaponSlot_PDADisguise; // Disguise Kit
					case 6: iSlot = WeaponSlot_InvisWatch; // Invis Watch
				}
			}
		}
	}
	
	return iSlot;
}

stock int TF2_GetItemInSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (!IsValidEdict(iWeapon))
	{
		//If weapon not found in slot, check if it a wearable
		int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
		if (IsValidEdict(iWearable))
			iWeapon = iWearable;
	}
	
	return iWeapon;
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);

	int iWearable = SDK_GetEquippedWearable(client, slot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(client, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
}

stock void TF2_SetAmmo(int iClient, int iSlot, int iAmmo)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (iWeapon > MaxClients)
	{
		int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType > -1)
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
	}
}

stock int TF2_GetBuildingOwner(int iBuilding)
{
	//There is the possibility that a map has buildings without ownership
	return GetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder");
}

stock void TF2_SetBuildingOwner(int iBuilding, int iClient)
{
	if (0 < iClient <= MaxClients && IsClientInGame(iClient))
	{
		SetEntPropEnt(iBuilding, Prop_Send, "m_hBuilder", iClient);
		SDK_AddObject(iClient, iBuilding);
	}
}

stock TFObjectType TF2_GetBuildingType(int iBuilding)
{
	if (iBuilding > MaxClients)
		return view_as<TFObjectType>(GetEntProp(iBuilding, Prop_Send, "m_iObjectType"));
		
	return TFObject_Invalid;
}

stock TFObjectMode TF2_GetBuildingMode(int iBuilding)
{
	if (iBuilding > MaxClients)
		return view_as<TFObjectMode>(GetEntProp(iBuilding, Prop_Send, "m_iObjectMode"));
		
	return TFObjectMode_Invalid;
}

stock void TF2_StunBuilding(int iBuilding, float flDuration)
{
	SetEntProp(iBuilding, Prop_Send, "m_bDisabled", true);
	CreateTimer(flDuration, Timer_EnableBuilding, EntIndexToEntRef(iBuilding));
}

public Action Timer_EnableBuilding(Handle timer, int iRef)
{
	int iBuilding = EntRefToEntIndex(iRef);
	if (iBuilding > MaxClients)
		SetEntProp(iBuilding, Prop_Send, "m_bDisabled", false);
	
	return Plugin_Continue;
}

stock void TF2_SetBuildingTeam(int iBuilding, TFTeam nTeam, int iNewBuilder = -1)
{
	int iBuilder = TF2_GetBuildingOwner(iBuilding);
	
	//Remove the building from the original builder so it doesn't explode on team switch
	SDK_RemoveObject(iBuilder, iBuilding);
	
	//Set its team. If we were attempting to do this by changing its TeamNum ent prop, Sentries would act derpy by actively trying to shoot itself
	int iTeam = view_as<int>(nTeam);
	SetVariantInt(iTeam);
	AcceptEntityInput(iBuilding, "SetTeam");
	SetEntProp(iBuilding, Prop_Send, "m_nSkin", iTeam-2);
	
	//Set a new builder and give them the building, if specified
	TF2_SetBuildingOwner(iBuilding, iNewBuilder);
	
	switch (TF2_GetBuildingType(iBuilding))
	{
		case TFObject_Sentry:
		{
			//Mini-sentries use different skins, adjust accordingly
			if (GetEntProp(iBuilding, Prop_Send, "m_bMiniBuilding"))
				SetEntProp(iBuilding, Prop_Send, "m_nSkin", iTeam);
			
			//Reset wrangler shield and player-controlled status to change team colors
			//If the sentry is still being wrangled, the values will automatically adjust themselves next frame
			if (GetEntProp(iBuilding, Prop_Send, "m_nShieldLevel") > 0)
			{
				SetEntProp(iBuilding, Prop_Send, "m_bPlayerControlled", false);
				SetEntProp(iBuilding, Prop_Send, "m_nShieldLevel", 0);
			}
		}
		case TFObject_Dispenser:
		{
			//Disable the dispenser's screen, it's better than having it not change team color
			int iScreen = MaxClients+1;
			while ((iScreen = FindEntityByClassname(iScreen, "vgui_screen")) > MaxClients)
			{
				if (GetEntPropEnt(iScreen, Prop_Send, "m_hOwnerEntity") == iBuilding)
					AcceptEntityInput(iScreen, "Kill");
			}
		}
		case TFObject_Teleporter:
		{
			//Disable teleporters for a little bit to reset the effects' colors
			TF2_StunBuilding(iBuilding, 0.1);
		}
	}
}

stock void TF2_Explode(int iAttacker = -1, float flPos[3], float flDamage, float flRadius, const char[] strParticle, const char[] strSound)
{
	int iBomb = CreateEntityByName("tf_generic_bomb");
	DispatchKeyValueVector(iBomb, "origin", flPos);
	DispatchKeyValueFloat(iBomb, "damage", flDamage);
	DispatchKeyValueFloat(iBomb, "radius", flRadius);
	DispatchKeyValue(iBomb, "health", "1");
	DispatchKeyValue(iBomb, "explode_particle", strParticle);
	DispatchKeyValue(iBomb, "sound", strSound);
	DispatchSpawn(iBomb);

	if (iAttacker == -1)
		AcceptEntityInput(iBomb, "Detonate");
	else
		SDKHooks_TakeDamage(iBomb, 0, iAttacker, 9999.0);
}

stock void TF2_Shake(float vecOrigin[3], float flAmplitude, float flRadius, float flDuration, float flFrequency)
{
	int iShake = CreateEntityByName("env_shake");
	if (iShake != -1)
	{
		DispatchKeyValueVector(iShake, "origin", vecOrigin);
		DispatchKeyValueFloat(iShake, "amplitude", flAmplitude);
		DispatchKeyValueFloat(iShake, "radius", flRadius);
		DispatchKeyValueFloat(iShake, "duration", flDuration);
		DispatchKeyValueFloat(iShake, "frequency", flFrequency);
		
		DispatchSpawn(iShake);
		AcceptEntityInput(iShake, "StartShake");
		RemoveEntity(iShake);
	}
}

stock int TF2_SpawnParticle(char[] sParticle, float vecOrigin[3] = NULL_VECTOR, float flAngles[3] = NULL_VECTOR, bool bActivate = true, int iEntity = 0, int iControlPoint = 0)
{
	int iParticle = CreateEntityByName("info_particle_system");
	TeleportEntity(iParticle, vecOrigin, flAngles, NULL_VECTOR);
	DispatchKeyValue(iParticle, "effect_name", sParticle);
	DispatchSpawn(iParticle);
	
	if (0 < iEntity && IsValidEntity(iEntity))
	{
		SetVariantString("!activator");
		AcceptEntityInput(iParticle, "SetParent", iEntity);
	}
	
	if (0 < iControlPoint && IsValidEntity(iControlPoint))
	{
		//Array netprop, but really only need element 0 anyway
		SetEntPropEnt(iParticle, Prop_Send, "m_hControlPointEnts", iControlPoint, 0);
		SetEntProp(iParticle, Prop_Send, "m_iControlPointParents", iControlPoint, _, 0);
	}
	
	if (bActivate)
	{
		ActivateEntity(iParticle);
		AcceptEntityInput(iParticle, "Start");
	}
	
	//Return ref of entity
	return EntIndexToEntRef(iParticle);
}

stock void TF2_TeleportSwap(int iClient[2])
{
	float vecOrigin[2][3];
	float vecAngles[2][3];
	float vecVel[2][3];
	
	for (int i = 0; i <= 1; i++)
	{
		//Remove Sniper scope before teleporting, otherwise huge server hang can happen
		if (TF2_IsPlayerInCondition(iClient[i], TFCond_Zoomed)) TF2_RemoveCondition(iClient[i], TFCond_Zoomed);
		if (TF2_IsPlayerInCondition(iClient[i], TFCond_Slowed)) TF2_RemoveCondition(iClient[i], TFCond_Slowed);
		
		//Get its origin, angles and vel
		GetClientAbsOrigin(iClient[i], vecOrigin[i]);
		GetClientAbsAngles(iClient[i], vecAngles[i]);
		GetEntPropVector(iClient[i], Prop_Data, "m_vecVelocity", vecVel[i]);
		
		//Create particle
		CreateTimer(3.0, Timer_EntityCleanup, TF2_SpawnParticle(PARTICLE_GHOST, vecOrigin[i], vecAngles[i]));
	}
	
	for (int i = 0; i <= 1; i++)
	{
		int j = ((i == 1) ? 0 : 1);
		
		TeleportEntity(iClient[j], vecOrigin[i], vecAngles[i], vecVel[i]);
		
		if (GetEntProp(iClient[i], Prop_Send, "m_bDucking") || GetEntProp(iClient[i], Prop_Send, "m_bDucked"))
		{
			SetEntProp(iClient[j], Prop_Send, "m_bDucking", true);
			SetEntProp(iClient[j], Prop_Send, "m_bDucked", true);
			SetEntityFlags(iClient[j], GetEntityFlags(iClient[j])|FL_DUCKING);
		}
	}
}

stock int TF2_CreateLightEntity(float flRadius, int iColor[4], int iBrightness)
{
	int iGlow = CreateEntityByName("light_dynamic");
	if (iGlow != -1)
	{			
		char sLigthColor[60];
		Format(sLigthColor, sizeof(sLigthColor), "%i %i %i", iColor[0], iColor[1], iColor[2]);
		DispatchKeyValue(iGlow, "rendercolor", sLigthColor);
		
		SetVariantFloat(flRadius);
		AcceptEntityInput(iGlow, "spotlight_radius");
		
		SetVariantFloat(flRadius);
		AcceptEntityInput(iGlow, "distance");
		
		SetVariantInt(iBrightness);
		AcceptEntityInput(iGlow, "brightness");
		
		SetVariantInt(1);
		AcceptEntityInput(iGlow, "cone");
		
		DispatchSpawn(iGlow);
		
		ActivateEntity(iGlow);
		AcceptEntityInput(iGlow, "TurnOn");
		SetEntityRenderFx(iGlow, RENDERFX_SOLID_SLOW);
		SetEntityRenderColor(iGlow, iColor[0], iColor[1], iColor[2], iColor[3]);
		
		int iFlags = GetEdictFlags(iGlow);
		if (!(iFlags & FL_EDICT_ALWAYS))
		{
			iFlags |= FL_EDICT_ALWAYS;
			SetEdictFlags(iGlow, iFlags);
		}
	}
	
	return iGlow;
}

stock void TF2_ShowAnnotation(int[] iClients, int iCount, int iTarget, const char[] sMessage, float flDuration = 5.0, const char[] sSound = SOUND_NULL)
{
	//Create an annotation and show it to a specified array of clients
	Event event = CreateEvent("show_annotation");
	event.SetInt("id", iTarget);				//Make its ID match the target, just so it's assigned to something unique
	event.SetInt("follow_entindex", iTarget);
	event.SetFloat("lifetime", flDuration);
	event.SetString("text", sMessage);
	event.SetString("play_sound", sSound);		//If this is missing, it'll try to play a sound with an empty filepath
	
	for (int i = 0; i < iCount; i++)
	{
		//No point in showing the annotation to the target
		if (iClients[i] != iTarget)
			event.FireToClient(iClients[i]);
	}
	
	event.Cancel();
}

stock int CreateViewModel(int iClient, int iModel)
{
	int iViewModel = CreateEntityByName("tf_wearable_vm");
	if (iViewModel <= MaxClients)
		return -1;
	
	SetEntProp(iViewModel, Prop_Send, "m_nModelIndex", iModel);
	SetEntProp(iViewModel, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(iViewModel, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntProp(iViewModel, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(iViewModel, Prop_Send, "m_CollisionGroup", 11);
	
	DispatchSpawn(iViewModel);
	SetVariantString("!activator");
	ActivateEntity(iViewModel);
	
	SDK_EquipWearable(iClient, iViewModel);
	return iViewModel;
}

stock bool StrEmpty(char[] sBuffer)
{
	return sBuffer[0] == '\0';
}

stock void PrepareSound(const char[] sSoundPath)
{
	PrecacheSound(sSoundPath, true);
	char s[PLATFORM_MAX_PATH];
	Format(s, sizeof(s), "sound/%s", sSoundPath);
	AddFileToDownloadsTable(s);
}

stock int PrecacheParticleSystem(const char[] particleSystem)
{
	static int particleEffectNames = INVALID_STRING_TABLE;
	if (particleEffectNames == INVALID_STRING_TABLE)
	{
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
		{
			return INVALID_STRING_INDEX;
		}
	}

	int index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX)
	{
		int numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames))
		{
			return INVALID_STRING_INDEX;
		}

		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}

	return index;
}

stock int FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];
	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i = 0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));
		if (StrEqual(buf, str))
		{
			return i;
		}
	}

	return INVALID_STRING_INDEX;
}

stock bool IsClientInRange(int iClient, float vecOrigin[3], float flRadius)
{
	float vecClientOrigin[3];
	GetClientAbsOrigin(iClient, vecClientOrigin);
	return GetVectorDistance(vecOrigin, vecClientOrigin) <= flRadius;
}

stock void CreateFade(int iClient, int iDuration = 2000, int iRed = 255, int iGreen = 255, int iBlue = 255, int iAlpha = 255)
{
	BfWrite bf = UserMessageToBfWrite(StartMessageOne("Fade", iClient));
	bf.WriteShort(iDuration);	//Fade duration
	bf.WriteShort(0);
	bf.WriteShort(0x0001);
	bf.WriteByte(iRed);			//Red
	bf.WriteByte(iGreen);		//Green
	bf.WriteByte(iBlue);		//Blue
	bf.WriteByte(iAlpha);		//Alpha
	EndMessage();
}