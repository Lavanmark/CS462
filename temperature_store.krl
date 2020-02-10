ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares __testing, temperatures, threshold_violations, inrange_temperatures
  }
  global {
    
    clear_temp = {}
    clear_violation = {}
    
    __testing = { "queries":
      [] , 
      "events":
        [ { "domain": "test", "type": "get_temps" },
          { "domain": "test", "type": "get_violations" },
          { "domain": "test", "type": "get_inrange" },
          { "domain": "test", "type": "reading_reset" }
        ]
    }
    
    temperatures = function(){
      return ent:temperature_map
    }
    
    threshold_violations = function(){
      return ent:violation_map
    }
    
    inrange_temperatures = function(){
      return ent:temperature_map.filter(function(v,k){(ent:violation_map >< k) == false})
    }
  }
  
  rule test_get_temperatures {
    select when test get_temps
    send_directive("test_get_temperatures", {"history" : temperatures()})
  }
  
  rule test_get_violations {
    select when test get_violations
    send_directive("test_get_violations", {"history" : threshold_violations()})
  }
  
  rule test_get_inrange {
    select when test get_inrange
    send_directive("test_get_inrange", {"history" : inrange_temperatures()})
  }
  
  rule test_reset {
    select when test reading_reset
    send_directive("test_reset", {"clearing": "violation logs and temperature logs"})
    always{
      raise sensor event "reading_reset"
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
  
  rule clear_temperatures {
    select when sensor reading_reset
    send_directive("clear_temperatures",{"sensor reading_reset": "Reading variables reset to nothing."})
    always{
      ent:temperature_map := clear_temp
      ent:violation_map := clear_violation
    }
  }
}
