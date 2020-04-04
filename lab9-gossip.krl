ruleset gossip {
  meta {
    use module io.picolabs.subscription alias subscription
    shares __testing, get_rumors_received, get_seen_tracker, get_my_latest, get_is_processing
  }
  global {
    
    __testing = { "queries":
      [ { "name": "__testing" },
        { "name": "get_rumors_received"},
        { "name": "get_seen_tracker"},
        { "name": "get_my_latest"},
        { "name": "get_is_processing"}
      ] , "events":
      [ { "domain": "gossip", "type": "update_heartrate", "attrs": ["heartbeat_rate"] },
        { "domain": "gossip", "type": "subscribe_neighbor", "attrs": [ "name", "Tx", "Tx_host" ] }, //gossip subscribe_neighbor
        { "domain": "gossip", "type": "process" },
        { "domain": "gossip", "type": "process", "attrs": ["process"] }
      ]
    }
    
    get_rumors_received = function() {
      ent:rumors_recv
    }
    
    get_seen_tracker = function() {
      ent:seen_tracker
    }
    
    get_my_latest = function() {
      ent:my_latest
    }
    
    get_is_processing = function() {
      ent:do_process
    }
    
    get_state = function(seen) {
      ent:rumors_recv.filter(function(v){
        id = get_picoID(v{"MessageID"})
        seen{id}.isnull() || (seen{id} < get_sequence(v{"MessageID"}))
      }).sort(function(a,b){
        aseq = get_sequence(a{"MessageID"})
        bseq = get_sequence(b{"MessageID"})
        aseq <=> bseq
      })
    }
    
    
    getPeer = function() {
      subs = subscription:established("Rx_role", "gossiper")

      frens_in_need = ent:seen_tracker.filter(function(v,k){
        get_state(v).length() > 0
      })
      
      rand_fren = frens_in_need.keys()[random:integer(frens_in_need.length() - 1)]
      frens_in_need.length() < 1 => subs[random:integer(subs.length() - 1)] | subs.filter(function(a){a{"Tx"} == rand_fren}).head()
    }
    
    
    get_best_sequence = function(pico) {
      filter_rumors = ent:rumors_recv.filter(function(v){
        id = get_picoID(v{"MessageID"})
        id == pico
      }).map(function(v){get_sequence(v{"MessageID"})})
      sorted_rumors = filter_rumors.sort(function(a,b){a<=>b}).klog("sorted array: ")
      sorted_rumors.reduce(function(a, b) { (b == a + 1) => b | a }, -1)
    }
    
    
    prepareMessage = function(subscriber) {
      message = random:integer(10) < 6 => prepare_rumor(subscriber) | prepare_seen(subscriber)
      message = message{"message"}.isnull() => prepare_seen(subscriber) | message
      message
    }
    
    prepare_rumor = function(subscriber) {
      missing_rumor = get_state(ent:seen_tracker{subscriber{"Tx"}})
      return { "message": missing_rumor.isnull() => null | missing_rumor[0],
               "type": "rumor" }
    }
    
    prepare_seen = function(subscriber) {
      return {"message": ent:my_latest, 
              "sender": subscriber,
              "type": "seen"} 
    }
    
    get_sequence = function(message_id){
     splits = message_id.split(re#:#)
     splits[splits.length()-1].as("Number")
    }
    
    get_picoID = function(message_id){
     splits = message_id.split(re#:#)
     splits[0]
    }
    
    new_message_ID = function(){
      oldseq = ent:self_sequence
      picoid = meta:picoId
      return picoid + ":" + oldseq
    }
    
    create_new_personal_rumor_message = function(temp, time) {
      {
        "MessageID": new_message_ID(),
        "SensorID": meta:picoId,
        "Temperature": temp,
        "Timestamp": time
      }
    }
   
  }
  
  rule update_rate {
    select when gossip update_heartrate
    pre{
      new_rate = event:attr("heartbeat_rate")
    }
    if not new_rate.isnull() then noop()
    fired {
      ent:heartbeat_rate := new_rate
    }
  }
  
  rule do_process_toggle {
    select when gossip process
    pre{
      process = event:attr("process")
    }
    if process.isnull() || (process != "on" && process != "off") then noop()
    fired { //toggle
      ent:do_process := ent:do_process == "on" => "off" | "on"
    } else { //set
      ent:do_process := process
    } finally { //if do_process is on, restart the gossip heartbeat.
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:heartbeat_rate})
        if ent:do_process == "on" && schedule:list().klog("schedule:").none(function(act){ act{"id"} == meta:picoId && act{"event"}{"domain"} == "gossip" && act{"event"}{"type"} == "heartbeat"})
    }
  }
  
  rule gossip_heartbeat {
    select when gossip heartbeat where ent:do_process == "on"
    pre {
      subscriber = getPeer().klog("Subscriber info:")
      m = prepareMessage(subscriber)
      message_pico = get_picoID(m{"message"}{"MessageID"})
      message_seq = get_sequence(m{"message"}{"MessageID"})
    }
    if subscriber.isnull() == false && m.isnull() == false then 
      event:send({
          "eci": subscriber{"Tx"},
          "domain": "gossip", 
          "type": m{"type"}.klog("Message type being sent:"),
          "attrs": m
      })
    fired{ 
      ent:seen_tracker{[subscriber{"Tx"}, message_pico]} :=  message_seq
        if m{"type"} == "rumor" && 
          ((ent:seen_tracker{subscriber{"Tx"}}{message_pico}.isnull() && message_seq == 0) || 
            ent:seen_tracker{subscriber{"Tx"}}{message_pico} + 1 == message_seq)
    }finally{
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:heartbeat_rate})
    }
  }
  
  
  
  rule gossip_rumor {
    select when gossip rumor where ent:do_process == "on"
    pre {
      message = event:attr("message")
      message_id = message{"MessageID"}
      pico = get_picoID(message_id)
      sequence = get_sequence(message_id)
    }
    if ent:my_latest{pico}.isnull() then noop()
    fired {
      ent:my_latest{pico} := -1
    } finally {
      ent:rumors_recv := ent:rumors_recv.append(message)
        if ent:rumors_recv.none(function(x){x{"MessageID"} == message_id })
      
      ent:my_latest{pico} := get_best_sequence(pico)
    }
  }
  
  
  
  rule gossip_seen {
    select when gossip seen where ent:do_process == "on"
    pre {
      sender = event:attr("sender"){"Rx"}
      message = event:attr("message")
    }
    always {
      ent:seen_tracker{sender} := message
    }
  }
  
  
  
  rule store_new_gossiper_subscription {
    select when wrangler subscription_added
    pre {
      tx_role = event:attr("bus")["Tx_role"].klog("tx role: ")
      tx = event:attr("bus")["Tx"].klog("tx: ")
    }
    if tx_role == "gossiper" then 
      noop()
    fired{
      ent:seen_tracker{tx} := {}
    }
  }
  
  
  rule subscribe_gossiper {
    select when gossip subscribe_neighbor
    pre {
      incoming_tx = event:attr("Tx")
      incoming_name = event:attr("name")
      host = event:attr("Tx_host")
    }
    always {
      raise wrangler event "subscription"
        attributes {
          "wellKnown_Tx" : incoming_tx,
          "name" : incoming_name,
          "Rx_role": "gossiper",
          "Tx_role": "gossiper",
          "channel_type": "subscription",
          "Tx_host": host
        };
    }
  }
  
  rule ruleset_added {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
        ent:heartbeat_rate := 10;
        ent:self_sequence := 0;
        ent:rumors_recv := [];
        ent:my_latest := {}
        ent:seen_tracker := {} //map of peer_Tx to a map of PicoIDs to latest seen message sequence number
        ent:do_process := "on"
        schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 10})
    }
  }
  
  rule new_local_temp_reading {
    select when wovyn new_temperature_reading
    pre {
      tempF = event:attr("temperature"){"temperatureF"}
      time = event:attr("timestamp")
      message = create_new_personal_rumor_message(tempF, time)
    }
    always{
      ent:rumors_recv := ent:rumors_recv.append(message)
      ent:my_latest{meta:picoId} := get_best_sequence(meta:picoId)
      ent:self_sequence := ent:self_sequence + 1
    }
  }
}
