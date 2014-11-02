class window.LineItemCollection extends IndexedDbCollection
  @EXPENSE = 1
  @INCOME = 2

  @SOURCE_IMPORT = 'import'

  @EXCLUDE_FROM_REPORT = 'Exclude from Reports'
  @TRANSFER_TO_CASH = 'Transfer:Cash'

  @TAG_CASH = 'Cash'

  helpers = 
    $isExpense: ->
        @type == LineItemCollection.EXPENSE
    $isIncome: ->
      @type == LineItemCollection.INCOME
    $date: ->
      moment(@date)
    $multiplier: ->
      if @type == LineItemCollection.EXPENSE then -1 else 1
    $signedAmount: ->
      parseFloat(@amount) * helpers.$multiplier.apply(@)
    $signedAmountAbs: ->
      Math.abs(parseFloat(@amount) * @$multiplier())
    $addProcessingRule: (processingRuleTable) ->
      return if !@categoryName || !@payeeName
      if @$originalPayeeName
        processingRuleTable.set('name:' + @$originalPayeeName, {payeeName: @payeeName, categoryName: @categoryName})
      else
        processingRuleTable.set('amount:' + @amount, {payeeName: @payeeName, categoryName: @categoryName})
    $process: (processingRules) ->
      processingRule = null
      if @payeeName && processingRules['name:' + @payeeName]
        processingRule = processingRules['name:' + @payeeName]
      else if processingRules['amount:' + @amount]
        processingRule = processingRules['amount:' + @amount]

      if processingRule
        @payeeName = processingRule.payeeName
        @categoryName = processingRule.categoryName
        true
      else
        false

  addHelpers: (items) ->
    items.forEach (item) -> angular.extend(item, helpers)
    
  getYearRange: ->
    Lazy(@collection).map((item) -> moment(item.date).year()).uniq().sortBy(Lazy.identity).toArray()

  getByDynamicFilter: (filter, sortColumns) ->
    new RSVP.Promise (resolve, reject) =>
      if filter.date
        if filter.date.month? && filter.date.year?
          minDate = moment({month: filter.date.month, year: filter.date.year}).startOf('month').valueOf()
          maxDate = moment({month: filter.date.month, year: filter.date.year}).endOf('month').valueOf()
        else if filter.date.year
          minDate = moment({year: filter.date.year}).startOf('year').valueOf()
          maxDate = moment({year: filter.date.year}).endOf('year').valueOf()
        
        @dba.lineItems.query('date').bound(minDate, maxDate).execute().then (lineItems) =>
          lineItems = _.filter(lineItems, (item) -> 
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
          lineItems = @sortLazy(lineItems, sortColumns)
          resolve(lineItems)
      else
        resolve([])

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

  reBalance: (modifiedItem, accountId) =>
    currentBalance = 0

    updateBalance = (item) =>
      unless item.tags and item.tags.indexOf(LineItemCollection.TAG_CASH) >= 0
        currentBalance += helpers.$signedAmount.apply(item)
      
      if item.balance != currentBalance
        item.balance = currentBalance
        @onEdit(item)

      currentBalance

    findPreviousItem = =>
      @dba.lineItems.query('account_date_id').upperBound([modifiedItem.accountId, modifiedItem.date, modifiedItem.id]).desc().limit(0, 2).execute()

    findRestItemsUpdateBalance = =>
      query = @dba.lineItems.query('account_date_id')
      if modifiedItem
        query = query.lowerBound([modifiedItem.accountId, modifiedItem.date, modifiedItem.id])
      else
        query = query.bound([accountId, 0, 0], [accountId, Number.MAX_VALUE, Number.MAX_VALUE])
      query.modify(balance: updateBalance)
      .execute()

    if modifiedItem
      findPreviousItem().then (previousItems) ->
        if previousItems.length == 2
          currentBalance = previousItems[1].balance
      .then -> findRestItemsUpdateBalance()
    else
      findRestItemsUpdateBalance()

  cloneLineItem: (originalItem) =>
    newItem = {}
    angular.copy(originalItem, newItem)
    delete newItem['id']
    delete newItem['createdAt']
    delete newItem['updatedAt']
    delete newItem['balance']
    newItem

  balancesByAccount: =>
    new RSVP.Promise (resolve, reject) =>
      results = {}
      @dba.lineItems.query('date_id').all().execute().then (items) ->
        results[item.accountId] = item.balance for item in items
        resolve(results)

  deleteItemAndRebalance: (item) =>
    items = @getItemsByAccountIdSorted(item.accountId)
    modifiedItemIndex = Lazy(items).pluck('id').indexOf(item.id)
    if modifiedItemIndex == 0
      previousItem = items[1]
    else
      previousItem = items[modifiedItemIndex - 1]
    @deleteById(item.id)
    @reBalance(previousItem)