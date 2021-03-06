AWS = Npm.require "aws-sdk"

# [dev] Meteor.settings.swf.options -> ./settings-local/dev.json (developers have their own AWS SWF credentials)
# [prod] Meteor.settings.swf.options -> ./settings/prod.json (client supplies general-purpose credentials)
check Meteor.settings.swf,
  domain: String
  accessKeyId: String
  secretAccessKey: String
  region: String

swf = new AWS.SWF _.extend
  apiVersion: "2012-01-25",
, Meteor.settings.swf
startWorkflowExecutionSync = Meteor.wrapAsync(swf.startWorkflowExecution, swf)
requestCancelWorkflowExecutionSync = Meteor.wrapAsync(swf.requestCancelWorkflowExecution, swf)

# Using "before" hook to ensure that SWF receives our request
Commands.before.insert (userId, command) ->
  step = Steps.findOne(command.stepId, {transform: Transformations.Step})
  _.extend command, step.insertCommandData() # an old version of client-side code might insert a Command in old format, so we need to override the Command data in server-side code
  Users.update(step.userId, {$inc: {executions: 1}})
  try
    user = Users.findOne(step.userId, {transform: Transformations.User})
    plan = user.plan()
#    TODO: comment out when we implement the "Choose your plan" step
#    if plan.executionsLimit and user.executions > plan.executionsLimit
#      throw new Meteor.Error(402, "Payment Required", EJSON.stringify({}))
    input = step.input(command)
    _.defaults input,
      commandId: command._id
      stepId: step._id
      userId: step.userId
    params =
      domain: step.domain()
      workflowId: command._id
      workflowType: step.workflowType()
      taskList: step.taskList()
      tagList: [ # not used in code, but helpful in debug
        command._id
        step._id
        step.userId
      ]
      input: JSON.stringify(input)
    if not command.isDryRunWorkflowExecution
      data = startWorkflowExecutionSync(params)
      command.runId = data.runId
  catch error
    Users.update(step.userId, {$inc: {executions: -1}}) # revert the update; this is better than fetch-and-check, because it prevents race conditions
    throw error
  true

Commands.before.remove (userId, command) ->
  step = Steps.findOne(command.stepId, {transform: Transformations.Step})
  if not command.isCompleted and not command.isFailed # cancelled by user; reimburse trial if command is cancelled by user
    Users.update(step.userId, {$inc: {executions: -1}})
  params =
    domain: step.domain()
    workflowId: command._id
  try
    if not command.isDryRunWorkflowExecution
      requestCancelWorkflowExecutionSync(params)
  catch error
    throw error if error.code isnt "UnknownResourceFault" # Workflow execution may have already been terminated
  true
