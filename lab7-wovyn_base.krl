ruleset wovyn_base {
  meta {
    use module sensor_profile alias prof
    use module io.picolabs.subscription alias subscription
  }
  
  global {
    
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where event:attr("genericThing")
    pre {
      details = event:attrs().klog("attrs")
      temperature_data = event:attr("genericThing"){"data"}{"temperature"}.klog("temp details")
      timestamp = time:now()
    }
    send_directive("process_heartbeat", {"genericThing": "Heartbeat Received."})
    always{
      raise wovyn event "new_temperature_reading"
        attributes { "temperature": temperature_data[0], "timestamp": timestamp }
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre{
      details = event:attrs().klog("temp attr ")
      tempF = event:attr("temperature"){"temperatureF"}.klog("Temp F = ")
    }
    send_directive("find_high_temps", {"threshold_violation": ((tempF > prof:get_threshold()) => "YES" | "NO")})
    always{
      raise wovyn event "threshold_violation"
        attributes event:attrs
          if (tempF > prof:get_threshold())
    }
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    foreach subscription:established().defaultsTo({}).filter(function(info) {
      info{"Rx_role"} == "sensor"
    }) setting(manager)
    pre{
      tempF = event:attr("temperature"){"temperatureF"}
      time = event:attr("timestamp")
    }
    event:send({ "eci": manager{"Tx"}, "domain": "sensor", "type": "threshold_violation",
        "attrs": {"name": prof:get_name(),
                  "temperature": tempF,
                  "timestamp": time,
                  "threshold": prof:get_threshold()}}
    )
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    always {
      raise wrangler event "pending_subscription_approval" 
        attributes event:attrs;
    }
  }
  
}
