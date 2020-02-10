ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures
    shares temperatures, threshold_violations, inrange_temperatures
  }
  global {
    
    clear_temp = {}
    clear_violation = {}
    
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
