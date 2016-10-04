

STATUS_KEY = 'statuses'

module.exports = (brain, questions) ->
  reset = () -> brain.set STATUS_KEY, null

  all = () ->
    current = brain.get STATUS_KEY
    return current ? {}

  lastMessageReceivedForUser = (userId) ->
    currentUserAnswers = forUser userId
    return currentUserAnswers.lastAnswerTimestamp

  recordMessageReceivedForUser = (userId, msg) ->
    currentAnswers = forUser userId
    currentAnswersForQuestion = currentAnswers.answers[currentAnswers.currentQuestion] ? []

    currentAnswersForQuestion.push msg

    currentAnswers.answers[currentAnswers.currentQuestion] = currentAnswersForQuestion
    currentAnswers.lastAnswerTimestamp = new Date().getTime()

    setAnswersForUser userId, currentAnswers

    return currentAnswers.lastAnswerTimestamp

  recordAnswerForUser = (userId) ->
    currentUserAnswers = forUser userId
    currentUserAnswers.currentQuestion += 1
    setAnswersForUser userId, currentUserAnswers

  setAnswersForUser = (userId, answers) ->
    currentAnswers = all()
    currentAnswers[userId] = answers
    brain.set STATUS_KEY, currentAnswers

  forUser = (userId) ->
    currentAnswers = all()
    return currentAnswers[userId] ? {
      answers: []
      lastAnswerTimestamp: null,
      currentQuestion: 0
    }

  userIsDone = (userId) ->
    answers = forUser userId
    return answers.currentQuestion == questions.length

  nextQuestionForUser = (userId) ->
    if not userIsDone userId
      answers = forUser userId
      return questions[answers.currentQuestion]

    return null

  finalReportForUser = (userId) ->
    if !userIsDone userId
      return null

    mappedAnswers = [] # list of tuples of answers
    answers = forUser userId
    for i in [0...answers.answers.length]
      question = questions[i]
      answer = answers.answers[i]
      mappedAnswers.push([question, answer])

    return mappedAnswers

  return {
    reset,
    all,
    recordAnswerForUser,
    recordMessageReceivedForUser,
    lastMessageReceivedForUser,
    forUser,
    userIsDone,
    nextQuestionForUser,
    finalReportForUser
  }
