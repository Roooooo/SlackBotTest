# Description : Deal with visual studio online issue
# @author     : t-jiyunz@microsoft.com

request = require 'sync-request'
fs = require 'fs'
vso = require 'vso-client'
CronJob = require('cron').CronJob
SlackClient = require 'slack-api-client'
slack = new SlackClient(process.env.HUBOT_SLACK_TOKEN)
download = require 'download-file'

SlackUpClient = require 'node-slack-upload'
slackup = new SlackUpClient(process.env.HUBOT_SLACK_TOKEN)

module.exports = (robot) ->
  get_username = (res) ->
    return "@#{res.message.user.name}"

  get_channel = (response) ->
    if response.message.room is response.message.user.name
      "@#{response.message.room}"
    else
      "##{response.message.room}"

  get_userid = (res) ->
    return res.message.user.id

  configdir = "/home/t-jiyunz/teambot/Slack_TeamBot/" + process.env.CONFIG_DIR

  get_config_file = (userid) ->
    return configdir + "config_" + userid + ".json"
  
  user_config = (res) ->
    if res is "common"
      return JSON.parse fs.readFileSync(configdir + "config_common.json", 'utf8')
    JSON.parse fs.readFileSync(get_config_file(get_userid res), 'utf8')
  
  get_token = (res) ->
    user_config(res)['token']

  get_pid = (res) ->
    config = user_config res
    return config.project.id

  get_tid = (res) ->
    config = user_config res
    return config.team.id

  APIv1 = "api-version=1.0"
  APIv1p1 = "api-version=1.0-preview.1"
  APIv2 = "api-version=2.0"
  APIv2p1 = "api-version=2.0-preview.1"
  APIv3 = "api-version=3.0"
  APIv3p2 = "api-version=3.0-preview.2"

  instance = "mseng.visualstudio.com"

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

  ProjURL = "https://#{instance}/DefaultCollection/_apis/projects?#{APIv1}"

# Get a board /Scenarios, stories and so on./ 

  robot.respond /vso get board$/i, (res) ->
    token = get_token res

    refresh_project_info insert_token_to_url token,ProjURL
    PID = ProjectID[ProjectName.indexOf 'VSOnline']
    
    url2 = "https://:#{token}@#{instance}/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    url = "https://:#{token}@#{instance}/DefaultCollection/#{PID}/#{TID}/_apis/work/boards?#{APIv2p1}"
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

    pid = get_pid "common"
    repourl = "https://#{instance}/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
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

    pid = get_pid res
    if pid is undefined
      res.send "Please set your project first!"
    else
      repourl = "https://#{instance}/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
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
    
    url2 = "https://:#{token}@#{instance}/DefaultCollection/_apis/projects/" + PID + "/teams?api-version=1.0&$top=1000"
    refresh_team_info url2
    TID = TeamID[TeamName.indexOf 'App Experience']

    itemsurl = "https://:#{token}@#{instance}/DefaultCollection" + "/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/?api-version=3.0-preview.2"
    refresh_dashboards_info itemsurl
    DID = DashboardsID[DashboardsName.indexOf 'Overview']

    dashboardurl = "https://:#{token}@#{instance}/DefaultCollection" +"/#{PID}/#{TID}" + "/_apis/Dashboard/Dashboards/#{DID}?api-version=3.0-preview.2"
    info = request('GET',dashboardurl).getBody('utf8')
    info = JSON.parse(info)

# Set VSO default project

  robot.respond /vso set project (.*)/, (res) ->
    token = get_token "common"
    config = user_config res

    oldProject = config.project.name
    newProject = res.match[1]

    refresh_project_info (insert_token_to_url token, ProjURL)
    
    newIndex = ProjectName.indexOf newProject

    if newIndex isnt -1

      config.project['name'] = newProject
      config.project['id'] = ProjectID[newIndex]
      config.project['url'] = ProjectURL[newIndex]

    else

      res.send "Error : Unknown Project Name."
      newProject = oldProject
    
    res.send "Your old project : #{oldProject} ."
    res.send "Your new project : #{newProject} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config

