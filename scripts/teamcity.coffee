# Description : Deal with teamcity issue
# @author     : t-jiyunz@microsoft.com

CronJob = require('cron').CronJob
request = require 'sync-request'
fs = require 'fs'

download = require 'download-file'

AuthInfo = "user.txt"

token = process.env.HUBOT_SLACK_TOKEN || ''
SlackClient = require 'slack-api-client'
slack = new SlackClient(token)
SlackUpClient = require 'node-slack-upload'
slackup = new SlackUpClient(token)

module.exports = (robot) ->

  get_username = (response) ->
    "@#{response.message.user.name}"

  get_channel = (response) ->
    if response.message.room is response.message.user.name
      "@#{response.message.room}"
    else
      "##{response.message.room}"

  ErrMsg = "An error has occured :"
  ErrStatus = "Error status code :"
  
  get_error_msg = (err, rcode, res) ->
    res.send "An error has occured : #{err}"
    if rcode isnt null
      res.send "Error status code : #{rcode.statuscode}"

  authInfo = ->
    fs.readFileSync AuthInfo, 'utf8'
  username = authInfo().match(/username="(.*)"/)[1]
  password = authInfo().match(/password="(.*)"/)[1]

  DomainList = [
    "epxprofilebuild"
    "msdnbuild"
    "msdndeploy"
    "profileautomation"
    "galleriesautomation"
    "forumsautomation"
  ]
  ProjectList = [
    /profile/i
    /forumsapi/i
    /forum/i
    /widget/i
    /recognition/i
    /galleries/i
    /wiki/i
    /slack/i
  ]
  ProjectName = [
    "profile"
    "forumsapi"
    "forum"
    "widget"
    "recognition"
    "galleries"
    "wiki"
    "test"
  ]
  BuildInfo = []
  
  domain = DomainList[0]

  refreshflag = false
  
  ServerURL = "http://#{username}:#{password}@#{domain}"
  authurl = "http://#{username}:#{password}@#{domain}/httpAuth"
  BuildConfListURL = "#{authurl}/app/rest/buildTypes"
  BuildRun = "#{authurl}/app/rest/builds?locator=buildType:"
  BuildQueueLocator = "#{authurl}/app/rest/buildQueue?locator=buildType:"
  BuildQueue = "#{authurl}/app/rest/buildQueue"
  Add2Que = "#{authurl}/action.html?add2Queue="

  refreshURL = () ->
    console.log domain
    ServerURL = "http://#{username}:#{password}@#{domain}"
    authurl = "http://#{username}:#{password}@#{domain}/httpAuth"
    BuildConfListURL = "#{authurl}/app/rest/buildTypes"
    BuildRun = "#{authurl}/app/rest/builds?locator=buildType:"
    BuildQueueLocator = "#{authurl}/app/rest/buildQueue?locator=buildType:"
    BuildQueue = "#{authurl}/app/rest/buildQueue"
    Add2Que = "#{authurl}/action.html?add2Queue="

  domain_field = 3
  op_field = domain_field + 1

  generate_build_xml = (id, paramlist) ->
    xml = "<buildType id=\"" + id + "\"\/>"


    if paramlist isnt []
      xml = xml + "<properties>"
      for param in paramlist
        xml = xml + "<property name=\"#{param.key}\" value=\"#{param.value}\"\/>"
      xml = xml + "<\/properties>"

    "<build>" + xml + "<\/build>"

# Parse the xml and display build configurations info
# To see the description and projectId , use ls -a

  get_build_list = (xml, res, dispAll) ->
    BuildNumber = xml.match(/<buildTypes\x20count="(\d+)[^>]+>/g)[0].match(/\d+/g)[0]
    res.send "There are #{BuildNumber} build configurations."

    Info = ""

    # The patterns and the domain names accordingly
    BuildConfPattern = [
      /id="([^"]+)"/,
      /name="([^"]+)"/,
      /projectName="([^"]+)"/,
      /description="([^"]+)"/,
      /projectID="([^"]+)"/
    ]
    PatternDim = [
      "id",
      "name",
      "projectName",
      "description",
      "projectID"
    ]
    
    # The number of items to display
    DisplayNum = 3
    if dispAll is true
      DisplayNum = 5

    attachments = []

    BuildConfList = xml.match(/<buildType\x20id=([^>]+)>/g)
    for BuildConf in BuildConfList
      buildobj = {
        pretext:"",
        fields:[]
      }
      for i in [0...DisplayNum]
       
        pattern = BuildConfPattern[i]
        dim = PatternDim[i]
        tmp = BuildConf.match(pattern)
        buildobj.fields.push {
          title:dim,
          short:true
        }
        if tmp is null
          Info = Info + "#{dim} : Undefined\t"
      #    buildobj.fields[i].value = "Undefined."
        else
          Info = Info + "#{dim} : #{tmp[1]}\t"
      #    buildobj.fields[i].value = tmp[1]
      Info = Info + "\n"
      #attachments.push buildobj
    res.send Info
    #console.log attachments
    #slack.api.chat.postMessage ({
    #  channel:get_username res,
    #  text:"Text",
    #  attachments:JSON.stringify attachments,
    #  as_user:true
    #}), (e,r) ->
    #  throw e if e

