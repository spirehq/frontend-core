Transformations["Step"] = (object) -> Transformations.dynamic(Steps, Steps.Step, object)
Steps = Collections["Step"] = new Mongo.Collection("Steps", {transform: if Meteor.isClient then Transformations.Step else null})

# TODO: when removing the step, remove tasks associated with this step if they are not isDone

class Steps.Step
  constructor: (doc) ->
    _.extend(@, doc)
    @template or= @cls
    @i18nKey or= @cls
    @isSafe or= false # Step is considered "safe" if its Command execution doesn't overwrite or delete user data
  isCurrent: -> not @isCompleted and @isActive()
  isActive: -> not Steps.findOne({isCompleted: false, position: {$lt: @position}, recipeId: @recipeId})
  forAllNext: (callback) ->
# TODO: rewrite using dependency mechanics
    prev = @last
    while prev
      break if prev is @
      callback(prev)
      prev = prev.prev
  revertAllNext: ->
    @forAllNext (step) -> step.revert()
  changeAllNext: ->
    @forAllNext (step) -> step.change()
  execute: -> throw "Implement me!"
  revert: -> throw "Implement me!"
  change: -> Steps.update(@_id, {$set: {isCompleted: false}})
  input: (command) -> @recipe().input(@, command)
  progressBars: -> @recipe().progressBars(@)
  domain: ->
    Meteor.settings.swf.domain
  workflowType: ->
    name: @cls
    version: @version or "1.0.0"
  taskList: ->
    name: @cls
#  columns: -> throw "Implement me!"
  insertCommand: (data, callback) ->
    Commands.insert _.extend({}, data, @insertCommandData()), callback
  insertCommandData: ->
    stepId: @_id
    progressBars: @progressBars()
  columns: -> @tempColumns()
  tempColumns: ->
    row = Rows.findOne({stepId: @_id})
    availableColumnsKeys = if row then _.keys(row) else []
    for key in availableColumnsKeys
      new Columns.Column(
        key: key
        _i18n:
          name: key
      )
  cachedColumns: ->
    return @_cachedColumns if @_cachedColumns
    @_cachedColumns = @columns()
  recipe: (options = {}) -> # for reactivity
    options.fields.cls = 1 if options.fields # for Transformations
    options.transform ?= Transformations.Recipe
    Recipes.findOne(@recipeId, options)
  user: (options = {}) ->
    options.transform ?= Transformations.User
    Users.findOne(@userId, options)
  runsLeft: ->
    user = @user({fields: {planId: 1, executions: 1}})
    plan = user.plan()
    if plan.executionsLimit
      Math.max(0, plan.executionsLimit - (user.executions or 0))
    else
      Infinity
  recipeField: (field, defaultValue = null) ->
    fields = {}
    fields[field] = 1
    recipe = @recipe({fields: fields})
    return defaultValue if not recipe
    recipe[field] or defaultValue
  issues: (selector, options) ->
    Issues.find(_.extend({stepId: @_id}, selector), options)
  refreshPlannedAtPlusCronTimeout: ->
    new Date(@refreshPlannedAt.getTime() + 60000)
  _i18n: ->
    key = @_i18nKey()
    parameters = @_i18nParameters()
    result = @_i18nResult(key, parameters)
    result = {} if result is key # i18n not found
    throw new Meteor.Error("_i18n:not-an-object", "", {result: result}) if not _.isObject(result)
    _.defaults(result, @_i18nResult("Steps.defaults", parameters))
  _i18nKey: -> "Steps.#{@i18nKey}"
  _i18nParameters: ->
    runsLeft: @runsLeft()
  _i18nResult: (key, parameters) ->
    i18n.t(key, _.extend({returnObjectTrees: true}, parameters))

Steps.match = ->
  _id: Match.StringId
  cls: String
  refreshInterval: Match.Optional(Match.Integer)
  refreshPlannedAt: Match.Optional(Date)
  position: Match.Integer
  search: String
  page: Match.Integer
  recipeId: Match.ObjectId(Recipes)
  userId: Match.ObjectId(Users)
  isCompleted: Boolean
  isAutorun: Boolean
  updatedAt: Date
  createdAt: Date

StepPreSave = (userId, changes) ->
  now = new Date()
  changes.updatedAt = changes.updatedAt or now

Steps.before.insert (userId, Step) ->
  Step._id ||= Random.id()
  now = new Date()
  _.defaults(Step, Meteor.settings.public.Step)
  _.autovalues(Step,
    search: ""
    page: 1
    isCompleted: false
    isAutorun: false
    position: (Step) -> Steps.find({recipeId: Step.recipeId}).count() + 1
    userId: userId
    updatedAt: now
    createdAt: now
  )
  check Step, Match.ObjectIncluding(Steps.match())
  StepPreSave.call(@, userId, Step)
  true

Steps.before.update (userId, Step, fieldNames, modifier, options) ->
  modifier.$set = modifier.$set or {}
  StepPreSave.call(@, userId, modifier.$set)
  true

# Don't forget to return true, otherwise the insert/update will be stopped!
Steps.Step::beforeInsert = (userId, Step) ->
  true
Steps.Step::afterInsert = (userId, Step) ->
  true
Steps.Step::beforeUpdate = (userId, Step, fieldNames, modifier, options) ->
  true
Steps.Step::afterUpdate = (userId, Step, fieldNames, modifier, options) ->
  true

Steps.before.insert (userId, Step) -> Transformations.cls(Steps, Steps.Step, Step)::beforeInsert.apply(@, arguments)

Steps.after.insert (userId, Step) -> Transformations.cls(Steps, Steps.Step, Step)::afterInsert.apply(@, arguments)

Steps.before.update (userId, Step, fieldNames, modifier, options) -> Transformations.cls(Steps, Steps.Step, Step)::beforeUpdate.apply(@, arguments)

Steps.after.update (userId, Step, fieldNames, modifier, options) -> Transformations.cls(Steps, Steps.Step, Step)::afterUpdate.apply(@, arguments)

Steps.after.update (userId, Step, fieldNames, modifier, options) ->
  Step = Transformations.Step(Step)
  Recipe = Step.recipe()
  Recipe.stepAfterUpdate.apply(Recipe, arguments)

if Meteor.isServer
  Steps.after.remove (userId, Step) ->
    Step = Transformations.Step(Step)
    Rows.remove({stepId: Step._id})
    Columns.remove({stepId: Step._id})
