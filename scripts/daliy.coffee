# Description : For daily chat and test
# @author     : t-jiyunz@microsoft.com

fs = require 'fs'

module.exports = (robot) ->
  get_username = (response) ->
    "@#{response.message.user.name}"

  get_channel = (response) ->
    if response.message.room is response.message.user.name
      "@#{response.message.room}"
    else
      "@#{response.message.room}"

  robot.respond /(hi)|(hello)/i, (res) ->
    res.send res.random ["Hi " + get_username(res),"Yolo~~~","Hello :P","Greetings! XD", "What's up"]

  robot.hear /bye/i, (res) ->
    res.send "Bye-bye!"

  help = (res, cmd) ->
    if cmd is undefined
      cmd = "common"
    console.log cmd
    msg = ""
    file = "/home/t-jiyunz/teambot/Slack_TeamBot/help.json"
    helpfile = JSON.parse fs.readFileSync(file,'utf8')
    for item in helpfile
      if item.key.match cmd
        if msg isnt ""
          msg = msg + "\n\n"
        msg = msg + item.value

    res.send msg
    return
  
  SlackClient = require('slack-api-client')
  token = process.env.HUBOT_SLACK_TOKEN || ''
  slack = new SlackClient(token)

  robot.respond /test1$/, (res) ->
    console.log "sleeping"
    sleep(10000)
    console.log "wake up"

  sleep = (ms) ->
    start = new Date().getTime()
    continue while new Date().getTime() - start < ms
#C1NNWAB5J
#  slack.api.channels.history ({
#    channel:"C1NNWAB5J"
##    oldest:1472203626.000155
#  }), (err, r) ->
#    throw err if err
#    console.log r
  
  robot.respond /(.*)/, (res) ->
    msg = res.match[1]
    if msg.match(/^\?(.*)?$/)
      cmd = msg.match(/^\?(.*)?$/)[1]
      help res,cmd
