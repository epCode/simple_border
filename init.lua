local yes = true -- lol

simple_border = {
  hud = {}
}

-- how long the border lasts till final size
local GAMESECONDS = 1000
local START_SIZE = 30 -- radius
local FINAL_SIZE = 1 -- radius

START_SIZE = START_SIZE-FINAL_SIZE

local function get_border_radius(seconds)
  local gtime = core.get_gametime()
  if seconds then return math.max(0, GAMESECONDS-gtime) end
  local current_border_radius = (START_SIZE-(gtime/GAMESECONDS*START_SIZE))+FINAL_SIZE
  
  current_border_radius = math.max(current_border_radius, FINAL_SIZE)
  return current_border_radius
end

local function in_border(pos)
  local current_border_radius = get_border_radius()

  if math.abs(pos.x) > current_border_radius or math.abs(pos.z) > current_border_radius then
    return true
  end
end

local function distance_from_border(pos, raw)
  local cb = get_border_radius()
  
  return {
    x=math.abs(pos.x-cb),
    z=math.abs(pos.z-cb),
    nx=math.abs(pos.x - -cb),
    nz=math.abs(pos.z - -cb),
  }
end

function simple_border.set_hud(player)
  local chud = simple_border.hud[player]
  
  if chud then
    for _,hudid in pairs(chud) do
      player:hud_remove(hudid)
    end
    simple_border.hud[player] = nil
  end
  simple_border.hud[player] = {
    player:hud_add({
      type = "text",
      text = math.floor(get_border_radius()),
      position = {x = 1, y = 0.1},
      scale = {x = 101, y = 101},
      size = {x=3, y=3},
      number = 0xff5555,
      offset = {x = -200, y = 0},
      z_index = 1001,
    }),
    player:hud_add({
      type = "text",
      text = math.floor(get_border_radius(yes)).."s",
      position = {x = 1, y = 0.1},
      scale = {x = 101, y = 101},
      size = {x=2, y=2},
      number = 0x55ff55,
      offset = {x = -200, y = 35},
      z_index = 1001,
    }),
  }
end

local timer = 0.5
local supertimer = 1
local oposite_vec = {x="z",z="x",nx="z",nz="x"}

core.register_craftitem("simple_border:no_reach",{
  range = 0,
})

local function set_spectator(player)
  core.hud_replace_builtin("name", {})
  core.hud_replace_builtin("breath", {})
  core.hud_replace_builtin("health", {})
  core.hud_replace_builtin("hotbar", {})
  player:set_lighting({
    saturation = 1,
    exposure = 1,
  })
  player:set_inventory_formspec("")
  player:get_armor_groups({fleshy=0})
  if core.get_modpath("mcl_gamemode") then
    playerphysics.add_physics_factor(player, "acceleration_default", "simple_border:acc_def", 0.3)
    playerphysics.add_physics_factor(player, "acceleration_air", "simple_border:acc_air", 0.3)
    playerphysics.add_physics_factor(player, "acceleration_fast", "simple_border:acc_fast", 0.3)
    player:get_meta():set_string("gamemode", "creative") -- very hacky
    local name = player:get_player_name()
    if hb.hudtables then
      for identifier,thing in pairs(hb.hudtables) do
        local id = hb.hudtables[identifier].hudids[name]
        if id then
          --print(core.serialize(id))
          player:hud_remove(id.bar)
        end
      end
    end
  else
    player:set_physics_override({
      acceleration_default = 0.3,
      acceleration_air = 0.3,
      acceleration_fast = 0.3,
    })
  end
  player:hud_set_hotbar_itemcount(1)
  player:set_wielded_item("simple_border:no_reach")
  player:set_properties({textures = {"blank.png"}, visual_size = vector.zero(), collisionbox = {-0.02, -0.02, -0.02, 0.02, 0.02, 0.02}, eye_height = 0.1})
  
  player:hud_set_flags({
    hotbar = false,
    healthbar = false,
    crosshair = false,
    wielditem = false,
    breathbar = false,
  })
end

local players_out_of_bounds = {}

