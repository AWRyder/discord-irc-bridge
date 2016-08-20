var Discord = require("discord.js");
var jsonfile = require('jsonfile');
var chokidar = require('chokidar');
var fs = require('fs');

var mybot = new Discord.Client();

var settings = jsonfile.readFileSync("discord.env");

var watcher = chokidar.watch('var', {ignored: function (string) {
            return string.indexOf(".discord.txt") !== -1;
}, persistent: true});

var serverName = settings.serverName;


var amIReady = false;

mybot.on("message", function(message) {
    var blob = {
        username: message.author.username,
        content: message.content
    };

    var filename = (new Date().getTime())+"."+serverName+".discord.txt";

    fs.writeFile("./var/"+filename,blob.username+":"+blob.content);

});

mybot.on("ready", function(message) {
    var server = mybot.servers.get("name", serverName);
    var channel = server.defaultChannel;
    mybot.sendMessage(channel, "Hello");
    amIReady = true;
});

mybot.loginWithToken(settings.token, function(err) {
});

watcher
    .on('add', function(path) {
      if ( !amIReady ) return;
      fs.readFile(path, "utf-8" ,parseRead);
      function parseRead(err, str){
          if ( !err  ){
              console.dir(str);
              var obj = {
                  "username": str.substring(0,str.indexOf(':')),
                  "content": str.substring(str.indexOf(':')+1)
              }
              console.dir(obj);
              if ( mybot.user.username != obj.username ) {
                  var server = mybot.servers.get("name", serverName);
                  var channel = server.defaultChannel;
                  mybot.sendMessage(channel, obj.username+": "+obj.content);
                  fs.unlink(path)
              }
          }
      }
  });
