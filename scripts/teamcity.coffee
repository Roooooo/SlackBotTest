# DescriptioODn : Deal with teamcity issue
# @author     : t-jiyunz@microsoft.com

parseString = require 'xml2js'
CronJob = require('cron').CronJob
request = require 'sync-request'
bobbin = require 'bobbin'

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

  username = "redmond.corp.microsoft.com%5Cvscsats"
  password = "China2016%40VisualStudio"
  DomainList = [
    "epxprofilebuild"
    "msdnbuild"
    "msdndeploy"
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
  #projurl = "#{authurl}/app/rest/projects/#{projname}"
  #buildconfurl = "#{authurl}/app/rest/buildTypes/#{buildname}"
  BuildConfListURL = "#{authurl}/app/rest/buildTypes"
  BuildRun = "#{authurl}/app/rest/builds?locator=buildType:"
  BuildQueueLocator = "#{authurl}/app/rest/buildQueue?locator=buildType:"
  BuildQueue = "#{authurl}/app/rest/buildQueue"
  Add2Que = "#{authurl}/action.html?add2Queue="

  refreshURL = () ->
    console.log domain
    ServerURL = "http://#{username}:#{password}@#{domain}"
    authurl = "http://#{username}:#{password}@#{domain}/httpAuth"
    #projurl = "#{authurl}/app/rest/projects/#{projname}"
    #buildconfurl = "#{authurl}/app/rest/buildTypes/#{buildname}"
    BuildConfListURL = "#{authurl}/app/rest/buildTypes"
    BuildRun = "#{authurl}/app/rest/builds?locator=buildType:"
    BuildQueueLocator = "#{authurl}/app/rest/buildQueue?locator=buildType:"
    BuildQueue = "#{authurl}/app/rest/buildQueue"
    Add2Que = "#{authurl}/action.html?add2Queue="

  domain_field = 3
  op_field = domain_field + 1

  general_build_xml = (id) ->
    "<build><buildType id=\"" + id + "\"\/><\/build>"
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

    BuildConfList = xml.match(/<buildType\x20id=([^>]+)>/g)
    for BuildConf in BuildConfList
      for i in [0...DisplayNum]
        pattern = BuildConfPattern[i]
        dim = PatternDim[i]
        tmp = BuildConf.match(pattern)
        if tmp is null
          Info = Info + "#{dim} : Undefined\t"
        else
          Info = Info + "#{dim} : #{tmp[1]}\t"
      Info = Info + "\n"
    res.send Info

# Test if its a valid domain
  test_domain = (inp) ->
    olddomain = domain
    domain = inp
    refreshURL()
    flag = false
    robot.http(BuildConfListURL).get() (err,r,info) ->
      console.log err
      console.log /<\/buildTypes>/.test(info)
      if err is null and /<\/buildTypes>/.test(info)
        flag = true
      domain = olddomain
      refreshURL()
      console.log "test" + flag
      return flag

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

#  robot.respond /refresh$/, (res) ->
#    refreshList()

# Get a list of build configuration
  robot.respond /ls(\s(\?|(-[\w\d?]+)))*$/, (res) ->
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
      info = request('GET',BuildConfListURL).getBody('utf8')
      get_build_list(info,res,dispAll)


# Check a build configuration's info by its id

  robot.respond /build\x20info\x20([a-zA-Z\d.-_]+)$/, (res) ->
    res.send "Checking build configuration " + res.match[1]
    tmpURL = BuildConfListURL + "/" + res.match[1]
    res.send get_build_list(request('GET',tmpURL).getBody('utf8'),res,true)

# Build a configuration spcified by its id

  robot.respond /build\x20asdasd([a-zA-Z\d.-_\/]+)$/, (res) ->
    res.send "Building " + res.match[1]
    console.log res.match[1]
    if /\//.test(res.match[1]) is true
      olddomain = domain
      tmpdomain = res.match[1].match(/^([^\/]+)\//)
      console.log tmpdomain
      if tmpdomain isnt null and test_domain(tmpdomain[1])
        domain = tmpdomain[1]
        refreshURL()
        id = res.match[1].match(/\/(.*)$/)
        if id is null or id[1] not in get_current_buildid()
          res.send "Incorrect build id."
          return
        robot.http("#{Add2Que}#{id[1]}").get() (err,r,info) ->
          if err isnt null
            get_error_msg err,r,res
          else
            res.send "Build success."
        domain = olddomain
        refreshURL()

      else
        res.send "Incorrect domain. Try again please."

      return

    if res.match[1] not in get_current_buildid()
      res.send "Incorrect build id."
      return
    robot.http("#{Add2Que}#{res.match[1]}").get() (err,r,info) ->
      if err isnt null
        get_error_msg err,r,res
      else
        res.send "Build success."

# Build / Deploy a project

#channel = 'general'
  robot.respond /(build|deploy)\s(.*)$/, (res) ->
    channel = res.message.user.name
    console.log channel
    if refreshflag is false
      refreshList()
    op = res.match[0].split(" ")[1]
    slices = res.match[2].split("\"")
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
        for i in [0...ProjectList.length]
          for j in [0...BuildInfo[i].length]
            if BuildInfo[i][j][0] is id and BuildInfo[i][j][op_field] is op
              pos = j
              proj = i
              break
          if pos isnt -1
            break
        if pos is -1
          res.send "Unknown build id."
          return

        domain = BuildInfo[proj][pos][domain_field]
        refreshURL()
        
        do_build_and_check(robot,channel,id)
        res.send op + "ing..."
        return
      else if slices.length is 2
      # build by project name and branch name
        projname = slices[0]
        branchname = slices[1]
        proj = ProjectName.indexOf(projname)
        if proj is -1
          res.send "Unknown project name."
          return
        
        for row in BuildInfo[proj]
          if row[1] is branchname and row[op_field] is op
            domain = row[domain_field]
            refreshURL()
            do_build_and_check(robot,channel,row[0])
            res.send op + "ing..."
            return

        res.send "Unknown branch name : "+ branchname
        return
      else
        res.send "Incorrect command."
        return
    else if slices.length is 3
      # a pair of quotes
      projname = slices[0].match(/[\w\d.-_]+/)[0]
      branchname = slices[1]
      proj = ProjectName.indexOf(projname)
      if proj is -1
        res.send "Unknown project name : " + projname
        return
        
      for row in BuildInfo[proj]
        if row[1] is branchname and row[op_field] is op
          domain = row[domain_field]
          refreshURL()
          do_build_and_check(robot,channel,row[0])
          res.send op + "ing..."
          return

      res.send "Unknown branch name : " + branchname
      return
    else if slices.length is 5
      # two pairs of quotes
      # build by project name and branch name
      
      projname = slices[1]
      branchname = slices[3]
      proj = ProjectName.indexOf(projname)
      if proj is -1
        res.send "Unknown project name : "
        return
        
      for row in BuildInfo[proj]
        if row[1] is branchname and row[op_field] is op
          domain = row[domain_field]
          refreshURL()
          do_build_and_check(robot,channel,row[0])
          res.send op + "ing..."
          return

      res.send "Unknown branch name." + branchname
      return

    else
      res.send "Incorrect command."

  do_build_and_check = (robot, channel, id) ->
    data = general_build_xml(id)
    info = request('POST', BuildQueue, {
      'headers': {'Content-type':'application/xml'}
      body: data
    }).getBody('utf8')

    href = get_build_href(info)
    new CronJob('* */1 * * * *', check_href_method(robot,channel,href), null,true)
    return

  check_href_method = (robot, channel, href) ->
    href = ServerURL + href
    -> if check_href(robot, channel, href) is true
      this.stop()
      
  check_href = (robot, channel, href) ->
    console.log href
    info = request('GET',href).getBody('utf8')
    status = info.match(/state="[^"]+"/)[0].split("\"")[1]
    console.log status
    if status is "finished"
      robot.messageRoom "t-jiyunz", "Your build has finished."
      return true
    return false

  get_build_href = (data) ->
    data.match(/href="[^"]+"/)[0].split("\"")[1]
