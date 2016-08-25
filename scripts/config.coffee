# Description : Init/load/save config for each user
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
path = require 'path'
SlackClient = require 'slack-api-client'
token = process.env.HUBOT_SLACK_TOKEN || ''
slack = new SlackClient(token)

module.exports = (robot) ->

  get_userid = (res) ->
    return res.message.user.id

  get_username = (res) ->
    return res.message.user.name

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/" + process.env.CONFIG_DIR

  get_config_file = (userid) ->
    return configdir + "config_" + userid + ".json"

  robot.respond /test2/,(res) ->
    res.send "get"

  user_config = (res) ->
    if res is "common"
      return JSON.parse fs.readFileSync(get_config_file res),'utf8'
    JSON.parse fs.readFileSync(get_config_file(get_userid res), 'utf8')

  insert_token_to_url = (token, url) ->
    url = url.split("\/\/")
    url[0] + "//:#{token}@" + url[1]

  slack.api.users.list ({
    presence:1
  }), (err,ret) ->
    throw err if err
    exist = fs.existsSync get_config_file "common"
    if exist is false
      common_data = {
        token:null
        team_members:[]
      }
      fs.writeFileSync (get_config_file "common"), (JSON.stringify common_data)
    commonconfig = user_config "common"
    commonconfig.team_members = []
    for item in ret['members']
      if item['is_bot'] is false and item.name isnt 'slackbot'
        file = get_config_file item['id']
#        console.log item.id
        commonconfig.team_members.push ({
          id:item.id
          name:item.name
          email:item.profile.email
          alias:item.profile.email.split('@')[0]
        })
        exist = fs.existsSync file
        if exist is false
          console.log item['name']
          user_data = {
            id:item['id']
            name:item['name']
            token:null
            mapping:[]
            email:item.email
            project:{}
            team:{}
          }
        
#          console.log user_data
          fs.writeFileSync file, JSON.stringify(user_data)
        else
          config = JSON.parse fs.readFileSync(get_config_file item.id,'utf8')
          #config = user_config "common"
#          console.log config
          if config.email isnt item.profile.email or config.name isnt item.name
            config.email = item.profile.email
            config.name = item.name
            fs.writeFileSync file,JSON.stringify config,'utf8'
          #if config.token is undefined
          #  slack.api.chat.postMessage ({
          #    channel:"@#{item.name}"
          #    text:"Please set your vso token."
          #    as_user:true
          #  }), (e,r) ->
          #    throw e if e
#    console.log commonconfig
    fs.writeFileSync (get_config_file "common"),(JSON.stringify commonconfig),'utf8'

  robot.respond /vso config init$/i, (res) ->
    file = get_config_file get_userid res
    console.log fs.readFileSync file,'utf8'
    user_data = {
      id:get_userid res
      name:get_username res
      token:null
      mapping:[]
    }
    fs.writeFileSync file,JSON.stringify user_data

  robot.respond /config set vso token ([0-9a-zA-Z]+)/i, (res) ->
    #res.send "Please contact bot admin!"
    file = get_config_file get_userid res
    config = user_config res
    config.token = res.match[1]
    console.log config
    console.log file
    fs.writeFileSync file,(JSON.stringify config),'utf8'


  robot.respond /config set map ([^\s\x20\t]+) (.*)$/, (res) ->
    file = get_config_file get_userid res
    config = JSON.parse fs.readFileSync file, 'utf8'

    from = res.match[1]
    to = res.match[2]

    config['mapping'].push {
      from:from
      to:to
    }

    fs.writeFileSync file, JSON.stringify config
    res.send "Now #{from} is map to #{to}."

  robot.respond /ls config$/, (res) ->
    if res.message.user.room is res.message.user.name
      config = user_config res
      res.send "Default Project : #{config.project.name}"
      res.send "Default Team : #{config.team.name}"
      res.send "Mapping :"
      for item in config.mapping
        res.send "Map \"#{item['from']}\" to \"#{item['to']}\""
    else
      res.send "Please try this command in direct chat channel."

