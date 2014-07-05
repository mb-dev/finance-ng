class BudgetItemCollection extends Collection
  getYearRange: ->
    Lazy(@collection).pluck('budget_year').uniq().sortBy(Lazy.identity).toArray()