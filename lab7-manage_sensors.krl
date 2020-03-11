ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    provides sensors, get_all_temps, get_default_number
    shares __testing, sensors, get_all_temps, get_default_number
  }
  
  global {
    
    rulesets_to_install = ["temperature_store", "wovyn_base", "sensor_profile"]
    default_threshold = 80
    default_number = "19199739210"
    
    get_default_number = function(){
      default_number
    }
    
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "sensors"},
        { "name": "get_all_temps"}
      ] , "events":
      [ { "domain": "sensor", "type": "clear_map" },
        { "domain": "sensor", "type": "new_sensor", "attrs": [ "sensor_name" ] },
        { "domain": "sensor", "type": "unneeded_sensor", "attrs": [ "sensor_name" ] },
        { "domain": "sensor", "type": "introduce", "attrs": [ "name", "Tx", "Tx_host" ] }
      ]
    }
    
    sensors = function() {
      ent:sensor_map.defaultsTo({})
    }
    
    get_sub_sensors = function() {
      subscription:established("Tx_role","sensor")
    }
    
    get_all_temps = function() {
     get_sub_sensors().map(function(info) {
      eci = info["Tx"];
      host = info["Tx_host"];
      url = host + "/sky/cloud/" + eci + "/temperature_store/temperatures";
      response = http:get(url,{});
      answer = response{"content"}.decode();
      return answer
     })
    }
    
    get_tx_from_sensor_name = function(sensor_name) {
      get_sub_sensors()
          .filter(function(sensor) {ent:sensor_map{sensor{"Tx"}} == sensor_name})
          .head(){"Tx"}
    }

  }
  
  rule new_sensor {
    select when sensor new_sensor
    pre{
      sensor_name = event:attr("sensor_name").defaultsTo("no_name").klog("name of new sensor to create is ")
      exists = ent:sensor_map.values() >< sensor_name
      eci = meta:eci.klog("meta eci is ")
    }
    if exists then 
      send_directive("sensor", {"new_sensor": "Sensor already exists"})
    notfired {
      raise wrangler event "child_creation"
      attributes {"name": sensor_name,
                  "color": "#ffff00",
                  "rids": rulesets_to_install }
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
      exists = ent:sensor_map.values() >< sensor_name
    }
    if exists then 
      send_directive("delete_sensor", {"deleting sensor": sensor_name})
    fired{
      clear ent:sensor_map{get_tx_from_sensor_name(sensor_name)}
      raise wrangler event "child_deletion"
        attributes {"name": sensor_name};
    }
  }
  
  rule subscribe_sensor_to_parent {
    select when wrangler child_initialized
    pre {
      child_name = event:attr("name")
      eci = event:attr("eci")
      child_rx = wrangler:skyQuery(eci, "io.picolabs.subscription", "wellKnown_Rx")["id"]
      parent_tx = subscription:wellKnown_Rx()["id"]
    }
      event:send({"eci":child_rx, "domain":"wrangler", "type":"subscription", "attrs":{
        "name" : child_name,
        "Rx_role": "sensor",
        "Tx_role": "manager",
        "channel_type": "subscription",
        "wellKnown_Tx" : parent_tx
      }})
  }
  
  
  
  rule introduce_sensor {
    select when sensor introduce
    pre {
      incoming_tx = event:attr("Tx")
      incoming_name = event:attr("name")
      host = event:attr("Tx_host")
    }
    always {
      raise wrangler event "subscription"
        attributes {
          "wellKnown_Tx" : incoming_tx,
          "name" : incoming_name,
          "Rx_role": "peer",
          "Tx_role": "sensor",
          "channel_type": "subscription",
          "Tx_host": host
        };
    }
  }
  
  rule store_new_sensor_subscription {
    select when wrangler subscription_added
    pre {
      name = event:attr("name").klog("name: ")
      tx_role = event:attr("bus")["Tx_role"].klog("tx role: ")
      tx = event:attr("bus")["Tx"].klog("tx: ")
    }
    if tx_role == "sensor" then 
      noop()
    fired{
      ent:sensor_map{tx} := name
    }
  }
  
  rule clear_sensor_map {
    select when sensor clear_map
    always {
      ent:sensor_map := {}
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    always {
      raise wrangler event "pending_subscription_approval" 
        attributes event:attrs;
    }
  }
  
}
