
defaultConfig = require('../default-config.json')

standupModelFactory = require('./standupModel')

configFile = process.env.HUBOT_STANDUP_CONFIG_FILE || null
config = {}
if configFile?
  try
    config = require(configFile)
  catch
    robot.logger.error "can't load config"

extend = (object, properties) ->
  for key, val of properties
    object[key] = val
  object

merge = (options, overrides) ->
  extend (extend {}, options), overrides

module.exports = (robot) ->
  config = merge defaultConfig, config

  standupModel = standupModelFactory robot.brain, config.questions

  randomMessage = (possibleMessages) ->
    index = Math.floor(Math.random() * possibleMessages.length)
    return possibleMessages[index]

  startStandupWithUser = (userName) ->
    robot.messageRoom "@" + userName, config.questions[0]
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
    # post the message
    robot.messageRoom "standup", msgData

  robot.listen(
    # Matcher
    (message) ->
      userId = message.user.id
      userRoom = message.user.room
      room = message.room
      if !standupModel.userIsDone userId and room == userRoom and message.text?
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
          receivedTimestamp = standupModel.recordAnswerForUser userId
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
        userNames = []
        for member in data.members
          userName = member.name
          if !member.deleted && !member.is_bot && config.excludedUsers.indexOf(userName) == -1
            userNames.push(member.name)

        callback(userNames)
      else
        robot.logger.error data
    )

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
