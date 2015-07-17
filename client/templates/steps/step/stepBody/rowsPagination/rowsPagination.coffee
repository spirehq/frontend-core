Template.rowsPagination.helpers
  pagination: ->
    rowsCount = Counts.get("RowsCountByStepId")
    lastPage = Math.ceil(rowsCount / Foreach.pageLimit)
    if @page < 1
      Steps.update(@_id, {$set: {page: 1}})
    else if @page > lastPage
      Steps.update(@_id, {$set: {page: lastPage}})
    else if rowsCount > Foreach.pageLimit
      from = @page - 2
      from = 1  if from < 1
      to = from + 4
      if to > lastPage
        to = lastPage
        from = to - 4
        from = 1  if from < 1
      lastPage: lastPage
      isFirstPage: @page is 1
      isLastPage: @page is lastPage
      active: @page
      pages: [from..to]

Template.rowsPagination.events
  "click .rows-pagination a": (event, template) ->
    $link = $(event.currentTarget)
    unless $link.hasClass("disabled") or $link.hasClass("active")
      page = parseInt($link.attr("data-page"))
      unless isNaN(page)
        Steps.update(template.data._id, {$set: {page: page}})
