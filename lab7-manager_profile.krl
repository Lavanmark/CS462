ruleset manager_profile {
  meta {
    use module manage_sensors
    use module cs462_keys
    use module twilio_lab alias twilio
       with account_sid = keys:twilio{"account_sid"}
       auth_token = keys:twilio{"auth_token"}
    shares __testing
    
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      ] , "events":
      [ 
        { "domain": "manager", "type": "profile_updated", "attrs": [ "phone_number" ] }
      ]
    }
    
    get_phone_number = function() {
      ent:phone_number.defaultsTo(manage_sensors:get_default_number())
    };
  }
  
  rule update_profile {
    select when manager profile_updated
    pre{
      number = event:attr("phone_number")
    }
    send_directive("update profile", {"number set to": number});
    always {
      ent:sms_number := number
    }
  }
  
  rule send_notification {
    select when manager send_notification
    pre{
      tempF = event:attr("temperature")
      time = event:attr("timestamp")
      name = event:attr("name")
      threshold = event:attr("threshold")
    }
    every{
      twilio:default_sender(
              to = get_phone_number(),
              body = ("The sensor '"+ name +"' had a temperature reading (" + tempF + ") at " + time 
                    + " which was in violation of your threshold of: " 
                    + threshold + ". <3 KRL")
                        ) setting (response);
      send_directive("twilio_response", {"response": response})
    }
  }
  
  rule threshold_violation {
    select when sensor threshold_violation
    always{
      raise manager event "send_notification"
        attributes event:attrs;
    }
  }
}
