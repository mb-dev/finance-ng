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
    )
    @sortLazy(results, sortColumns)

  reBalance: (modifiedItem) =>
    return if !@collection || @collection.length == 0
    return if !modifiedItem || !modifiedItem.accountId
    
    sortedCollection = @getItemsByAccountId(modifiedItem.accountId, ['originalDate', 'id']).toArray()
    currentBalance = new BigNumber(0)

    if !modifiedItem || (modifiedItem.id == sortedCollection[0].id)
      startIndex = 0
    else
      startIndex = Lazy(sortedCollection).pluck('id').indexOf(modifiedItem.id)
      currentBalance = new BigNumber(sortedCollection[startIndex-1].balance)
    
    [startIndex..(sortedCollection.length-1)].forEach (index) =>
      if !(sortedCollection[index].tags && sortedCollection[index].tags.indexOf(LineItemCollection.TAG_CASH) >= 0) # don't increase balance for cash
        currentBalance = currentBalance.plus(sortedCollection[index].$signedAmount())
      sortedCollection[index].balance = currentBalance.toString()

  cloneLineItem: (originalItem) =>
    newItem = {}
    angular.copy(originalItem, newItem)
    delete newItem['id']
    delete newItem['createdAt']
    delete newItem['updatedAt']
    delete newItem['balance']
    newItem

class BudgetItemCollection extends Collection
  getYearRange: ->
    Lazy(@collection).pluck('budget_year').uniq().sortBy(Lazy.identity).toArray()

class ImportedLinesCollection extends Collection
  findByContent: (content) ->
    index = Lazy(@collection).pluck('content').indexOf(content)
    return null if index < 0
    @collection[index]

class MemoriesCollection extends Collection

  migrateIfNeeded: ->

  getByDynamicFilter: (filter, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      if filter.date
        date = moment(item.date)
        return false if !(date.month() == filter.date.month && date.year() == filter.date.year)
      if filter.onlyParents
        return false if !item.parentMemoryId && (!item.events || item.events.length == 0)
      true
    )
    @sortLazy(results, sortColumns)

  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getItemsByEventId: (eventId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.events && item.events.indexOf(eventId) >= 0 )
    @sortLazy(results, sortColumns)

  getItemsByParentMemoryId: (parentMemoryId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.parentMemoryId == parentMemoryId)
    @sortLazy(results, sortColumns)

  getMemoriesByPersonId: (personId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.people && item.people.indexOf(personId) >= 0 )
    @sortLazy(results, sortColumns)

  getAllParentMemories: (sortColumns) ->
    results = Lazy(@collection).filter((item) -> !item.parentMemoryId && (!item.events || item.events.length == 0) )
    @sortLazy(results, sortColumns)

  getMemoriesMentionedAtEventId: (eventId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.mentionedIn && item.mentionedIn.indexOf(eventId) >= 0 )
    @sortLazy(results, sortColumns)

  getMemoriesMentionedToPersonId: (personId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.mentionedTo && item.mentionedTo.indexOf(personId) >= 0 )
    @sortLazy(results, sortColumns)

class EventsCollection extends Collection
  getItemsByMonthYear: (month, year, sortColumns) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    @sortLazy(results, sortColumns)

  getEventsByParticipantId: (participantId, sortColumns) ->
    results = Lazy(@collection).filter((item) -> item.participantIds && item.participantIds.indexOf(participantId) >= 0 )
    @sortLazy(results, sortColumns)

