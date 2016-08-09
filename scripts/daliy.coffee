# Description : For daily chat and test
# @author     : t-jiyunz@microsoft.com

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

  robot.hear /((help|pot|bot)\x20(help|bot|pot))/i, (res) ->
    res.send "Hi i'm pot, welcome to chat room!"
    res.send "You can call me by using one of formats below:"
    res.send "    @pot: [command]"
    res.send "    pot [command]"
    res.send "    (Direct message to me)[command]"
    res.send "===================================================="
    res.send "So far i've supported serveral commands, including : \n"
    res.send "ls [-a] : Show brief info of all build configurations on msdnbuild/msdndeploy/epxprofilebuild.(With -a you will get more details)"
    res.send "build/deploy buildId : Run a build configuration specified by its build id. You can look up the buildIds through 'ls'."
    res.send "build/deploy projectname branchname : Run a build configuration specified by project and branch. Here projectname shoule be in {wiki, galleries, profile, forums, forumsapi, widget, recognition}, and branchname is the name of the branch you want to build, such as \"main\" or \"Trunk\". You can also look up the branchname through 'ls'."
    res.send "hi/hello : Get a warm greeting from @pot. (Temporarily test command for testing whether the bot is online or blocked also. -ping will be online as soon as possible.)"
  
  SlackClient = require('slack-api-client')
  token = process.env.HUBOT_SLACK_TOKEN || ''
  slack = new SlackClient(token)

  robot.respond /test1$/, (res) ->
    console.log "sleeping"
    sleep(10000)
    console.log "wake up"

  robot.respond /test2$/, (res) ->
    console.log "get"

  sleep = (ms) ->
    start = new Date().getTime()
    continue while new Date().getTime() - start < ms
