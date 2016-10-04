
module.exports = (robot) ->

  enterReplies = ['Hi', 'Target Acquired', 'Firing', 'Hello friend.', 'Gotcha', 'I see you']
  leaveReplies = ['Are you still there?', 'Target lost', 'Searching']

  robot.enter (res) ->
    res.send res.random enterReplies
  robot.leave (res) ->
    res.send res.random leaveReplies

  robot.router.get '/hubot/start-standup', (req, res) ->
    room = robot.adapter.client.rtm.dataStore.getDMByName "drewp"
    robot.messageRoom room.id, "yo"
    res.send 'OK'

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE"
