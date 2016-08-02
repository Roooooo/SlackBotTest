# Description : Init/load/save config for each user
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
path = require 'path'
SlackClient = require 'slack-api-client'
token = process.env.HUBOT_SLACK_TOKEN || ''
slack = new SlackClient(token)

module.exports = (robot) ->

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/config"

  slack.api.users.list ({
    presence:1
  }), (err,ret) ->
    throw err if err
    for item in ret['members']
      if item['is_bot'] is false
        file = configdir + "/config_" + item['id'] + ".json"
        console.log item['id']
        console.log item['name']
        console.log file
        #exist = fs.existsSync file
        #if exist is false
        user_data = {
          name:item['name']
          token:null
        }
        
        console.log user_data
        fs.writeFileSync file, JSON.stringify(user_data)

        #fs.existsSync file, (exist) ->
        #  console.log exist
        #  if exist is false
        #    console.log file
        #    fs.writeFileSync file, null
  
  update_user_info = ->


  init_vso_config = (userID) ->
    vsoconfigdir = "/home/t-jiyunz/teambot/Slack_Teambot/config/vso"
    
    file = vsoconfigdir + "/" + userID + ".json"
    slack.api.user.info ({
      user:userID
    }), (err, ret) ->
      throw err if err
      user_data = {
        id:userID
        name:ret['user']['name']
        vsotoken:null
      }
      fs.writeFileSync file JSON.stringify(user_data)

  robot.respond /vso set config init$/i, (res) ->
    