angular.module('app.services', ['ngStorage'])
  .factory 'mdb', ($http, $q, $sessionStorage, $localStorage, $rootScope, fileSystem) ->
    tablesList = {
      memories: 'memories'
      events: 'events'
      people: 'people'
      categories: 'categories'
    }
    db = new Database('memoryng', $http, $q, $sessionStorage, $localStorage, fileSystem)
    tables = {
      memories: db.createCollection(tablesList.memories, new MemoriesCollection($q, ['date', 'id']))
      events: db.createCollection(tablesList.events, new EventsCollection($q, 'date'))
      people: db.createCollection(tablesList.people, new Collection($q,'name')),
      categories: db.createCollection(tablesList.categories, new SimpleCollection($q))
    }

    # events
    tables.events.setItemExtendFunc (item) ->
      item.$participants = ->
        getAll: ->
          tables.people.findByIds(item.participantIds)
      item.$memories = ->
        getAll: ->
          tables.memories.getItemsByEventId(item.id)
      item.$mentioned = ->
        getAll: ->
          tables.memories.getMemoriesMentionedAtEventId(item.id)

    tables.people.setItemExtendFunc (item) ->
      item.$mentioned = ->
        getAll: ->
          tables.memories.getMemoriesMentionedToPersonId(item.id)

    accessFunc = {
      tables: tablesList
      memories: ->
        tables.memories
      events: ->
        tables.events
      people: ->
        tables.people
      categories: ->
        tables.categories
      user: ->
        db.user()
      authAndCheckData: (tableList) =>
        db.authAndCheckData(tableList)
      getTables: (tableList, forceRefreshAll) =>
        defer = $q.defer()
        db.getTables(tableList, forceRefreshAll).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList, forceServerCleanAndSaveAll) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }

  .factory 'fdb', ($http, $q, $sessionStorage, $localStorage, $rootScope, fileSystem) ->
    db = new Database('financeng', $http, $q, $sessionStorage, $localStorage, fileSystem)

    tablesList = {
      accounts: 'accounts',
      lineItems: 'lineItems',
      budgetItems: 'budgetItems',
      plannedItems: 'plannedItems'
      categories: 'categories'
      payees: 'payees'
      importedLines: 'importedLines'
      processingRules: 'processingRules'
    }
    tables = {
      accounts: db.createCollection(tablesList.accounts, new Collection($q, 'name'))
      lineItems: db.createCollection(tablesList.lineItems, new LineItemCollection($q, ['date', 'id']))
      budgetItems: db.createCollection(tablesList.budgetItems, new BudgetItemCollection($q, 'budget_year'))
      plannedItems: db.createCollection(tablesList.plannedItems, new Collection($q))
      categories: db.createCollection(tablesList.categories, new SimpleCollection($q))
      payees: db.createCollection(tablesList.payees, new SimpleCollection($q))
      importedLines: db.createCollection(tablesList.importedLines, new ImportedLinesCollection($q))
      processingRules: db.createCollection(tablesList.processingRules, new SimpleCollection($q))
    }
    
    tables.lineItems.setItemExtendFunc (item) ->
      item.$isExpense = ->
        @type == LineItemCollection.EXPENSE
      item.$isIncome = ->
        @type == LineItemCollection.INCOME
      item.$date = ->
        moment(@date)
      item.$multiplier = ->
        if @type == LineItemCollection.EXPENSE then -1 else 1
      item.$signedAmount = ->
        parseFloat(@amount) * @$multiplier()
      item.$signedAmountAbs = ->
        Math.abs(parseFloat(@amount) * @$multiplier())
      item.$addProcessingRule = ->
        return if !@categoryName || !@payeeName
        if @$originalPayeeName
          tables.processingRules.set('name:' + @$originalPayeeName, {payeeName: @payeeName, categoryName: @categoryName})
        else
          tables.processingRules.set('amount:' + @amount, {payeeName: @payeeName, categoryName: @categoryName})
          
      item.$process = ->
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

    tables.plannedItems.setItemExtendFunc (item) ->
      item.$isIncome = ->
        @type == 'income'
      item.$isExpense = ->
        @type == 'expense'
      item.$eventDateStart = ->
        moment(@event_date_start)
      item.$eventDateEnd = ->
        moment(@event_date_end)

    
    accessFunc = {
      tables: tablesList
      importDatabase: ->
        importDatabase($q, accessFunc)
      lineItems: ->
        tables.lineItems
      accounts: ->
        tables.accounts
      budgetItems: ->
        tables.budgetItems
      user: ->
        db.user()
      plannedItems: ->
        tables.plannedItems
      categories: ->
        tables.categories
      payees: ->
        tables.payees
      importedLines: ->
        tables.importedLines
      processingRules: ->
        tables.processingRules
      authAndCheckData: (tableList) =>
        db.authAndCheckData(tableList)
      getTables: (tableList, forceRefreshAll = false) =>
        defer = $q.defer()
        db.getTables(tableList, forceRefreshAll).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise
      saveTables: (tableList, forceServerCleanAndSaveAll = false) ->
        db.saveTables(tableList, forceServerCleanAndSaveAll)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }
