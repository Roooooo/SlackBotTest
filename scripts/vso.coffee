# Description : Deal with visual studio online issue
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
vso = require 'vso-client'
CronJob = require('cron').CronJob
module.exports = (robot) ->
  
  get_userid = (res) ->
    return res.message.user.id

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/config/"

  get_config_file = (userid) ->
    return configdir + "config_" + userid + ".json"
  
  user_config = (res) ->
    if res is "common"
      return JSON.parse fs.readFileSync(configdir + "config_common.json", 'utf8')
    JSON.parse fs.readFileSync(get_config_file(get_userid res), 'utf8')
  
  get_token = (res) ->
    user_config(res)['token']

  get_default_pid = (res) ->
    config = user_config res
    return config['default_PID']

  APIv1 = "api-version=1.0"
  APIv2 = "api-version=2.0"
  APIv2p1 = "api-version=2.0-preview.1"
  APIv3 = "api-version=3.0"
  APIv3p2 = "api-version=3.0-preview.2"

  DashboardsName = []
  DashboardsURL = []
  DashboardsID = []
  ProjectName = []
  ProjectURL = []
  ProjectID = []
  TeamName = []
  TeamURL = []
  TeamID = []

  insert_password_to_url = (username, psw, url) ->
    url = url.split("\/\/")
    url[0] + "//#{username}:#{psw}@" + url[1]

  insert_token_to_url = (token, url) ->
    url = url.split("\/\/")
    url[0] + "//:#{token}@" + url[1]




  refresh_project_info = (url) ->
    info = JSON.parse(request('GET',url).getBody('utf8'))['value']

    ProjectName = []
    ProjectURL = []
    ProjectID = []

    for obj in info
      ProjectID.push obj['id']
      ProjectName.push obj['name']
      ProjectURL.push obj['url']

  refresh_team_info = (url) ->
    info = JSON.parse(request('GET',url).getBody('utf8'))['value']
    TeamName = []
    TeamURL = []
    TeamID = []
    
    for obj in info
      TeamName.push obj['name']
      TeamID.push obj['id']
      TeamURL.push obj['URL']

  refresh_dashboards_info = (url) ->
    info = JSON.parse(request('GET',url).getBody('utf8'))['dashboardEntries']

    DashboardsName = []
    DashboardsURL = []
    DashboardsID = []

    for obj in info
      DashboardsName.push obj['name']
      DashboardsURL.push obj['url']
      DashboardsID.push obj['id']

  ProjURL = "https://mseng.visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"

# Get a board /Scenarios, stories and so on./ 

  robot.respond /vso get board$/i, (res) ->
    token = get_token res

    refresh_project_info insert_token_to_url token,ProjURL
    PID = ProjectID[ProjectName.indexOf 'VSOnline']
    
    url2 = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    url = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/#{PID}/#{TID}/_apis/work/boards?#{APIv2p1}"
    info = request('GET',url).getBody('utf8')
    info = JSON.parse(info)
    console.log info
    url = insert_token_to_url token,info['value'][1]['url'] + "?" + APIv2p1

    info = request('GET',url).getBody('utf8')
    console.log JSON.parse info

# Monitor the request reviewed by users

  check_requests_method = ->
    token = get_token "common"
    -> check_requests(token)

  check_requests = (token)->
    common = user_config "common"
    team_members = common.team_members

    pid = get_default_pid "common"
    repourl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
    repourl = insert_token_to_url token,repourl
    console.log repourl
    info = JSON.parse request('GET',repourl).getBody('utf8')
    for repo in info['value']
      requesturl = insert_token_to_url token,repo['url'] + "/pullRequests?#{APIv2}"
      requests = JSON.parse request('GET',requesturl).getBody('utf8')
      for req in requests.value
        if req.status is 'active'
          for reviewer in req.reviewers
            #slack.api.users.list
            for user in team_members
              if reviewer.uniquename is user.email
                slack.api.char.postMessage ({
                  channel:"@#{user.name}"
                  text:"There's a pull request to review."
                  as_user:true
                }), (e,r) ->
                  throw e if e
  monitor_review = new CronJob('*/30 * * * * *', check_requests_method(), null, true)

# Get pull requests

  robot.respond /vso get request$/i, (res) ->
    token = get_token res

    pid = get_default_pid res
    if pid is undefined
      res.send "Please set your project first!"
    else
      repourl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
      repourl = insert_token_to_url token, repourl
      info = request('GET',repourl).getBody('utf8')
      info = JSON.parse info
      for item in info['value']
        url = insert_token_to_url token, item['url'] + "/pullRequests?#{APIv1}"
        info = request('GET',url).getBody('utf8')
        rt = JSON.parse info
        if rt.count isnt 0

          console.log rt.value[0]
      
    

# Get Dashboard

  robot.respond /vso get dashboard$/i, (res) ->
    token = get_token res

    refresh_project_info insert_token_to_url token,ProjURL
    PID = ProjectID[ProjectName.indexOf 'VSOnline']
    
    url2 = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    itemsurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection" + "/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/?api-version=3.0-preview.2"
    refresh_dashboards_info itemsurl
    DID = DashboardsID[DashboardsName.indexOf 'Overview']

    dashboardurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection" +"/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/#{DID}?api-version=3.0-preview.2"
    info = request('GET',dashboardurl).getBody('utf8')
    info = JSON.parse(info)

# Set VSO default project

  robot.respond /vso set default project (.*)/, (res) ->
    token = get_token res
    config = user_config res

    oldProject = config['default_project']
    newProject = res.match[1]

    refresh_project_info insert_token_to_url token, ProjURL
    
    newIndex = ProjectName.indexOf newProject

    if newIndex isnt -1

      config['default_project'] = newProject
      config['default_PID'] = ProjectID[newIndex]
      config['default_PURL'] = ProjectURL[newIndex]

    else

      res.send "Error : Unknown Project Name."
      newProject = oldProject
    
    res.send "Your old default project : #{oldProject} ."
    res.send "Your new default project : #{newProject} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config

# Set VSO default team

  robot.respond /vso set default team (.*)/, (res) ->
    token = get_token res
    config = user_config res

    project = config['default_project']
    if project is undefined
      res.send "Please set your default project first."
      return
    refresh_team_info insert_token_to_url token, config['default_PURL'] + "/teams?#{APIv1}&$top=1000"

    oldTeam = config['default_team']
    newTeam = res.match[1]

    newIndex = TeamName.indexOf newTeam

    if newIndex isnt -1

      config['default_team'] = newTeam
      config['default_TID'] = TeamID[newIndex]
      config['default_TURL'] = TeamURL[newIndex]

    else

      res.send "Error : Unknown Team Name."
      newTeam = oldTeam

    res.send "Your old default team : #{oldTeam} ."
    res.send "Yout new default team : #{newTeam} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config