core.register_globalstep(function(dtime)
  timer = timer - dtime
  supertimer = supertimer - dtime
  if supertimer < 0 then
    supertimer = 60
    --core.chat_send_all(core.colorize("#f22", "The border radius is now "..math.floor(get_border_radius()).."!!"))
  end
  
  if timer > 0 then return end
  timer = 0.5
  
  local gtime = core.get_gametime()
  for _,player in pairs(core.get_connected_players(true)) do
    set_spectator(player)
  end
  for _,player in pairs(core.get_connected_players()) do 

    local pos = player:get_pos()

  
    local distv = distance_from_border(pos)
    
    
    local distancefromnearestborder = math.min(distv.x, distv.z, distv.nz, distv.nx)
    if in_border(pos) then
      if not players_out_of_bounds[player] then
        players_out_of_bounds[player] = true
        core.sound_play("outofbounds", {to_player=player:get_player_name()}, true)
      end
      distancefromnearestborder = 0
    elseif players_out_of_bounds[player] then
      players_out_of_bounds[player] = nil
    end
    player:set_lighting({
      saturation = math.min(1, distancefromnearestborder/5),
      exposure = math.min(1, distancefromnearestborder/5),
    })
    
    
    
    local br = get_border_radius(seconds)
    
    if not br then return end
    
    for vec,dist in pairs(distv) do
      if dist < 30 then
        
        local real_vec = vec:gsub("n", "")
        
        local vecn = string.find(vec, "n")
        if vecn then vecn = -1 else vecn = 1 end
        
        local particle_wall_size = dist*2+10
        local multi = 3
        local pbpos = table.copy(pos)
        pbpos[real_vec] = br*vecn
        pbpos[oposite_vec[vec]] = math.max(-br, math.min(br, pbpos[oposite_vec[vec]] + particle_wall_size))
        pbpos.y = pbpos.y - particle_wall_size
        local pbpos2 = table.copy(pbpos)
        pbpos2[oposite_vec[vec]] = math.max(-br, math.min(br, pbpos2[oposite_vec[vec]] - particle_wall_size*2))
        pbpos2.y = pbpos2.y + particle_wall_size*2
        
        
        core.add_particlespawner({
          amount = 400,
          time = 0.5,
          minpos = pbpos2,
          maxpos = pbpos,
          minvel = {x=-0.2, y=-0.2, z=-0.2},
          maxvel = {x=0.2, y=0.2, z=0.2},
          minacc = {x=0, y=0, z=0},
          maxacc = {x=0, y=0, z=0},
          minexptime = 0.3,
          maxexptime = 1,
          minsize = 1,
          maxsize = 3,
          vertical = false,
          glow = 3,
          texture = "simple_border_x.png",
        })
      end
    end
    
    simple_border.set_hud(player)

    local spectator = core.get_player_privs(player:get_player_name()).spectator

    if in_border(pos) and not spectator then
      player:add_velocity(vector.multiply(vector.direction(pos, vector.new(0,pos.y+10,0)), 5))
      player:set_hp(player:get_hp()-1)
      return
    end
    -- if we aren't in the border..

  end
end)

core.register_privilege("spectator", {
    description = "Makes the player a spectator.",
    give_to_singleplayer = false,
    give_to_admin = false,
})

local original_func = core.get_connected_players

function core.get_connected_players(spectators)
  local new_list = {}
  local original_return = original_func()
  for _,player in pairs(original_return) do
    local spec = core.get_player_privs(player:get_player_name()).spectator
    if spectators and spec then
      table.insert(new_list, player)
    elseif not spectators and not spec then
      table.insert(new_list, player)
    end
  end
  return new_list
end

core.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
  if core.get_player_privs(player:get_player_name()).spectator then
    return true
  end
end)

core.register_on_joinplayer(function(player)
  if core.get_player_privs(player:get_player_name()).spectator then
    set_spectator(player)
  end
end)

local place_of_death = {}

core.register_on_dieplayer(function(player, reason)
  place_of_death[player] = player:get_pos()
  core.set_player_privs(player:get_player_name(), {fly=true,fast=true,noclip=true,spectator=true})
  set_spectator(player)
end)

core.register_on_respawnplayer(function(player)
  if place_of_death[player] then
    player:set_pos(place_of_death[player])
  end
end)