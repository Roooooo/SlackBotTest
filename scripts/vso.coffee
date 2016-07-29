# Description : Deal with visual studio online issue
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
vso = require 'vso-client'

module.exports = (robot) ->
  
  url = "https://mseng.visualstudio.com/VSOnline/App%20Experience/_apis/build/builds"
  AuthInfo = "user.txt"
  authInfo = ->
    fs.readFileSync AuthInfo, 'utf8'
  token = authInfo().match(/vsotoken="(.*)"/)[1]

  DashboardsName = []
  DashboardsURL = []
  DashboardsID = []
  ProjectName = []
  ProjectURL = []
  ProjectID = []
  TeamName = []
  TeamURL = []
  TeamID = []

  refresh_project_info = (info) ->
    ProjectName = []
    ProjectURL = []
    ProjectID = []

    for obj in info
      ProjectID.push obj['id']
      ProjectName.push obj['name']
      ProjectURL.push obj['url']

  refresh_team_info = (info) ->
    TeamName = []
    TeamURL = []
    TeamID = []
    
    for obj in info
      TeamName.push obj['name']
      TeamID.push obj['id']
      TeamURL.push obj['URL']

  refresh_dashboards_info = (info) ->
    DashboardsName = []
    DashboardsURL = []
    DashboardsID = []

    for obj in info
      DashboardsName.push obj['name']
      DashboardsURL.push obj['url']
      DashboardsID.push obj['id']

  url = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0"

  client = vso.createClient('https://mseng.visualstudio.com','VSChina/App%20Experience','t-jiyunz',token)
  robot.hear /test$/i, (res) ->
    info = request('GET',url).getBody('utf8')
    info = JSON.parse(info)['value']
    refresh_project_info info

    teamsurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/_apis/projects/" + ProjectID[ProjectName.indexOf 'VSChina'] + "/teams?api-version=1.0"
    info = JSON.parse(request('GET',teamsurl).getBody('utf8'))['value']
    refresh_team_info info

    dashboardurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/" + ProjectID[ProjectName.indexOf 'VSChina'] + "/" + TeamID[TeamName.indexOf 'App Experience'] + "/_apis/Dashboard/Dashboards/?api-version=3.0-preview.2"
    info = JSON.parse(request('GET',dashboardurl).getBody('utf8'))['dashboardEntries']
    refresh_dashboards_info info

    dashboardurl = "https://:#{token}@mseng.visualstudio.com/DefaultCollection/" + ProjectID[ProjectName.indexOf 'VSChina'] + "/" + TeamID[TeamName.indexOf 'App Experience'] + "/_apis/Dashboard/Dashboards/" + DashboardsID[0] + "?api-version=3.0-preview.2"
    info = JSON.parse(request('GET',dashboardurl).getBody('utf8'))
    console.log info
