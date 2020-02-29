ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    provides sensors, get_all_temps
    shares __testing, sensors, get_all_temps
  }
  
  global {
    
    rulesets_to_install = [ "temperature_store", "wovyn_base", "sensor_profile", 
                            "cs462_keys", "twilio_lab" ]
    default_threshold = 80
    default_number = "19199739210"
    
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "sensors"},
        { "name": "get_all_temps"}
      ] , "events":
      [ { "domain": "sensor", "type": "new_sensor", "attrs": [ "sensor_name" ] },
        { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "sensor_name" ] }
      ]
    }
    
    sensors = function() {
      ent:sensor_map.defaultsTo({})
    }
    
    get_all_temps = function() {
      ent:sensor_map.map(function(eci){
        wrangler:skyQuery(eci,"temperature_store","temperatures", [])
      })
    }
  }
  
  rule new_sensor {
    select when sensor new_sensor
    pre{
      sensor_name = event:attr("sensor_name").klog("name of new sensor to create is ")
      exists = ent:sensor_map >< sensor_name
      eci = meta:eci.klog("meta eci is ")
    }
    if exists then 
      send_directive("sensor", {"new_sensor": "Sensor already exists"})
    notfired {
      ent:sensor_map{sensor_name} := eci
      raise wrangler event "child_creation"
      attributes {"name": sensor_name,
                  "color": "#ffff00",
                  "rids": rulesets_to_install }
    }
  }
  
  rule store_new_sensor {
    select when wrangler child_initialized
    pre {
      sensor_name = event:attr("name")
      eci = event:attr("eci")
    }
    if sensor_name then
      noop()
    fired {
      ent:sensor_map{sensor_name} := eci
    }
  }
  
  rule update_child_profile {
   select when wrangler new_child_created
     pre {
       sensor_name = event:attr("name")
       eci = event:attr("eci")
     }
     event:send({"eci":eci, 
                 "domain":"sensor", 
                 "type":"profile_updated", 
                 "attrs":{"name": sensor_name, 
                          "threshold": default_threshold, 
                          "phone_number": default_number}})
  }
  
  rule remove_sensor {
    select when sensor unneeded_sensor
    pre{
      sensor_name = event:attr("sensor_name").klog("sensor to delete: ")
      exists = ent:sensor_map >< sensor_name
    }
    if exists then 
      send_directive("delete_sensor", {"deleting sensor": sensor_name})
    fired{
      clear ent:sensor_map{sensor_name}
      raise wrangler event "child_deletion"
        attributes {"name": sensor_name};
    }
  }
}
