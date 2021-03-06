Template.StartWorkflowExecution.helpers
  isLoading: (selector) ->
    step = Template.currentData()
    commands = Commands.find(_.defaults({stepId: step._id}, selector)).fetch()
    not _.every commands, (command) ->
      everyProgressBarIsCompletedOrSkipped = _.every command.progressBars, (progressBar) -> progressBar.isCompleted or progressBar.isSkipped
      anyProgressBarIsFailed = _.any command.progressBars, (progressBar) -> progressBar.isFailed
      everyProgressBarIsCompletedOrSkipped or anyProgressBarIsFailed
  isLoadingLiveRunSelector: ->
    isDryRun: false
    isShallow: false
    sampleId: {$exists: false}
  isLoadingAllSamplesSelector: ->
    isDryRun: false
    isShallow: true
    sampleId: {$exists: false}
  isLoadingSingleSampleSelector: ->
    isDryRun: false
    isShallow: true
    sampleId: @_id
  commandLiveRun: ->
    Commands.findOne({isDryRun: false, isShallow: false, sampleId: {$exists: false}}, {sort: {createdAt: -1}})
  commandForAllSamples: ->
    Commands.findOne({isDryRun: false, isShallow: true, sampleId: {$exists: false}}, {sort: {createdAt: -1}})
  commandForSingleSample: ->
    Commands.findOne({isDryRun: false, isShallow: true, sampleId: @_id}, {sort: {createdAt: -1}})
  showDebugPanel: ->
    Meteor.settings.public.isDebug or Spire.currentUserField("isAdmin")
  shownColumns: ->
    step = Template.instance().data
    _.filter(step.columns(), (column) => column.key not in step.hiddenColumnKeys)
  samples: ->
    Samples.find({stepId: @_id}, {sort: {sort: 1, createdAt: -1}})
  count: ->
    Counts.get("SamplesCountByStepId")
  stringify: (object) ->
    EJSON.stringify(object[@], {indent: true})
  data: ->
    sample: Template.parentData(1)
    column: Template.currentData()
  progressBarMessage: (command) ->
# isFinished has priority (so that isStarted = false & isFinished = true displays OK)
    step = command.step()
    key = step._i18nKey() + ".progressBars.#{@activityId}"
    if @total? and @current? # not undefined, not null, may be equal to 0
      suffix = "complex" # e.g. "Downloaded 1 of 4 Twitter followers"
      count = @total # <- "followers", because 4 total
    else
      suffix = "simple" # e.g. "Downloaded 4 Twitter followers"
      count = @total or @current

    if @isSkipped
      key += ".skipped"
    else if @isFailed
      key += ".failed"
    else if @isCompleted
      key += ".loaded_#{suffix}"
    else if @isStarted
      if count
        suffix += "_message" if @message
        key += ".loading_#{suffix}"
      else
        key += ".connecting"
    else if command.isFailed
      key += ".cancelled"
    else
      key += ".waiting"
    i18n.t(key, _.extend({count: count, message: @message}, @, step)) # example i18n string where step data is necessary: "Reused <a href='{{spreadsheet.link}}'>{{spreadsheet.name}}</a> (created earlier)"
  progressBarIconClass: (command) ->
    return "fa-check" if @isSkipped
    return "fa-exclamation-circle" if @isFailed
    return "fa-check" if @isCompleted
    return "fa-refresh fa-spin" if @isStarted
    return "fa-ban" if command.isFailed
    return "fa-ellipsis-h"

Template.StartWorkflowExecution.onCreated ->
  @autorun =>
    step = Template.currentData()
    @subscribe("LatestCommandsByStepId", step._id)
    @subscribe("SamplesByStepId", step._id, step.page, 0, step.search)
    @subscribe("SamplesCountByStepId", step._id, step.search)

Template.StartWorkflowExecution.events
  "switchChange.bootstrapSwitch .is-autorun-toggle": grab encapsulate (event, template, isChecked) ->
    $toggle = $(event.currentTarget)
    state = $toggle.bootstrapSwitch("state")
    Steps.update(@_id, {$set: {isAutorun: isChecked}}, Spire.createErrback(
      ->
    ,
      (error) -> $toggle.bootstrapSwitch("state", not state) if error
    ))
  "click .run": grab encapsulate (event, template) ->
    @insertCommand
      isDryRun: false
      isShallow: false
    , Spire.createErrback()
  "click .test": grab encapsulate (event, template) ->
    @insertCommand
      isDryRun: true
      isShallow: false
    , Spire.createErrback()
  "click .run-for-all-samples": grab encapsulate (event, template) ->
    $(event.currentTarget).blur()
    @insertCommand
      isDryRun: false
      isShallow: true
    , Spire.createErrback()
  "click .run-for-single-sample": grab encapsulate (event, template) ->
    @insertCommand
      isDryRun: false
      isShallow: true
      sampleId: @_id
    , Spire.createErrback()
  "click .cancel-run": grab encapsulate (event, template) ->
    Commands.find({stepId: @_id}).forEach (command) -> Commands.remove(command._id)

  # Debug events

  "click .set-execution-counter-to-executions-limit": grab encapsulate (event, template) ->
    user = Spire.currentUser()
    Users.update(Meteor.userId(), {$set: {executions: user.plan().executionsLimit or 0}})
  "click .set-plan-id": grab encapsulate (event, template) ->
    planId = $(event.currentTarget).attr("data-plan-id")
    Meteor.call("setPlanId", @userId, planId)