# Set VSO default team

  robot.respond /vso set team (.*)/, (res) ->
    token = get_token res
    config = user_config res

    project = config.project.name
    if project is undefined
      res.send "Please set your default project first."
      return
    refresh_team_info insert_token_to_url token, config.project.url + "/teams?#{APIv1}&$top=1000"

    oldTeam = config.team.project + "/" + config.team.name
    if config.team.name is undefined
      oldTeam = undefined
    newTeam = res.match[1]

    newIndex = TeamName.indexOf newTeam

    if newIndex isnt -1

      config.team['name'] = newTeam
      config.team['id'] = TeamID[newIndex]
      config.team['url'] = TeamURL[newIndex]

    else

      res.send "Error : Unknown Team Name."
      newTeam = oldTeam

    res.send "Your old team : #{oldTeam} ."
    res.send "Yout new team : #{newTeam} ."

    fs.writeFileSync (get_config_file get_userid res), JSON.stringify config

  robot.respond /vso set repo (.*)/, (res) ->
   
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

    pid = get_pid res
    repourl = "https://#{instance}/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
    repourl = insert_token_to_url token, repourl

    info = JSON.parse request('GET',repourl).getBody('utf8')
  
    for repo in info.value
      console.log repo.name
      if repo.name is newrepo.name
        newrepo.id = repo.id
        newrepo.url = repo.url
        config.repo = newrepo

        res.send "Your old repo : #{oldrepo.name}."
        res.send "Your new repo : #{newrepo.name}."
          
        fs.writeFileSync (get_config_file get_userid res),(JSON.stringify config)
        return
    
    res.send "#{res.match[1]} is not a correct repo name."

  robot.respond /vso ls repo$/, (res) ->
    token = get_token res
    config = user_config res

    pid = get_pid res
    if pid is undefined
      res.send "Please set your default project first."
      return

    repourl = "https://#{instance}/DefaultCollection/#{pid}/_apis/git/repositories?#{APIv1}"
    repourl = insert_token_to_url token, repourl

    info = JSON.parse request('GET',repourl).getBody('utf8')
    msg = ""
    console.log info.value
    for repo in info.value
      msg = msg + "Repo name : #{repo.name}\n"

    res.send msg

  robot.respond /vso ls workitem$/, (res) ->
    token = get_token res
    pid = get_pid res

    wiqlurl = "https://#{instance}/DefaultCollection/#{pid}/_apis/wit/wiql?#{APIv1}"
    wiqlurl = insert_token_to_url token,wiqlurl

    query = {
      json:{"query":"SELECT [System.Id],[System.Title],[System.State]
        FROM WorkItems
        WHERE [System.WorkItemType] = 'TASK' AND [System.AssignedTo] = @Me AND [System.State] IN ('In progress','Proposed')"
      }
    }
    
    attachments = []

    cnt = 0

    info = request('POST',wiqlurl,query).getBody('utf8')
    info = JSON.parse info

    for item in info.workItems
      itemobj = {}
      cnt = cnt + 1

      itemurl = item.url
      itemurl = insert_token_to_url token,itemurl
      
      iteminfo = JSON.parse request('GET',itemurl).getBody('utf8')
      state = iteminfo.fields['System.State']
      if state is "Proposed"
        itemobj.color = 'danger'
      else if state is "In Progress"
        itemobj.color = 'warning'

      itemobj.pretext = ""
      itemobj.fields = []
      
      assigned = iteminfo.fields['System.AssignedTo'].split('<')[0]
      itemobj.fields.push build_attach_obj "ID",iteminfo.id,true
      itemobj.fields.push build_attach_obj "AssignedTo",assigned, true
      itemobj.fields.push build_attach_obj "Name",iteminfo.fields['System.Title'],true
      itemobj.fields.push build_attach_obj "Priority",iteminfo.fields['Microsoft.VSTS.Common.Priority'],true
      
      attachments.push itemobj

    slack.api.chat.postMessage ({
      channel:"#general",
      text:"Here are #{cnt} tasks for you.",
      attachments:JSON.stringify attachments,
      as_user:true
    }), (e,r) ->
      throw e if e


  robot.respond /vso ls bug( -s .*)?$/, (res) ->
    token = get_token res
    pid = get_pid res

    wiqlurl = "https://#{instance}/DefaultCollection/#{pid}/_apis/wit/wiql?#{APIv1}"
    wiqlurl = insert_token_to_url token,wiqlurl
    
    statemsg = ""
    console.log res.match
    states = ""
    if res.match[1] isnt undefined
      for state in res.match[1].split(' ')
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
    pid = get_pid res

    bugurl = "https://#{instance}/DefaultCollection/_apis/wit/workitems/#{bugid}?#{APIv1}"
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

  robot.respond /vso\s+ls\s+build(\s+-k\s+(.*))?$/,(res) ->
    token = get_token res
    pid = get_pid res

    console.log res.match
    key = ""
    if res.match[1] isnt ''
      key = res.match[2]

    defurl = "https://#{instance}/DefaultCollection/#{pid}/_apis/build/definitions?#{APIv2}"
    defurl = insert_token_to_url token,defurl

    info = JSON.parse request('GET',defurl).getBody('utf8')
    msg = ""
    for def in info.value
      author = def.authoredBy
      if author isnt undefined
        author = author.displayName
      if key isnt ""
        if not def.name.match(key)
          continue
      msg = msg + "Build definition: #{def.name}, AuthoredBy: #{author}, id: #{def.id}\n"

    res.send msg

  robot.respond /vso queue build ([0-9]+)( -b .*)?/, (res) ->
    token = get_token res
    pid = get_pid res
    
    console.log res.match
    post = {
      definition:{
        id:res.match[1]
      }
    }
    if res.match[2] isnt undefined
      post.sourceBranch = res.match[2].split(' ')[2]

    buildurl = "https://#{instance}/DefaultCollection/#{pid}/_apis/build/builds?#{APIv2}"
    buildurl = insert_token_to_url token,buildurl

    do_build_and_check res,buildurl,post
  
  do_build_and_check = (res,url,post) ->
    token = get_token res
    pid = get_pid res
    id = post.definition.id
    info = request('POST',url,{
      json:post
    }).getBody('utf8')

    info = JSON.parse info

    href = info._links.self.href + "?" + APIv2
    href = insert_token_to_url token, href
    new CronJob('0 */1 * * * *',check_build_method(res,href),null,true)

  check_build_method = (res, href) ->
    channel = get_username res
    url = href
    -> if check_build(res,url) is true
      this.stop()

  check_build = (res,url) ->
    token = get_token res
    info = JSON.parse request('GET',url).getBody('utf8')
    console.log info.status
    if info.status is "completed"
      console.log "yes"
      logurl = info.logs.url + "?" + APIv2
      logurl = insert_token_to_url token, logurl
      loginfo = JSON.parse request('GET',logurl).getBody('utf8')
      console.log loginfo
      for log in loginfo.value
        tmpurl = log.url + "?#{APIv2}"
        tmpurl = insert_token_to_url token,tmpurl
      
        buildid = log.url.match(/builds\/([0-9]+)\/logs/)[1]
        logid = log.url.match(/logs\/([0-9]+)/)[1]

        option =
          directory:"./cache/vso/"
          filename:"Log_VSTS_#{buildid}_#{logid}.txt"
         
        text = request('GET',tmpurl).getBody('utf8')
        obj =
          content:text
          filetype:'text'
          title:option.filename
          channels:'#general'

        slackup.uploadFile obj, (er) ->
          throw er if er
          console.log 'done'

      return true
    return false

  robot.respond /vso pull request( -s ([^-]+) -t ([^-\x20]+))( -title "([^\"]+)")?( -d "([^\"]+)")?( -r(( [a-zA-Z\-]+)+))?/, (res) ->
    token = get_token res
    pid = get_pid res
    tid = get_tid res
    config = user_config res
    repo = config.repo

    console.log res.match
    if repo is undefined
      res.send "Please set your repo first!"
      return

    repourl = insert_token_to_url token,repo.url
    repourl = repourl + "/pullRequests?#{APIv1p1}"

    probj = {
      sourceRefName:"refs/heads/" + res.match[2]
      targetRefName:"refs/heads/" + res.match[3]
      title:"Auto Generate PR"
      description:"Generate by slack team bot."
      reviewers:[
        {
          id:tid
        }
      ]
    }

