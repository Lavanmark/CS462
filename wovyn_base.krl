ruleset wovyn_base {
  meta {
    use module cs462_keys
    use module twilio_lab alias twilio
       with account_sid = keys:twilio{"account_sid"}
       auth_token = keys:twilio{"auth_token"}
       
    use module sensor_profile alias prof
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
    pre{
      tempF = event:attr("temperature"){"temperatureF"}
      time = event:attr("timestamp")
    }
    every{
      twilio:default_sender(
            to = prof:get_phone_number(),
            body = ("The temperature reading (" + tempF + ") at " + time 
                  + " was in violation of your threshold of: " 
                  + prof:get_threshold() + ". <3 KRL")
                      ) setting (response);
      send_directive("twilio_response", {"response": response})
    }
  }
  
}
