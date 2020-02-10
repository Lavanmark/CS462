ruleset wovyn_temp_tests {
  meta {
    use module temperature_store alias tstore
    shares __testing
  }
  global {
    __testing = { "queries":
      [] , 
      "events":
        [ { "domain": "test", "type": "get_temps" },
          { "domain": "test", "type": "get_violations" },
          { "domain": "test", "type": "get_inrange" },
          { "domain": "test", "type": "reading_reset" }
        ]
    }
  }
  
  rule test_get_temperatures {
    select when test get_temps
    send_directive("test_get_temperatures", {"history" : tstore:temperatures()})
  }
  
  rule test_get_violations {
    select when test get_violations
    send_directive("test_get_violations", {"history" : tstore:threshold_violations()})
  }
  
  rule test_get_inrange {
    select when test get_inrange
    send_directive("test_get_inrange", {"history" : tstore:inrange_temperatures()})
  }
  
  rule test_reset {
    select when test reading_reset
    send_directive("test_reset", {"clearing": "violation logs and temperature logs"})
    always{
      raise sensor event "reading_reset"
    }
  }
}
