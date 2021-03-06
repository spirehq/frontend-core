Transformations["Issue"] = (object) -> Transformations.static(Issues.Issue, object)
Issues = Collections["Issue"] = new Mongo.Collection("Issues", {transform: if Meteor.isClient then Transformations.Issue else null})

class Issues.Issue
  constructor: (doc) ->
    _.extend(@, doc)

IssuePreSave = (userId, changes) ->
  now = new Date()
  changes.updatedAt = changes.updatedAt or now

Issues.before.insert (userId, Issue) ->
  Issue._id ||= Random.id()
  now = new Date()
  _.autovalues(Issue,
    reason: "" # this will become a code string passed to i18n, currently it's passed displayed on the page in plain text
    details: {}
    taskToken: "" # optional
    commandId: ""
    stepId: ""
    userId: userId
    updatedAt: now
    createdAt: now
  )
#  throw new Meteor.Error("Issue:recipeId:empty", "Issue::recipeId is empty", Issue) if not Issue.recipeId
#  throw new Meteor.Error("Issue:taskId:empty", "Issue::taskId is empty", Issue) if not Issue.taskId
  throw new Meteor.Error("Issue:stepId:empty", "Issue::stepId is empty", Issue) if not Issue.stepId
  throw new Meteor.Error("Issue:userId:empty", "Issue::userId is empty", Issue) if not Issue.userId
  IssuePreSave.call(@, userId, Issue)
  true

Issues.before.update (userId, Issue, fieldNames, modifier, options) ->
  modifier.$set = modifier.$set or {}
  IssuePreSave.call(@, userId, modifier.$set)
  true
