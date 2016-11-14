

numbersAsWords = {
  'zero': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10
}

ordinalMapping = {
  1: 'first',
  2: 'second',
  3: 'third',
  4: 'fourth',
  5: 'fifth',
  6: 'sixth',
  7: 'seventh',
  8: 'eigth',
  9: 'ninth',
  10: 'tenth',
}

replaceTokens = (messages, repeatCount) ->
  followups = []
  for j in [0...repeatCount]
    number = j + 1
    ordinal = ordinalMapping[number]
    for i in [0...messages.length]
      message = messages[i]
      message = message.replace(new RegExp("{number}", 'g'), number)
      message = message.replace(new RegExp("{ordinal}", 'g'), ordinal)
      followups.push message

  return followups

questionModelFactory = (question) ->
  returnModel = {
    getQuestion: () -> question
    answerCallback: null
    # answerCallback: {
    #   status: "fail"
    #   followups: ["Why'd you do that?"]
    #   OR
    #   status: "success"
    #   followups: [
    #   ]
    # }
  }

  if not (typeof question == 'string' || question instanceof String)
    questionType = question.questionType

    returnModel.getQuestion = () -> question.question

    if questionType == 'repeated-followup'
      returnModel.answerCallback = (answers) ->
        lastAnswer = answers[answers.length - 1]
        parsedAnswer = parseInt(lastAnswer)
        if numbersAsWords[lastAnswer]
          parsedAnswer = numbersAsWords[lastAnswer]
        else if parsedAnswer < 0 || isNaN(parsedAnswer)
          return {
            status: "fail"
            followups: ["That's not a number, try one or 1"]
          }

        tokenizedFollowUps = replaceTokens(question.followups, parsedAnswer)
        return {
          status: 'success'
          followups: tokenizedFollowUps.map(questionModelFactory)
        }
  return returnModel

module.exports = questionModelFactory
