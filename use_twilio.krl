ruleset use_twilio {
  meta {
    use module cs462_keys
    use module twilio_lab alias twilio
      with account_sid = keys:twilio{"account_sid"}
      auth_token = keys:twilio{"auth_token"}
      
    shares __testing
    logging on
  }
  
  global{
    __testing = { "queries": [ ],
              "events": [ { "domain": "test", "type": "send_test_message" } ]
            }
  }

  rule test_send_sms {
    select when test new_message
      twilio:send_sms(event:attr("to"),
                      event:attr("from"),
                      event:attr("body")
                      )
  }
  
  rule another_test_sms {
    select when test send_test_message
      twilio:send_sms("+19199739210", "+12052559063", "\"This is a test message. F\"")
  }
}