# Get a list of build-ids on current domain
  get_current_buildid = () ->
    cur_buildid = []
    robot.http(BuildConfListURL).get() (err,r,info) ->
      if err isnt null
        return
      list = info.match(/id="[^"]+)"/g)
      if list isnt null
        for item in list[0..-2]
          cur_buildid.push(item)
    return cur_buildid

# Get the list of build configuration infomation

  refreshList = () ->
    for i in [0...ProjectList.length]
      BuildInfo[i] = []
    for item in DomainList
      domain = item
      console.log domain
      refreshURL()
      info = request('GET',BuildConfListURL).getBody('utf8')
      IdList = info.match(/id="[^"]+(?=")/g)
      NameList = info.match(/name="[^"]+(?=")/g)
      ProjectNameList = info.match(/projectName="[^"]+(?=")/g)
      List = [IdList, NameList, ProjectNameList]
      for i in [0...IdList.length]
        id = IdList[i].split("\"")[1]
        name = NameList[i].split("\"")[1]
        pname = ProjectNameList[i].split("\"")[1]
        str = id + "|" + name + '|' + pname
        for j in [0...ProjectList.length]
          if str.match(ProjectList[j])
            if domain is "msdndeploy" or str.match(/deploy/i) isnt null
              BuildInfo[j].push([id,name,pname,item,"deploy"])
            else
              BuildInfo[j].push([id,name,pname,item,"build"])
            break
    refreshflag = true

  msg_queue = []
  msg_oldest = 0

  msg_track_method = (channel_list,im_list) ->
    console.log "test"
    console.log channel_list
    console.log im_list
    -> msg_loop(channel_list,im_list)

  msg_loop = (channel_list,im_list) ->
    msg_collect(channel_list,im_list)
    msg_process()

  msg_collect = (channel_list,im_list) ->
    console.log "collecting"
    tmp_oldest = msg_oldest
    for channel in channel_list
      param =
        channel:channel.id
        oldest:tmp_oldest
        count:1000
      slack.api.channels.history (param), (err, ret) ->
        if ret.messages isnt undefined and ret.messages.length isnt 0
          msg_oldest = Math.max(ret.messages[0].ts,msg_oldest)
          for msg in ret.messages
            if msg.type is "message"
              msg_queue.push msg

    for channel in im_list
      param =
        channel:channel.id
        oldest:tmp_oldest
        count:1000
      slack.api.im.history (param), (err,ret) ->
        if ret.messages isnt undefined and ret.messages.length isnt 0
          msg_oldest = Math.max(ret.messages[0].ts,msg_oldest)
          for msg in ret.messages
            if msg.type is "message"
              msg.channel = param.channel
              msg_queue.push msg
  
  msg_process = () ->
    console.log "processing"
    while msg_queue.length isnt 0
      msg = msg_queue.shift()
      console.log msg
      if msg.text.match(/teamcity\s+(build|deploy)\s+([^-]+)(\s+-p((\s+([0-9a-zA-Z\._-]+)=([0-9a-zA-Z\._-]+))+))?$/)
        
        param = msg.text.match(/teamcity\s+(build|deploy)\s+([^-]+)(\s+-p((\s+([0-9a-zA-Z\._-]+)=([0-9a-zA-Z\._-]+))+))?$/)
        queue_build(param,msg.channel,msg.user)

  slack.api.channels.list ({}), (err, ret) ->
    throw err if err
    channel_list = []
    general_id = undefined
    for channel in ret.channels
      channel_list.push {
        id:channel.id
        name:channel.name
      }
      if channel.name is "general"
        general_id = channel.id
    slack.api.im.list (e,r) ->
      throw e if e
      im_list = []
      for im in r.ims
        im_list.push {
          id:im.id
          name:im.user
        }
      slack.api.chat.postMessage ({
        channel:"#general"
        text:"Bot is working now."
        as_user:true
      }), (err1, ret1) ->
        throw err1 if err1
        slack.api.channels.history ({
          channel:general_id
        }), (err2,ret2) ->
          throw err2 if err2
          for msg in ret2.messages
            if msg.text = "Bot is working now."
              msg_oldest = msg.ts
              break
          msg_tracking = new CronJob('*/30 * * * * *', msg_track_method(channel_list,im_list),null, true)

  #Get a list of build configuration
  robot.respond /teamcity ls(\s(\?|(-[\w\d?]+)))*$/, (res) ->
    dispAll = false
  
    if res.match[0].match(/ls\s(.*)$/) isnt null
      OpList = res.match[0].match(/ls\s(.*)$/)[1].match(/[/\w\d?]/g)

      for op in OpList
        if op is 'a'
          dispAll = true
        else if op is '?'
          res.send "ls [-a]\n
\t\tDisplay all of the build configurations' id, name and project name in current url.\n\n
-a\tDisplay projectID and description.\n"
          return
        else
          res.send "Unknown option -#{op}. Try \"ls ?\" instead."
          return

    for item in DomainList
      domain = item
      refreshURL()
      console.log BuildConfListURL
      info = request('GET',BuildConfListURL).getBody('utf8')
      get_build_list(info,res,dispAll)

# Check a build configuration's info by its id

  robot.respond /teamcity\s+ls\s+build\s+info\s+([0-9a-zA-Z\d.-_]+)$/, (res) ->
    if refreshflag is false
      refreshList()

    buildid = res.match[1]
    newdomain = find_domain buildid
    if newdomain is undefined
      res.send "Unknown build id."
      return
    domain = newdomain
    refreshURL()

    res.send "Checking build configuration " + res.match[1]
    tmpURL = BuildConfListURL + "/id:" + res.match[1] + "/parameters"
    info = request('GET',tmpURL).getBody('utf8')
    params = info.match(/<property([^>]+)\/>/g)
    selections = info.match(/<property([^>]+)><type([^>]+)><\/property>/g)
    attachments =[]
    for param in params
      paramobj =
        fields:[]
        pretext:""
      name = param.match(/name=\"([\w\d\._-]+)\"/)
      defaultvalue = param.match(/value=\"([^\"]*)\"/)
      if name is undefined or defaultvalue is undefined
        continue
      if defaultvalue[1] is ""
        defaultvalue[1] = "undefined"
      paramobj.fields.push build_attach_obj "Property",name[1],true
      paramobj.fields.push build_attach_obj "Default value",defaultvalue[1], true

      attachments.push paramobj

    for param in selections
      paramobj =
        pretext:""
        fields:[]
      
      name = param.match(/name=\"([\w\d\.-_]+)\"/)
      defaultvalue = param.match(/value=\"([^\"]*)\"/)
      value = param.match(/rawValue=\"([\w\d\.-_=\'\s]+)\"/)
      if name is undefined or value is undefined or defaultvalue is undefined
        continue
      if defaultvalue[1] is ""
        defaultvalue[1] = "undefined"
      value = value[1].match(/data_\d+=\'([^\']+)\'/g)
      msg = ""
      for item in value
        param = item.match(/\'(.*)\'/)
        if msg isnt ""
          msg = msg + ","
        msg = msg + param[1]

      paramobj.fields.push build_attach_obj "Property",name[1],true
      paramobj.fields.push build_attach_obj "Default value",defaultvalue[1],true
      paramobj.fields.push build_attach_obj "Options",msg,false
      attachments.push paramobj

    channel = get_channel res
    slack.api.chat.postMessage ({
      channel:channel
      text:"123123"
      attachments:JSON.stringify attachments
      as_user:true
    }), (e,r) ->
      throw e if e
    
    res.send info

  find_domain = (buildid) ->
    if refreshflag is false
      refreshList()

    for i in [0...ProjectList.length]
      for j in [0...BuildInfo[i].length]
        if BuildInfo[i][j][0] is buildid
          return BuildInfo[i][j][domain_field]
    return undefined

  build_attach_obj = (title, value, short) ->
    {
      title:title
      value:value
      short:short
    }
# Build / Deploy a project

#robot.respond /teamcity\s+(build|deploy)\s+([^-]+)(\s+-p((\s+([0-9a-zA-Z\._-]+)=([0-9a-zA-Z\._-]+))+))?$/, (res) ->
  queue_build = (cmd,channel,user) ->
    console.log cmd
    if refreshflag is false
      refreshList()

    paramlist = []
    params = cmd[4].split(/\s+/) if cmd[4]?
    if params
      for param in params
        if param isnt ''
          param = param.split('=')
          paramlist.push {
            key:param[0]
            value:param[1]
          }

    op = cmd[1]
    slices = cmd[2].split("\"")
    if slices.length is 1
      # no quotes
      # build by build-id
      slices = slices[0].split(" ")
      console.log slices
      if slices.length is 1
        id = slices[0]
        console.log id
  
        pos = -1
        proj = -1
        console.log "id" + id
        console.log "op" + op
        for i in [0...ProjectList.length]
          for j in [0...BuildInfo[i].length]
            console.log BuildInfo[i][j][0]
            console.log BuildInfo[i][j][op_field]
            if BuildInfo[i][j][0] is id and BuildInfo[i][j][op_field] is op
              pos = j
              proj = i
              break
          if pos isnt -1
            break
        if pos is -1
          post_msg channel, "Unknown build id."
          return

        domain = BuildInfo[proj][pos][domain_field]
        refreshURL()
        
        do_build_and_check(user,id,paramlist)
        post_msg channel,(op + "ing...")
        return
      else if slices.length is 2
      # build by project name and branch name
        projname = slices[0]
        branchname = slices[1]
        proj = ProjectName.indexOf(projname)
        if proj is -1
          post_msg channel,"Unknown project name."
          return
        
        for row in BuildInfo[proj]
          if row[1] is branchname and row[op_field] is op
            domain = row[domain_field]
            refreshURL()
            do_build_and_check(user,row[0],paramlist)
            post_msg channel,(op + "ing...")
            return

        post_msg channel,("Unknown branch name : "+ branchname)
        return
      else
        post_msg channel, "Incorrect command."
        return
    else if slices.length is 3
      # a pair of quotes
      projname = slices[0].match(/[\w\d.-_]+/)[0]
      branchname = slices[1]
      proj = ProjectName.indexOf(projname)
      if proj is -1
        post_msg channel,("Unknown project name : " + projname)
        return
        
      for row in BuildInfo[proj]
        if row[1] is branchname and row[op_field] is op
          domain = row[domain_field]
          refreshURL()
          do_build_and_check(user,row[0],paramlist)
          post_msg channel,(op + "ing...")
          return

      post_msg channel,("Unknown branch name : " + branchname)
      return
    else if slices.length is 5
      # two pairs of quotes
      # build by project name and branch name
      
      projname = slices[1]
      branchname = slices[3]
      proj = ProjectName.indexOf(projname)
      if proj is -1
        post_msg channel,("Unknown project name : ")
        return
        
      for row in BuildInfo[proj]
        if row[1] is branchname and row[op_field] is op
          domain = row[domain_field]
          refreshURL()
          do_build_and_check(user,row[0],paramlist)
          post_msg channel,(op + "ing...")
          return

      post_msg channel,("Unknown branch name." + branchname)
      return

    else
      post_msg channel,("Incorrect command.")

  do_build_and_check = (user, id, paramlist) ->
    data = generate_build_xml id, paramlist
    info = request('POST', BuildQueue, {
      'headers': {'Content-type':'application/xml'}
      body: data
    }).getBody('utf8')
    href = get_build_href info
    num = href.split("id:")[1]
    new CronJob('0 */1 * * * *', check_href_method(user,href), null,true)
    return

  check_href_method = (user, href) ->
    channel = user
    href = ServerURL + href
    serverURL = ServerURL
    -> if check_href(channel, href, serverURL) is true
      this.stop()
      
  check_href = (channel, href, serverURL) ->
    console.log channel
    console.log href
    info = request('GET',href).getBody('utf8')
    status = info.match(/state="[^"]+"/)[0].split("\"")[1]

    statURL = info.match(/statistics\x20href="[^"]+"/)
    if statURL isnt null
      statURL = serverURL + statURL[0].split("\"")[1]
      stat = request('GET',statURL).getBody('utf8')
      buildTime = stat.match(/BuildDuration" value="[^"]+"/)
      if buildTime is null
        console.log "Not found build time."
      else
        buildTime = parseInt(buildTime[0].split("\"")[2])/1000
        slack.api.chat.postMessage ({
          channel:channel,
          text:"Have used #{buildTime}s on building.",
          as_user:true
        }), (err, ret) ->
          throw err if err
    if status is "finished"
      slack.api.chat.postMessage ({
        channel:"#general"
        text:"Your build has finished."
        as_user:true
      }), (err,ret) ->
        throw err if err
        buildId = href.match(/id:([0-9]+)/)[1]
        logurl = serverURL + "/httpAuth/downloadBuildLog.html?buildId=#{buildId}"
        option =
          directory:"./cache/"
          filename:"Log_#{buildId}.txt"
        download logurl, option, (e) ->
          throw e if e
          content = fs.readFileSync(option.directory+option.filename, 'utf8')
          obj = {
            content:content
            filetype:'text'
            #  title:option.filename
            channels:'#general'
          }
          slackup.uploadFile obj, (er) ->
            throw er if er
            console.log 'done'
      return true
    return false

  post_msg = (channel,text) ->
    slack.api.chat.postMessage ({
      channel:channel
      text:text
      as_user:true
    }), (err, ret) ->
      throw err if err
      
  get_build_href = (data) ->
    console.log data
    data.match(/href="[^"]+"/)[0].split("\"")[1]

  ls_build_param = (res,id) ->
    parameterURL = ServerURL + "/httpAuth/app/rest/builds/id:#{id}/resulting-properties"
    console.log parameterURL
    info = request('GET',parameterURL).getBody('utf8')
    console.log info
