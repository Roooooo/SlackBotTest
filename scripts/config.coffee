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

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/config/"

  get_config_file = (userid) ->
    return configdir + "config_" + userid + ".json"

  user_config = (res) ->
    JSON.parse fs.readFileSync(get_config_file(get_userid res), 'utf8')

  insert_token_to_url = (token, url) ->
    url = url.split("\/\/")
    url[0] + "//:#{token}@" + url[1]

  slack.api.users.list ({
    presence:1
  }), (err,ret) ->
    throw err if err
    for item in ret['members']
      if item['is_bot'] is false and item.name isnt 'slackbot'
        file = get_config_file item['id']
        console.log item['id']
        console.log item['name']
        console.log item
        exist = fs.existsSync file
        if exist is false
          user_data = {
            id:item['id']
            name:item['name']
            token:null
            mapping:{}
          }
        
          console.log user_data
          fs.writeFileSync file, JSON.stringify(user_data)
        else
          config = JSON.parse fs.readFileSync(get_config_file item.id,'utf8')
          console.log config
          if config.token is undefined
            slack.api.chat.postMessage ({
              channel:"@#{item.name}"
              text:"Please set your vso token."
              as_user:true
            }), (e,r) ->
              throw e if e
          else
            token = config.token
            insert_token_to_url token, "https://mseng.visualstudio.com/DefaultCollection/_apis/projects/"
            # TODO: how to get profile with basic auth?
            console.log profileurl
            info = request('GET',profileurl).getBody('utf8')
            console.log JSON.parse info

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

  robot.respond /config set vso token/i, (res) ->
    res.send "Please contact bot admin!"

  robot.respond /config set map [^\s\x20\t]+ (.*)$/, (res) ->
    file = get_config_file get_userid res
    config = JSON.parse fs.readFileSync file, 'utf8'

    from = res.match[0].split('map ')[1].split(' ')[0]
    to = res.match[1]

    config['mapping'].push {
      from:from
      to:to
    }

    fs.writeFileSync file, JSON.stringify config

  robot.respond /ls config$/, (res) ->
    if res.message.user.room is res.message.user.name
      config = user_config res
      res.send "Default Project : #{config['default_project']}"
      res.send "Default Team : #{config['default_team']}"
      res.send "Mapping :"
      for item in config['mapping']
        res.send "Map \"#{item['from']}\" to \"#{item['to']}\""
    else
      res.send "Please try this command in direct chat channel."

