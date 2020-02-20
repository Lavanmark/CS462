ruleset temperature_store {
  meta {
    provides temperatures, threshold_violations, inrange_temperatures, current_temperature
    shares temperatures, threshold_violations, inrange_temperatures, current_temperature
  }
  global {
    
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
