--<<Auto Armlet Toggle by Sophylax, reworked and updated by Moones v1.4>>
require("libs.Utils")
require("libs.ScriptConfig")
require("libs.Animations")
require("libs.HeroInfo")

--[[
 0 1 0 1 0 0 1 1    
 0 1 1 0 1 1 1 1        ____          __        __         
 0 1 1 1 0 0 0 0       / __/__  ___  / /  __ __/ /__ ___ __
 0 1 1 0 1 0 0 0      _\ \/ _ \/ _ \/ _ \/ // / / _ `/\ \ /
 0 1 1 1 1 0 0 1     /___/\___/ .__/_//_/\_, /_/\_,_//_\_\ 
 0 1 1 0 1 1 0 0             /_/        /___/             
 0 1 1 0 0 0 0 1    
 0 1 1 1 1 0 0 0 

			Auto Armlet Toggle  v1.4

		This script uses armlet to gain hp when your hero is below a specified health.

		Changelog:
			v1.4:
			 - Added calculation of incoming damage (projectiles, abilities, attacking heroes)
			 - MinimumHP is now considered only when there is no incoming damage and there are enemy heroes near
			 
			v1.3:
				Added Auto toggle on when ranged hero shoots on you or any hero is in melee range of you.
				
			v1.2:
			 - Reworked for new version
			 
			v1.1:
			 - Tweaked script for the new armlet mechanics again
			 - Removed the configurable armlet delay

			v1.0c:
			 - Tweaked script for the new armlet mechanics
			 - Added key for manual armlet toggling

			v1.0b:
			 - Script now checks armlet cooldown even if it is activated by the user

			v1.0a:
			 - Script now disables itself if the user is under Ice Blast effect
			 - Lowered menu Width

			v1.0:
			 - Release

]]


local config = ScriptConfig.new()
config:SetParameter("Hotkey", "L", config.TYPE_HOTKEY)
config:SetParameter("MinimumHP", 200)
config:SetParameter("ToggleAlways", false)
config:Load()

hotkey = config.Hotkey
minhp = config.MinimumHP

local xx,yy = 10,client.screenSize.y/25.714
local reg = nil
local F14 = drawMgr:CreateFont("f14","Tahoma",14,550)
local statusText = drawMgr:CreateText(xx,yy,-1,"Auto armlet toggle: Off",F14)
local incoming_projectiles = {} local incoming_damage = 0 local toggle = false

ARMLET_DELAY = 1000

extraToggle = 0

function Key(msg,code)
    if msg ~= KEY_UP or code ~= hotkey or client.chat then return end
	if not active then
		active = true
		statusText.text = "Auto armlet toggle: On"
		return true
	else
		active = nil
		statusText.text = "Auto armlet toggle: Off"
		return true
	end

end

