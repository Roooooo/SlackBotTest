# Description : Deal with visual studio online issue
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
vso = require 'vso-client'

module.exports = (robot) ->
  
  get_userid = (res) ->
    return res.message.user.id

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/config/"

  get_config_file = (userid) ->
    return configdir + "config_" + userid + ".json"
  
  user_config = (res) ->
    JSON.parse fs.readFileSync(get_config_file(get_userid res), 'utf8')
  
  get_token = (res) ->
    user_config(res)['token']

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

  TeamURL = "https://mseng.visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"

# Get a board /Scenarios, stories and so on./ 

  robot.respond /vso get board$/i, (res) ->
    token = get_token res

    refresh_project_info insert_token_to_url token,TeamURL
    PID = ProjectID[ProjectName.indexOf 'VSOnline']
    
    url2 = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    url3 = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/#{PID}/#{TID}/_apis/wit/classificationNodes/iterations?#{APIv1}"
    info = request('GET',url3).getBody('utf8')
    info = JSON.parse(info)
    console.log info

    url = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/#{PID}/#{TID}/_apis/work/boards?#{APIv2p1}"
    info = request('GET',url).getBody('utf8')
    info = JSON.parse(info)

    url = insert_token_to_url token,info['value'][0]['url'] + "?" + APIv2p1

    info = request('GET',url).getBody('utf8')


# Get Dashboard

  robot.respond /vso get dashboard$/i, (res) ->
    token = get_token res

    refresh_project_info insert_token_to_url token,TeamURL
    PID = ProjectID[ProjectName.indexOf 'VSOnline']
    
    url2 = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    itemsurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection" + "/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/?api-version=3.0-preview.2"
    refresh_dashboards_info itemsurl
    DID = DashboardsID[DashboardsName.indexOf 'Overview']

    dashboardurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection" +"/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/#{DID}?api-version=3.0-preview.2"
    console.log dashboardurl
    info = request('GET',dashboardurl).getBody('utf8')
    console.log JSON.parse(info)

# Set VSO default project

  robot.respond /vso set default project (.*)/, (res) ->
    token = get_token res
    config = user_config res

    oldProject = config['default project']
    newProject = res.match[1]

    refresh_project_info insert_token_to_url token, TeamURL
    
    newIndex = ProjectName.indexOf newProject

    if newIndex isnt -1

      config['default project'] = newProject
      config['default PID'] = ProjectID[newIndex]
      config['default PURL'] = ProjectURL[newIndex]

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

    project = config['default project']
    refresh_team_info insert_token_to_url token, config['default PURL'] + "/teams?#{APIv1}&$top=1000"

    oldTeam = config['default team']
    newTeam = res.match[1]

    newIndex = TeamName.indexOf newTeam

    if newIndex isnt -1

      config['default team'] = newTeam
      config['default TID'] = TeamID[newIndex]
      config['default TURL'] = TeamURL[newIndex]

    else

      res.send "Error : Unknown Team Name."
      newTeam = oldTeam

    res.send "Your old default team : #{oldTeam} ."
    res.send "Yout new default team : #{newTeam} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config
