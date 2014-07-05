class window.LineItemCollection extends Collection
  @EXPENSE = 1
  @INCOME = 2

  @SOURCE_IMPORT = 'import'

  @EXCLUDE_FROM_REPORT = 'Exclude from Reports'
  @TRANSFER_TO_CASH = 'Transfer:Cash'

  @TAG_CASH = 'Cash'
    
  getYearRange: ->
    Lazy(@collection).map((item) -> moment(item.date).year()).uniq().sortBy(Lazy.identity).toArray()

  getByDynamicFilter: (filter, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      if filter.date
        date = moment(item.date)
        if filter.date.month? && filter.date.year?
          return false if date.month() != filter.date.month || date.year() != filter.date.year
        else if filter.date.year
          return false if (date.year() != filter.date.year)
      if filter.categories?
        return false if filter.categories.indexOf(item.categoryName) < 0
      if filter.categoryName == 'empty'
        return false if typeof(item.categoryName) != 'undefined' 
        return false if item.categoryName? && item.categoryName.length > 0
      else if filter.categoryName?
        return false if item.categoryName != filter.categoryName
      if filter.accountId?
        return false if item.accountId != filter.accountId
      if filter.groupedLabel?
        return false if item.groupedLabel != filter.groupedLabel
      true
    )
    @sortLazy(results, sortColumns)

  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getItemsByMonthYearAndCategories: (month, year, categories, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year && categories.indexOf(item.categoryName) >= 0
    )
    @sortLazy(results, sortColumns)

  getItemsByAccountId: (accountId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      item.accountId == accountId
    ).map((item) -> angular.copy(item))
    @sortLazy(results, sortColumns)

  getItemsByAccountIdSorted: (accountId) =>
    @getItemsByAccountId(accountId, ['originalDate', 'id']).toArray()

  reBalance: (modifiedItem) =>
    return if !@collection || @collection.length == 0
    return if !modifiedItem || !modifiedItem.accountId
    
    sortedCollection = @getItemsByAccountIdSorted(modifiedItem.accountId)
    currentBalance = new BigNumber(0)

    if !modifiedItem || (modifiedItem.id == sortedCollection[0].id)
      startIndex = 0
    else
      startIndex = Lazy(sortedCollection).pluck('id').indexOf(modifiedItem.id)
      currentBalance = new BigNumber(sortedCollection[startIndex-1].balance)
    
    [startIndex..(sortedCollection.length-1)].forEach (index) =>
      if !(sortedCollection[index].tags && sortedCollection[index].tags.indexOf(LineItemCollection.TAG_CASH) >= 0) # don't increase balance for cash
        currentBalance = currentBalance.plus(sortedCollection[index].$signedAmount())

      newBalance = currentBalance.toString()
      if sortedCollection[index].balance != newBalance
        sortedCollection[index].balance = newBalance
        @editById(sortedCollection[index])

  cloneLineItem: (originalItem) =>
    newItem = {}
    angular.copy(originalItem, newItem)
    delete newItem['id']
    delete newItem['createdAt']
    delete newItem['updatedAt']
    delete newItem['balance']
    newItem

  balancesByAccount: =>
    results = {}
    @sortLazy(Lazy(@collection), ['date', 'id']).each((item) -> 
      results[item.accountId] = item.balance
    )
    results

  deleteItemAndRebalance: (item) =>
    items = @getItemsByAccountIdSorted(item.accountId)
    modifiedItemIndex = Lazy(items).pluck('id').indexOf(item.id)
    if modifiedItemIndex == 0
      previousItem = items[1]
    else
      previousItem = items[modifiedItemIndex - 1]
    @deleteById(item.id)
    @reBalance(previousItem)