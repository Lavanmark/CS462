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
    __testing = { "queries": [],
              "events": [ {"domain": "get", "type": "messages"},
                { "domain": "get", "type": "messages",
                            "attrs": [ "to", "from", "size", "offset" ] },
                { "domain": "test", "type": "send_test_message" },
                { "domain": "test", "type": "new_message",
                            "attrs": [ "to", "from", "body" ] }
               ]
            }
  }

  rule test_send_sms {
    select when test new_message
    every{
      twilio:send_sms(event:attr("to"),
                      event:attr("from"),
                      event:attr("body")
                      ) setting (response);

      send_directive("response", {"response": response})
    }
  }
  
  rule get_sms {
    select when get messages
    pre {
      messages = twilio:get_messages(
        to = event:attr("to") => event:attr("to") | null,
        from = event:attr("from") => event:attr("from") | null,
        size = event:attr("size") => event:attr("size") | 50,
        offset = event:attr("offset") => event:attr("offset") | null
      )
    }

    send_directive("messages", {"messages": messages})
  }
  
  rule another_test_sms {
    select when test send_test_message
    every{
      twilio:send_sms("+19199739210", "+12052559063", "\"This is a test message. F\"") setting (response);

      send_directive("response", {"response": response})
    }
  }
}
