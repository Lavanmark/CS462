ruleset sensor_profile {
  meta {
    provides get_phone_number, get_threshold, get_profile
    shares __testing, get_phone_number, get_threshold, get_profile
  }
  
  global {
    __testing = { 
    "queries":
      [ {"name":"get_profile"},
        {"name":"get_threshold"},
        {"name":"get_phone_number"}], 
    "events":[]
    }
    
    get_phone_number = function(){
      ent:profile_phone.defaultsTo("+19199739210")
    }
    
    get_threshold = function(){
      ent:profile_threshold.defaultsTo(75)
    }
    
    get_profile = function(){
      {     
          "name": ent:profile_name.defaultsTo("NO_NAME"),
          "phone": ent:profile_phone.defaultsTo("+19199739210"),
          "location": ent:profile_location.defaultsTo("LOCATION_UNKNOWN"),
          "threshold": ent:profile_threshold.defaultsTo(75)
      }
    }
  }
  
  rule profile_updated{
    select when sensor profile_updated
    pre{
      name = event:attr("name")
      phone = event:attr("phone_number")
      location = event:attr("location")
      threshold = event:attr("threshold")
    }
    send_directive("profile_updated", {"Profile Updated": "YES" })
    always{
      ent:profile_name := name
      ent:profile_phone := phone
      ent:profile_location := location
      ent:profile_threshold := threshold
    }
  }
}
