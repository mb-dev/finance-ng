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
    $addProcessingRule: ->
      return if !@categoryName || !@payeeName
      if @$originalPayeeName
        tables.processingRules.set('name:' + @$originalPayeeName, {payeeName: @payeeName, categoryName: @categoryName})
      else
        tables.processingRules.set('amount:' + @amount, {payeeName: @payeeName, categoryName: @categoryName})
    $process: ->
      processingRule = null
      if @payeeName && tables.processingRules.has('name:' + @payeeName)
        processingRule = tables.processingRules.get('name:' + @payeeName)
      else if tables.processingRules.has('amount:' + @amount)
        processingRule = tables.processingRules.get('amount:' + @amount)

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
        
        @dba.lineItems.query('date').bound(minDate, maxDate).execute().done (lineItems) =>
          lineItems = Lazy(lineItems).filter((item) -> 
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

  reBalance: (modifiedItem) =>
    currentBalance = 0

    updateBalance = (item) ->
      unless item.tags and item.tags.indexOf(LineItemCollection.TAG_CASH) >= 0
        currentBalance += helpers.$signedAmount.apply(item)
      currentBalance

    new RSVP.Promise (resolve, reject) =>
      @dba.lineItems.query('date_id')
      .all()
      .modify(balance: updateBalance)
      .execute()
      .then -> resolve()

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