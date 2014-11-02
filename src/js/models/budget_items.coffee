class BudgetItemCollection extends IndexedDbCollection
  getAllForYear: (year) ->
    new RSVP.Promise (resolve, reject) =>
      @dba.budgetItems.query('budgetYear').only(year).execute().then (results) ->
        resolve(results)

  getYearRange: ->
    Lazy(@collection).pluck('budgetYear').uniq().sortBy(Lazy.identity).toArray()