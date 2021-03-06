Meteor.startup ->
  if not Meteor.settings.public.ga.isEnabled
    window["ga-disable-" + Meteor.settings.public.ga.property] = true
  ga("create", Meteor.settings.public.ga.property, if Meteor.settings.public.isDebug then "none" else "auto");

sendPageview = (context) ->
  ga("send", "pageview", context.path)
