ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    logging on
    shares hello, __Testing
  }
   
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
    __testing = { "queries": [ { "name": "hello", "args": [ "obj" ] },
                           { "name": "__testing" } ],
              "events": [ { "domain": "echo", "type": "hello" } ]
            }
  }
   
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }
  
  rule hello_monkey {
    select when echo monkey
    pre{
      name = event:attr("name").klog("our passed in name: ").defaultsTo("Monkey")
    }
    send_directive("say", {"something": "Hello " + name})
  }
   
}
