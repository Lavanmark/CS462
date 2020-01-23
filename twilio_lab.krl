ruleset twilio_lab {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms
        
    shares __testing
  }
 
  global {
    send_sms = defaction(to, from, body) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "body":body,
                "from":from,
                "to":to
            }, autoraise = "sms_test_post")
            
    }
    __testing = { "queries": [ ],
              "events": [ { "domain": "test", "type": "new_message",
                            "attrs": [ "to", "from", "body" ] } ]
            }
  }
  
  rule post_result{
    select when http post label re#sms_test_post#
    send_directive("Page says...", {"content":event:attr("content")});
  }
}
