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
        
        if filter.sortBy == 'originalDate'
          index = 'originalDate_id'
        else
          index = 'date_id'

        @dba.lineItems.query(index).bound([minDate, 0], [maxDate, Number.MAX_VALUE]).execute().then (lineItems) =>
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
          resolve(lineItems)
      else
        resolve([])

  reBalance: (modifiedItem, accountId, deletedItem = false) =>
    new RSVP.Promise (resolve, reject) =>
      currentBalance = new BigNumber(0)

      updateBalance = (item) =>
        unless item.tags and item.tags.indexOf(LineItemCollection.TAG_CASH) >= 0
          currentBalance = currentBalance.plus(helpers.$signedAmount.apply(item))
        
        newBalanceString = currentBalance.toFixed(2)
        if item.balance != newBalanceString
          item.balance = newBalanceString
          @onEdit(item)

        newBalanceString

      findPreviousItem = =>
        @dba.lineItems.query('account_originalDate_id').upperBound([modifiedItem.accountId, modifiedItem.originalDate, modifiedItem.id]).desc().limit(0, 2).execute()

      findRestItemsUpdateBalance = =>
        query = @dba.lineItems.query('account_originalDate_id')
        if modifiedItem
          query = query.bound([modifiedItem.accountId, modifiedItem.originalDate, modifiedItem.id], [modifiedItem.accountId, Number.MAX_VALUE, Number.MAX_VALUE])
        else
          query = query.bound([accountId, 0, 0], [accountId, Number.MAX_VALUE, Number.MAX_VALUE])
        query.modify(balance: updateBalance)
        .execute()

      if modifiedItem
        findPreviousItem().then (previousItems) ->
          if previousItems.length == 2
            startingIndex = if deletedItem then 0 else 1
            currentBalance = new BigNumber(parseFloat(previousItems[startingIndex].balance))
        .then -> findRestItemsUpdateBalance().then -> resolve()
      else
        findRestItemsUpdateBalance().then -> resolve()

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
    @deleteById(item.id)
    .then => @reBalance(item, item.accountId, true)