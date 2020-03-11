ruleset twilio_lab {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms, default_sender, get_messages
    shares default_sender
  }
 
  global {
    base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
    
    send_sms = defaction(to, from, body) {
      every{
          http:post(base_url + "Messages.json", form = {
                "Body" : body,
                "From" : from,
                "To" : to
            }) setting(response);
      }
      returns {
        "response" : response{"content"}.decode()
      }
    }
    
    default_sender = defaction(to, body){
      every{
        send_sms(to,"+12052559063",body) setting (response)
      }
      returns response{"response"}
    }
    
    get_messages = function(to, from, offset, size){
      messages = http:get(base_url + "Messages.json?", qs = {
        "PageSize": size.defaultsTo(50),
        "Page": offset.defaultsTo(0),
        "To": to,
        "From": from
      });

      messages{"content"}.decode()
    }
    
  }
}
