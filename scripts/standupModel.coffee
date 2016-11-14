
questionModelFactory = require('./questionModel')

STATUS_KEY = 'statuses'

module.exports = (brain, questions) ->
  reset = () -> brain.set STATUS_KEY, null

  all = () ->
    current = brain.get STATUS_KEY
    return current ? {}

  startStandupWithUser = (userId) ->
    model = forUser userId
    for question in questions
      model.questions.push questionModelFactory(question)
    setUser userId, model

  lastMessageReceivedForUser = (userId) ->
    currentUserAnswers = forUser userId
    return currentUserAnswers.lastAnswerTimestamp

  currentAnswersForUser = (userId) ->
    currentAnswers = forUser userId
    currentAnswersForQuestion = currentAnswers.answers[currentAnswers.currentQuestion] ? []
    return currentAnswersForQuestion

  recordMessageReceivedForUser = (userId, msg) ->
    model = forUser userId
    currentAnswersForQuestion = currentAnswersForUser userId
    currentAnswersForQuestion.push msg

    model.answers[model.currentQuestion] = currentAnswersForQuestion
    model.lastAnswerTimestamp = new Date().getTime()

    setUser userId, model

    return model.lastAnswerTimestamp

  recordAnswerForUser = (userId) ->
    model = forUser userId
    questionModel = model.questions[model.currentQuestion]
    answers = currentAnswersForUser userId
    if questionModel.answerCallback != null
      response = questionModel.answerCallback(answers)
      followups = response.followups
      if response.status == 'success'
        model.currentQuestion += 1
        model.questions.splice.apply(model.questions, [model.currentQuestion, 0].concat(followups));
        setUser userId, model
      else
        return followups
    else
      model.currentQuestion += 1

    return null


  setUser = (userId, model) ->
    current = all()
    current[userId] = model
    brain.set STATUS_KEY, current

  forUser = (userId) ->
    currentAnswers = all()
    return currentAnswers[userId] ? {
      questions: []
      answers: []
      responses: []
      lastAnswerTimestamp: null
      currentQuestion: 0
    }

  userIsDone = (userId) ->
    model = forUser userId
    return model.currentQuestion == model.questions.length

  nextQuestionForUser = (userId) ->
    if not userIsDone userId
      model = forUser userId
      questionModel = model.questions[model.currentQuestion]
      return questionModel.getQuestion()

    return null

  finalReportForUser = (userId) ->
    if !userIsDone userId
      return null

    mappedAnswers = [] # list of tuples of answers
    model = forUser userId
    for i in [0...model.answers.length]
      question = model.questions[i].getQuestion()
      answer = model.answers[i]
      mappedAnswers.push([question, answer])

    return mappedAnswers

  return {
    reset,
    all,
    startStandupWithUser,
    recordAnswerForUser,
    recordMessageReceivedForUser,
    lastMessageReceivedForUser,
    forUser,
    userIsDone,
    nextQuestionForUser,
    finalReportForUser
  }
