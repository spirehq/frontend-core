Mixpanel = Npm.require("mixpanel")
crypto = Npm.require("crypto")
flatten = Npm.require("flat")

mixpanel = Mixpanel.init(Meteor.settings.public.mixpanel.token, {key: Meteor.settings.mixpanel.key})
if not Meteor.settings.public.mixpanel.isEnabled
  mixpanel.send_request = (endpoint, data, callback) -> callback?() # don't really send any requests
else
  mixpanel.set_config({debug: Meteor.settings.public.isDebug})

mixpanel.track = _.wrap mixpanel.track, (parent, name, properties = {}, callback) ->
  if name isnt "$create_alias"
    throw "No userId specified for #{name}" unless properties.userId
    properties.distinct_id = properties.userId
  if properties.userId in Spire.internalUserIds
    return # don't track internal users
  properties = flatten(sanitize(properties))
  parent.call(mixpanel, name, properties, callback)

mixpanel.track_user = (user) ->
  user = Transformations.User(user)
  mixpanel.people.set(user._id,
    _id: user._id
    $name: user.name()
    $first_name: user.firstName()
    $last_name: user.lastName()
    $email: user.email()
    $created: user.createdAt
    isRealName: user.profile.isRealName
    Flags: user.flags
  )

mixpanel.call = (method, url, params) ->
  _.defaults(params,
    api_key: Meteor.settings.mixpanel.key
    expire: Date.now() + 60 * Spire.minute
  )
  paramsToBeSorted = []
  for key, value of params
    paramsToBeSorted.push({key: key, value: value})
  paramsToBeSorted = _.sortBy(paramsToBeSorted, (object) -> object.key)
  paramsString = ""
  for object in paramsToBeSorted
    paramsString += "#{object.key}=#{object.value}"
  params.sig = crypto.createHash('md5').update(paramsString + Meteor.settings.mixpanel.secret).digest("hex")
  response = HTTP.call(method, url, {params: params, timeout: Spire.minute})
  if response.statusCode isnt 200
    throw "[#{response.statusCode}] Mixpanel HTTP error"
  data = response.data
  if data.status isnt "ok"
    throw "[#{data.status}] Mixpanel content error"
  data
