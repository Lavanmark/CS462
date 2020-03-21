ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures, current_temperature
    shares __testing, temperatures, threshold_violations, inrange_temperatures, current_temperature
  }
  global {
    
    __testing = { 
    "queries":
      [ {"name":"temperatures"},
        {"name":"threshold_violations"},
        {"name":"inrange_temperatures"},
        {"name":"current_temperature"}
      ], "events": [
        {"domain": "testing", "type": "fake_temp"},
        {"domain": "testing", "type": "fake_temp", "attrs": ["temperature"]},
        {"domain": "testing", "type": "fake_temps", "attrs": ["number"]},
        {"domain": "sensor", "type": "reading_reset"}
      ]
    }
    
    clear_temp = {}
    clear_violation = {}
    clear_latest_temp = -400
    
    temperatures = function(){
      return ent:temperature_map.defaultsTo(clear_temp)
    }
    
    threshold_violations = function(){
      return ent:violation_map.defaultsTo(clear_violation)
    }
    
    inrange_temperatures = function(){
      return ent:temperature_map.filter(function(v,k){(ent:violation_map >< k) == false}).defaultsTo(clear_temp)
    }
    
    current_temperature = function(){
      return ent:latest_temp.defaultsTo(clear_latest_temp)
    }
    
    make_list = function(x, arr){
      (x > 0) => make_list(x-1, arr.append(random:number(80))) | arr
    }
  }
  
  rule fake_temps {
    select when testing fake_temps
      foreach make_list(event:attr("number"),[]) setting (x)
    always{
      raise testing event "fake_temp"
        attributes {"temperature":x}
    }
  }
  
  rule fake_temp {
    select when testing fake_temp
    pre{
      tempF = event:attr("temperature").defaultsTo(random:number(75))
      time = time:now()
    }
    noop()
    //send_directive("fake_temp", {"fake temperature reading of ": tempF})
    always{
      raise wovyn event "new_temperature_reading"
        attributes { "temperature": {"temperatureF":tempF}, "timestamp": time }
    }
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre{
      tempF = event:attr("temperature"){"temperatureF"}
      time = event:attr("timestamp")
    }
    send_directive("collect_temperatures", {"Logging temperature reading": tempF, "Time":time})
    always{
      ent:temperature_map{time}:=tempF
      ent:latest_temp := tempF
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre{
      tempF = event:attr("temperature"){"temperatureF"}
      time = event:attr("timestamp")
    }
    send_directive("collect_threshold_violations", {"Logging threshold violation temperature": tempF, "Time":time})
    always{
      ent:violation_map{time} := tempF
    }
  }
  
  rule readings_request {
    select when sensor readings_requested
    pre{
      rcn = event:attr("rcn").klog("rcn was: ")
      rx = event:attr("Rx")
      report = temperatures()
    }
    event:send({"eci": rx,
                "domain": "sensor",
                "type": "received_report",
                "attrs": {
                  "report": report,
                  "rcn": rcn
                }
    })
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    send_directive("clear_temperatures",{"sensor reading_reset": "Reading variables reset to nothing."})
    always{
      ent:temperature_map := clear_temp
      ent:violation_map := clear_violation
      ent:latest_temp := clear_latest_temp
    }
  }
}
