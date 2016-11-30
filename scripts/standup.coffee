
defaultConfig = require('../default-config.json')

standupModelFactory = require('./standupModel')


extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

merge = (options, overrides) ->
  extend (extend {}, options), overrides

module.exports = (robot) ->
  configJSONstr = process.env.HUBOT_STANDUP_CONFIG || null
  config = {}
  if configJSONstr?
    try
      config = JSON.parse(configJSONstr)
    catch
      robot.logger.error "can't load config"
      return

  config = merge defaultConfig, config

  standupModel = standupModelFactory robot.brain, config.questions

  randomMessage = (possibleMessages) ->
    index = Math.floor(Math.random() * possibleMessages.length)
    return possibleMessages[index]

  startStandupWithUser = (user) ->
    standupModel.startStandupWithUser(user.id)
    firstQuestion = standupModel.nextQuestionForUser(user.id)
    userName = user.name
    robot.messageRoom "@" + userName, firstQuestion
    robot.messageRoom "@" + userName, randomMessage config.openings

  finalReportToSlackAttachmentFields = (report) ->
    fields = []
    for questionAnswerTuple in report
      question = questionAnswerTuple[0]
      answer = questionAnswerTuple[1].join("\n")
      fields.push
        title: question
        value: answer
        short: false

    return fields

  sendFinalReport = (userId, userName) ->
    finalReportData = standupModel.finalReportForUser userId
    descText = "@" + userName + "'s standup"
    msgData =
      channel: config.reportChannel
      text: descText,
      attachments: [
          {
              "fallback": descText,
              "color": "#e97824",
              "fields": finalReportToSlackAttachmentFields(finalReportData)
          }
      ]

    robot.messageRoom "standup", msgData

  robot.listen(
    # Matcher
    (message) ->
      userId = message.user.id
      userRoom = message.user.room
      room = message.room

      if room == userRoom && !standupModel.userIsDone userId
        return message.text.substring robot.name.length
      else
        return false
    # Callback
    (response) ->
      userId = response.envelope.user.id
      answer = response.match
      receivedTimestamp = standupModel.recordMessageReceivedForUser userId, answer
      setTimeout(() ->
        if receivedTimestamp == standupModel.lastMessageReceivedForUser(userId)
          failResponse = standupModel.recordAnswerForUser userId
          if failResponse != null
            for resp in failResponse
              response.reply resp

            return

          if standupModel.userIsDone userId
            response.reply randomMessage config.closings
            userName = response.envelope.user.name
            sendFinalReport userId, userName
          else
            response.reply standupModel.nextQuestionForUser userId

          response.reply randomMessage config.acknowledgements

      , config.responseTimeout)
  )

  getStandupUsers = (callback) ->
    robot.adapter.client.web.users.list().then((data) ->
      if data.members?
        users = []
        for member in data.members
          if !member.deleted && !member.is_bot && config.excludedUsers.indexOf(member.name) == -1
            users.push({name: member.name, id: member.id})

        callback(users)
      else
        robot.logger.error data
    )


robot.router.get '/hubot/test-standup', (req, res) ->    
    getStandupUsers (users) ->    
      for user in users   
        if user.name == 'drewp' || user.name == 'neel' || user.name == 'omkarbhat'    
          startStandupWithUser(user)    
     
    res.send 'OK'

  robot.router.get '/hubot/start-standup', (req, res) ->
    standupModel.reset()
    getStandupUsers((users) ->
      users.map startStandupWithUser
    )

    res.send 'OK'

  robot.router.get '/hubot/test-config', (req, res) ->
    standupModel.reset()

    res.send JSON.stringify(config)

  robot.error (err, res) ->
    robot.logger.error err
