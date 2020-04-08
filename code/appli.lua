-- global variables
amb_temp_cur=0
amb_humi_cur=0
amb_volt_cur=0
amb_light_cur=0

-- connects to mqtt_srv_ip:mqtt_srv_port
mqtt_srv_port=mqtt_srv_port or 1883
amb_mqtt_topic=amb_mqtt_topic or "/ambient"
amb_mqtt_id=amb_mqtt_id or node.chipid()
amb_node_room=amb_node_room or "home"
amb_node_alias=amb_node_alias or amb_mqtt_id

-- timer triggers every 10s
amb_timer_int=amb_timer_int or 10000

-- publication cache
local cache_node_room, cache_node_alias, cache_temp_cur, cache_humi_cur, cache_volt_cur, cache_light_cur

local pub_timer
local amb_mqtt_state=0
local amb_mqtt
local conn_states={"DIS", "CON", "EST"}

local function amb_read_temp()
  local status, temp, humi
  local retry

  if brd_dht then
    for retry = 1,20 do
      status,temp,humi=dht.readxx(brd_dht)
      if status == dht.OK and temp >= -40 and temp <= 80 then
        amb_temp_cur=temp
        amb_humi_cur=humi
	break
      end
    end
  end
end

local function amb_read_ldr()
  if brd_ldr then
    amb_light_cur = 1 - gpio.read(brd_ldr)
  end
end

local function mqtt_connect_cb(s)
  if led then led(0) end
  amb_mqtt_state=2
  --note: also called on errors, must check s for errors first
  s:subscribe({
    [amb_mqtt_topic .. "/env/+"]=0,
    [amb_mqtt_topic .. "/cmd/" .. amb_mqtt_id .. "/+"]=0},
    nil)
  s:publish(amb_mqtt_topic .. "/sts/" .. amb_mqtt_id .. "/online", "1", 0, 1)
end

local function amb_mqtt_reconnect()
  if mqtt_srv_ip == nil then amb_mqtt_state = 0 return end
  if amb_mqtt_state > 0 then return end
  if amb_mqtt:connect(mqtt_srv_ip, mqtt_srv_port, false, mqtt_connect_cb, mqtt_fail_cb) then
    amb_mqtt_state = 1
    if led then led(1) end
  end
end

local function amb_pub(t,v)
  if amb_mqtt == nil then return nil end
  if amb_mqtt_state == 0 then amb_mqtt_reconnect() end
  if amb_mqtt_state < 2 then return nil end
  amb_mqtt:publish(amb_mqtt_topic .. "/sts/" .. amb_mqtt_id .. t, v, 0, 1)
  return v
end

local function mqtt_fail_cb(s,r)
  amb_mqtt_state=0
  if led then led(0) end
end

local function mqtt_disconnect_cb(s)
  amb_mqtt_state=0
  if led then led(0) end
end

-- receive commands from MQTT
local function mqtt_message_cb(s,t,v)
  local pfxlen=string.len(amb_mqtt_topic)+string.len(amb_mqtt_id)+6
  local name=t:sub(pfxlen+1)

  --print("topic " .. t .. " value " .. v)
  if t == amb_mqtt_topic .. "/env/state" then amb_env_state=v end
  if t == amb_mqtt_topic .. "/env/moment" then amb_env_moment=v end

  if t:sub(1,pfxlen) ~= amb_mqtt_topic .. "/cmd/" .. amb_mqtt_id .. "/" then return end
  if v == nil then return end

  if     name == "time_offset"     then     time_offset=tonumber(v)
  end
end

function ambient_release()
  if pub_timer then pub_timer:unregister() end
  pub_timer=nil
  if amb_mqtt then amb_mqtt:close() end
  amb_mqtt=nil
end

amb_mqtt=mqtt.Client((amb_mqtt_idpfx or "") .. amb_mqtt_id, 10, nil, nil)
amb_mqtt:lwt(amb_mqtt_topic .. "/sts/" .. amb_mqtt_id .. "/online", "", 0, 1)
amb_mqtt:on("message", mqtt_message_cb)
amb_mqtt:on("offline", mqtt_disconnect_cb)

amb_mqtt_reconnect()

pub_timer=tmr.create()
pub_timer:alarm(amb_timer_int,tmr.ALARM_SEMI,function()
  amb_read_temp()
  amb_read_ldr()
  if adc_mv then amb_volt_cur=adc_mv()/1000 end
  
  if disp then disp:clearBuffer() end

  if disp then
    local t = time_now()
    draw_7seg_str(0,0,string.format("%02d:%02d",t["hour"],t["min"]))
    draw_7seg_str(0,28,string.format("%2.1f°", amb_temp_cur))
    disp:drawStr(0,56,string.format("hum: %2.1f%%", amb_humi_cur))
    if adc_mv then disp:drawStr(0,65,string.format("bat: %1.2fV", amb_volt_cur)) end
    disp:drawStr(0,74,string.format("light: %s", tostring(amb_light_cur)))
    disp:drawStr(0,83,string.format("mqtt: %s", tostring(conn_states[amb_mqtt_state+1])))
    disp:drawStr(0,92,string.format("room: %s", tostring(amb_node_room)))
    disp:drawStr(0,101,string.format("name: %s", tostring(amb_node_alias)))
    disp:drawStr(0,110,string.format("mo: %s", tostring(amb_env_moment)))
    disp:drawStr(0,119,string.format("st: %s", tostring(amb_env_state)))
  end

  if disp then disp:sendBuffer() end

  if cache_temp_cur ~= amb_temp_cur then cache_temp_cur = amb_pub("/temp_cur", amb_temp_cur) end
  if cache_humi_cur ~= amb_humi_cur then cache_humi_cur = amb_pub("/humi_cur", amb_humi_cur) end
  if cache_volt_cur ~= amb_volt_cur then cache_volt_cur = amb_pub("/volt_cur", amb_volt_cur) end
  if cache_light_cur ~= amb_light_cur then cache_light_cur = amb_pub("/light_state", amb_light_cur) end
  if cache_node_room ~= amb_node_room then cache_node_room = amb_pub("/room", amb_node_room) end
  if cache_node_alias ~= amb_node_alias then cache_node_alias = amb_pub("/alias", amb_node_alias) end
  pub_timer:start()
end)
