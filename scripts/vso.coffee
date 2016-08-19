# Description : Deal with visual studio online issue
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
vso = require 'vso-client'
CronJob = require('cron').CronJob
SlackClient = require 'slack-api-client'
slack = new SlackClient(process.env.HUBOT_SLACK_TOKEN)

module.exports = (robot) ->
  get_username = (res) ->
    return "@#{res.message.user.name}"

  get_userid = (res) ->
    return res.message.user.id

  #info = request('GET',"https://slack.com/oauth/authorize?client_id=56799400722.70107065559&scope=incoming-webhook&scope=bot&scope=commands").getBody('utf8')
  #console.log info
  #console.log JSON.parse info

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/" + process.env.CONFIG_DIR

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
    return config.project.id

  APIv1 = "api-version=1.0"
  APIv1p1 = "api-version=1.0-preview.1"
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
    info = JSON.parse request('GET',repourl).getBody('utf8')
    console.log info.value[0]
    for repo in info['value']
      requesturl = insert_token_to_url token,repo['url'] + "/pullRequests?#{APIv2}"
      requests = JSON.parse request('GET',requesturl).getBody('utf8')
      for req in requests.value
        if req.status is 'active'
          for reviewer in req.reviewers
            #slack.api.users.list
            for user in team_members
              if reviewer.uniquename is user.email
                slack.api.chat.postMessage ({
                  channel:"@#{user.name}"
                  text:"Hi #{user.name}, There's a pull request for you to review."
                  as_user:true
                }), (e,r) ->
                  throw e if e

  #monitor_review = new CronJob('* * */1 * * *', check_requests_method(), null, true)

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

    oldProject = config.project.name
    newProject = res.match[1]

    refresh_project_info insert_token_to_url token, ProjURL
    
    newIndex = ProjectName.indexOf newProject

    if newIndex isnt -1

      config.project['name'] = newProject
      config.project['id'] = ProjectID[newIndex]
      config.project['url'] = ProjectURL[newIndex]

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

    project = config.project.name
    if project is undefined
      res.send "Please set your default project first."
      return
    refresh_team_info insert_token_to_url token, config.project.url + "/teams?#{APIv1}&$top=1000"

    oldTeam = config.team.name
    newTeam = res.match[1]

    newIndex = TeamName.indexOf newTeam

    if newIndex isnt -1

      config.team['name'] = newTeam
      config.team['id'] = TeamID[newIndex]
      config.team['url'] = TeamURL[newIndex]

    else

      res.send "Error : Unknown Team Name."
      newTeam = oldTeam

    res.send "Your old default team : #{oldTeam} ."
    res.send "Yout new default team : #{newTeam} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config

  robot.respond /vso set default repo (.*)/, (res) ->
   
    token = get_token res
    config = user_config res

    oldrepo = config.repo
    if oldrepo is undefined
      oldrepo = {
        name:undefined
      }
    newrepo = {
      name:res.match[1]
    }

    pid = get_default_pid res
    repourl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
    repourl = insert_token_to_url token, repourl

    info = JSON.parse request('GET',repourl).getBody('utf8')
  
    for repo in info.value
      console.log repo.name
      if repo.name is newrepo.name
        newrepo.id = repo.id
        newrepo.url = repo.url
        config.repo = newrepo

        res.send "Your old default repo : #{oldrepo.name}."
        res.send "Your new default repo : #{newrepo.name}."
          
        fs.writeFileSync (get_config_file get_userid res),(JSON.stringify config)
        return
    
    res.send "#{res.match[1]} is not a correct repo name."

  robot.respond /vso ls repo$/, (res) ->
    token = get_token res
    config = user_config res

    pid = get_default_pid res
    if pid is undefined
      res.send "Please set your default project first."
      return

    repourl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
    repourl = insert_token_to_url token, repourl

    info = JSON.parse request('GET',repourl).getBody('utf8')
    msg = ""
    console.log info.value
    for repo in info.value
      msg = msg + "Repo name : #{repo.name}\n"

    res.send msg

  robot.respond /vso ls bug( -s .*)?$/, (res) ->
    token = get_token res
    pid = get_default_pid res

    wiqlurl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/wit/wiql?#{APIv1}"
    wiqlurl = insert_token_to_url token,wiqlurl
    
    statemsg = ""
    console.log res.match
    states = ""
    if res.match[1] isnt undefined
      for state in res.match[1].split(' ')
        console.log state
        if states isnt ""
          statemsg = statemsg + " "
          states = states + ","
        if state is "active"
          states = states + "'Active'"
        if state is "resolved"
          states = states + "'Resolved'"
        if state is "closed"
          states = states + "'Closed'"
        if state isnt "-s"
          statemsg = statemsg + state
    else
      states = "'Active'"
      statemsg = "active"

    console.log states

    query = {
      json:{"query":"SELECT [System.Id],[System.Title],[System.State]
        FROM WorkItems 
        WHERE [System.WorkItemType] = 'Bug' AND [System.AssignedTo] = @Me AND [System.State] IN (#{states})"}
    }
    info = JSON.parse request('POST',wiqlurl,query).getBody('utf8')
    
    console.log info
    
    attachments = []

    cnt = 0

    for bug in info.workItems
      cnt = cnt + 1
      bugobj = {}

      bugurl = insert_token_to_url token,bug.url
      buginfo = JSON.parse request('GET',bugurl).getBody('utf8')
      console.log buginfo
      state = buginfo.fields['System.State']
      if state is 'resolved'
        bugobj.color = "good"
      if state is 'Active'
        bugobj.color = "danger"
      
      bugobj.pretext = ""
      bugobj.fields = []

      bugobj.fields.push build_attach_obj "Bug ID",buginfo.id,true

      assigned = buginfo.fields['System.AssignedTo'].split('<')[0]
      bugobj.fields.push build_attach_obj "Bug Assigned To",assigned,true
      bugobj.fields.push build_attach_obj "Bug Name",buginfo.fields['System.Title'],true
      bugobj.fields.push build_attach_obj "Priority",buginfo.fields['Microsoft.VSTS.Common.Priority'],true
      bugobj.fields.push build_attach_obj "State",buginfo.fields['System.State'],true
      attachments.push bugobj

    channel = get_username res

    #console.log msg.attachments
    slack.api.chat.postMessage ({
      channel:"#general",
      text:"Here are #{cnt} #{states} bugs.",
      attachments:JSON.stringify attachments,
      as_user:true
    }), (e,r) ->
      throw e if e

  build_attach_obj = (title,value,short) ->
    obj = {
      title:title,
      value:value,
      short:short
    }
    return obj

  robot.respond /vso resolve bug ([0-9]+)$/, (res) ->
    set_bug_state res.match[1], "resolved", res

  robot.respond /vso close bug ([0-9]+)$/, (res) ->
    set_bug_state res.match[1], "closed", res


  set_bug_state = (bugid, newstate, res) ->
    token = get_token res
    pid = get_default_pid res

    bugurl = "https://mseng.visualstudio.com/DefaultCollection/_apis/wit/workitems/#{bugid}?#{APIv1}"
    bugurl = insert_token_to_url token, bugurl
    info = JSON.parse request('GET',bugurl).getBody('utf8')

    patch = {
      headers:{"Content-type":"application/json-patch+json"}
      body:JSON.stringify([
        {
          op:"replace"
          path:"/fields/System.State"
          value:newstate
        }
      ])
    }
    info = request('PATCH',bugurl,patch).getBody('utf8')
    console.log JSON.parse info
    res.send "Bug #{bugid} has been set to #{newstate}."

  robot.respond /vso ls build (definition|def)(.*)$/,(res) ->
    token = get_token res
    pid = get_default_pid res

    beginwith = ""
    if res.match[2] isnt ''
      word = res.match[2].split(' ')[1]
      beginwith = "&name=#{word}*"

    defurl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/build/definitions?#{APIv2}#{beginwith}"
    defurl = insert_token_to_url token,defurl

    info = JSON.parse request('GET',defurl).getBody('utf8')
    msg = ""
    for def in info.value
      author = def.authoredBy
      if author isnt undefined
        author = author.displayName
      msg = msg + "Build definition: #{def.name}, AuthoredBy: #{author}, id: #{def.id}\n"

    res.send msg

  robot.respond /vso queue build ([0-9]+)( -b .*)?/, (res) ->
    token = get_token res
    pid = get_default_pid res
    
    post = {
      definition:{
        id:res.match[1]
      }
    }
    if res.match[2] isnt undefined
      post.sourceBranch = res.match[2].split(' ')[2]

    buildurl = "https://mseng.visualstudio.com/DefaultCollection/#{pid}/_apis/build/builds?#{APIv2}"
    buildurl = insert_token_to_url token,buildurl

    info = JSON.parse request('POST',buildurl,{
      json:post
    }).getBody('utf8')
    console.log info

# TODO : send feedback to slack

  robot.respond /vso pull request( -s ([^-]+) -t ([^-\x20]+))( -d "([^\"]+)")?/, (res) ->
    token = get_token res
    console.log res.match
    config = user_config res
    repo = config.repo
    if repo is undefined
      res.send "Please set your repo first!"
      return

    repourl = insert_token_to_url token,repo.url
    branurl = repourl + "/refs/heads?#{APIv1}"
    repourl = repourl + "/pullRequests?#{APIv1p1}"

    probj = {
      sourceRefName:"refs/heads/" + res.match[2]
      targetRefName:"refs/heads/" + res.match[3]
      title:"Auto Generate PR"
      description:"Generate by slack team bot."
      reviewers:[]
    }
    if res.match[4] isnt undefined
      probj.description = res.match[5]
    info = request('GET',branurl).getBody('utf8')
    console.log JSON.parse info
    console.log probj
    console.log repourl
    info = request('POST',repourl,{
      json:probj
    }).getBody('utf8')

    info = JSON.parse info

    if info.message isnt undefined
      res.send "Error #{info.message}"
    else
      url = "https://mseng.visualstudio.com/#{config.project.name}/#{config.team.name}/_git/#{config.repo.name}/pullRequest/#{info.pullrequestID}"
      res.send "Build succeed.\n#{url}"
