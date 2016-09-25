# Slack Team Bot

Slack Team Bot is a bot intended for team work automation. It integrates the main function of Visual Studio Team Service and Teamcity. With slack commands, you can access to the main function on these sites without open a new page.

### Environment

* Ubuntu 16.04 LTS
* Node.js v4.2.6

### Installation

0. Pull code from [here][https://mseng.visualstudio.com/vschina/app experience/_git/msdn.buildnotification].

1. Install npm with
```
apt-get install npm
```

2. Install related package
```
npm install cron
npm install sync-request
npm install slack-api-client
npm install node-slack-upload
npm install download-file
```

3.Run the bot with your slack team bot token. FYI, you may not upload your slack token to anywhere on Internet, otherwise slack will force you to renew your token.
```
CONFIG_DIF="config/team/" HUBOT_SLACK_TOKEN=xoxb-********-****************** ./bin/hubot
```

### Scripting

There have been 4 scripts under `scripts/`. `teamcity.coffee` and `vso.coffee` is mainly used for integration with VSO and teamcity. `config.coffee` include several commands on config file operation. `daliy.coffee` is used for test and you can treat it as a simple example if you are new to hubot.

You may add new functions with add new script under `scripts/`. All the scripts under `scripts/` will be run automatically by hubot.