#   Set PR details
    if res.match[4] isnt undefined
      probj.title = res.match[5]
    if res.match[6] isnt undefined
      probj.description = res.match[7]
    if res.match[8] isnt undefined
      teamurl = "https://#{instance}/DefaultCollection/_apis/projects/#{pid}/teams/#{tid}/members?#{APIv1}"
      teamurl = insert_token_to_url token,teamurl
      info = JSON.parse request('GET',teamurl).getBody('utf8')

      fail = ""

      teamconfig = user_config "common"
      teamId = []
      teamEmail = []
      teamAlias = []
      for item in teamconfig.team_members
        teamAlias.push item.alias
      
      for item in info.value
        teamId.push item.id
        teamEmail.push item.uniqueName
      for alias in res.match[9].split(' ')

        if alias is ''
          continue
        email = alias + "@microsoft.com"
        index = teamEmail.indexOf(email)

        if index is -1
          if fail is ""
            fail = fail + alias
          else
            fail = fail + "," + alias
        else
          probj.reviewers.push {
            id:teamId[index]
          }
        
        
      if fail isnt ""
        fail = fail + " are not vaild alias, they will not be added to reviewers."
        res.send fail

    info = request('POST',repourl,{
      json:probj
    }).getBody('utf8')

    info = JSON.parse info
    if info.message isnt undefined
      res.send "Error #{info.message}"
    else
      url = "https://#{instance}/#{config.project.name}/#{config.team.name}/_git/#{config.repo.name}/pullRequest/#{info.pullRequestId}"
      url = url.replace(/\x20/g,"%20")
      res.send "Succeed, click the following url to check your pull request.\n#{url}"
      
      if res.match[8] isnt undefined
        for alias in res.match[9].split(' ')
          index = teamAlias.indexOf(alias)
          if index isnt -1
            slack.api.chat.postMessage ({
              channel:"@#{teamconfig.team_members[index].name}"
              text:"#{res.message.user.name} has sent a pull request and invited you as reviewer."
              as_user:true
            }), (err) ->
              throw err if err