function Tick( tick )
	if not PlayingGame() or client.console or client.paused then return end
	local me = entityList:GetMyHero() 
	if not reg then
		script:RegisterEvent(EVENT_KEY,Key)
		reg = true
		incoming_projectiles = {} 
		incoming_damage = 0
	end
	
	local armlet = me:FindItem("item_armlet")
	if not armlet or me:IsStunned() or not armlet:CanBeCasted() or not active then incoming_damage = 0 incoming_projectiles = {} toggle = false return end
	
	local armState = me:DoesHaveModifier("modifier_item_armlet_unholy_strength")
	local enemies = entityList:GetEntities({type=LuaEntity.TYPE_HERO,alive=true,visible=true,team=me:GetEnemyTeam()})
	if not me.alive then
		incoming_damage = 0
		incoming_projectiles = {}
		toggle = false
		return
	end
	
	if armState and me:DoesHaveModifier("modifier_ice_blast") and SleepCheck() then
		me:SafeCastItem("item_armlet")
		Sleep(ARMLET_DELAY)
	end
	
	if config.ToggleAlways and SleepCheck() and (toggle or (#enemies <= 0 and me.health < minhp and (me.health - incoming_damage) > 0)) then
		if armState then
			me:SafeCastItem("item_armlet")
			me:SafeCastItem("item_armlet")
			Sleep(ARMLET_DELAY)
		else
			me:SafeCastItem("item_armlet")
			Sleep(ARMLET_DELAY)
		end
		toggle = false
	end
	
	for i,v in ipairs(enemies) do			
		if not v:IsIllusion() and not me:DoesHaveModifier("modifier_ice_blast") then
			local projectile = entityList:GetProjectiles({target=me})
			local distance = GetDistance2D(v,me)
			if armState and SleepCheck() then							
				if #projectile > 0 then
					for k,z in ipairs(projectile) do
						if z.target and z.target == me and z.source then
							local spell = z.source:FindSpell(z.name) 
							if spell then
								local dmg = spell:GetDamage(spell.level)
								if dmg <= 0 then dmg = spell:GetSpecialData("damage",spell.level) end
								if not incoming_projectiles[spell.handle] then
									incoming_projectiles[spell.handle] = {damage = dmg, time = client.gameTime + ((GetDistance2D(me,z.position)-50)/z.speed)}
									incoming_damage = incoming_damage + dmg
								elseif client.gameTime > incoming_projectiles[spell.handle].time then
									incoming_damage = incoming_damage - dmg
									incoming_projectiles[spell.handle] = nil
								end	
								if (me.health+((-40+me.healthRegen)*(GetDistance2D(me,z.position)/z.speed))) < dmg then
									me:SafeCastItem("item_armlet")
									me:SafeCastItem("item_armlet")
									Sleep(ARMLET_DELAY)
								end
							else
								if not incoming_projectiles[z.source.handle] then																	
									incoming_projectiles[z.source.handle] = {damage = (((z.source.dmgMax + z.source.dmgMin)/2)*((1-me.dmgResist)+1) + z.source.dmgBonus), time = client.gameTime + ((GetDistance2D(me,z.position)-50)/z.speed)}
									incoming_damage = incoming_damage + (((z.source.dmgMax + z.source.dmgMin)/2)*((1-me.dmgResist)) + z.source.dmgBonus)
								elseif client.gameTime > incoming_projectiles[z.source.handle].time then
									incoming_damage = incoming_damage - (((z.source.dmgMax + z.source.dmgMin)/2)*((1-me.dmgResist)) + z.source.dmgBonus)
									incoming_projectiles[z.source.handle] = nil
								end	
								if (me.health+((-40+me.healthRegen)*(GetDistance2D(me,z.position)/z.speed))) < (((z.source.dmgMax + z.source.dmgMin)/2)*((1-me.dmgResist)+1) + z.source.dmgBonus) then
									me:SafeCastItem("item_armlet")
									me:SafeCastItem("item_armlet")
									Sleep(ARMLET_DELAY)
								end
							end
						end
					end
				else
					incoming_damage = 0
					incoming_projectiles = {}
				end
				for i,z in ipairs(v.abilities) do
					if z.abilityPhase and distance <= z.castRange and (math.max(math.abs(FindAngleR(v) - math.rad(FindAngleBetween(v, me))) - 0.20, 0)) == 0 then
						local spell = z
						if spell then
							local dmg = spell:GetDamage(spell.level)
							if dmg <= 0 then dmg = spell:GetSpecialData("damage",spell.level) end
							if not dmg then dmg = 0 end
							if me.health+((-40+me.healthRegen)*(z:FindCastPoint()-client.latency/1000)) < dmg then
								me:SafeCastItem("item_armlet")
								me:SafeCastItem("item_armlet")
								Sleep(ARMLET_DELAY)
							end
						end
					end 
				end	
				if distance <= (v.attackRange+100) and Animations.isAttacking(v) and (math.max(math.abs(FindAngleR(v) - math.rad(FindAngleBetween(v, me))) - 0.20, 0)) == 0 then
					if (heroInfo[v.name] and heroInfo[v.name].projectileSpeed and (me.health+((-40+me.healthRegen)*(Animations.GetAttackTime(v) + distance/heroInfo[v.name].projectileSpeed)) < (((v.dmgMax + v.dmgMin)/2)*((1-me.dmgResist)+1))))
					or (me.health+((-40+me.healthRegen)*(Animations.GetAttackTime(v))) < (((v.dmgMax + v.dmgMin)/2)*((1-me.dmgResist)+1)))
					then
						me:SafeCastItem("item_armlet")
						me:SafeCastItem("item_armlet")
						Sleep(ARMLET_DELAY)
					end
				elseif me.health < minhp and (me.health - incoming_damage) > 0 then
					if distance < 900 then
						me:SafeCastItem("item_armlet")
						me:SafeCastItem("item_armlet")
						Sleep(ARMLET_DELAY)
					else
						toggle = true
					end
				end
			end
			if not armState and SleepCheck() then
				for i,z in ipairs(v.abilities) do
					if z.abilityPhase and distance <= z.castRange and (math.max(math.abs(FindAngleR(v) - math.rad(FindAngleBetween(v, me))) - 0.20, 0)) == 0 then
						me:SafeCastItem("item_armlet")
						Sleep(ARMLET_DELAY)
					end
				end	
				if projectile then
					for k,z in ipairs(projectile) do
						if z.target and z.target == me and armlet.toggled == false then
							me:SafeCastItem("item_armlet")
							Sleep(ARMLET_DELAY)
						end
					end
				end
				if distance <= (200) or (Animations.isAttacking(v) and (math.max(math.abs(FindAngleR(v) - math.rad(FindAngleBetween(v, me))) - 0.20, 0)) == 0) then
					if armlet.toggled == false then
						me:SafeCastItem("item_armlet")
						Sleep(ARMLET_DELAY)
					end
				end
			end
		end
	end
end

script:RegisterEvent(EVENT_FRAME,Tick)
