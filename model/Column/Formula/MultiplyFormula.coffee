class Columns.MultiplyFormula extends Columns.Formula
  constructor: (doc) ->
    super
  calculate: (row, columns) ->
    _.reduce(@parse(row, columns), ((memo, arg) -> memo * Spire.floatval(arg.trim())), 1)
