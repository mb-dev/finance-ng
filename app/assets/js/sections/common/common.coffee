# JS Functions

# Other

class window.LineItemCollection extends Collection
  @EXPENSE = 1
  @INCOME = 2

  @SOURCE_IMPORT = 'import'
    
  getItemsByMonthYear: (month, year, sortBy) ->
    Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    ).sortBy(sortBy)

  reBalance: (modifiedItem) =>
    return if !@collection || @collection.length == 0
    
    sortedCollection = Lazy(@collection).sortBy(@defaultSortFunction).toArray()
    currentBalance = new BigNumber(0)

    if !modifiedItem || (modifiedItem.id == sortedCollection[0].id)
      startIndex = 0
    else
      startIndex = Lazy(sortedCollection).pluck('id').indexOf(modifiedItem.id)
      currentBalance = new BigNumber(sortedCollection[startIndex-1].balance)
    
    [startIndex..(sortedCollection.length-1)].forEach (index) =>
      currentBalance = currentBalance.plus(sortedCollection[index].$signedAmount())
      sortedCollection[index].balance = currentBalance.toString()



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
    Lazy(@collection).each (item) ->
      if item.event_date
        item.date = item.event_date
        delete item.event_date
      if item.eventId
        item.events = [item.eventId]
        delete item.eventId

  getItemsByMonthYear: (month, year, sortBy) ->
    results = Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    )
    results = results.sortBy sortBy if sortBy
    results

  getItemsByEventId: (eventId, sortBy) ->
    results = Lazy(@collection).filter((item) -> item.events && item.events.indexOf(eventId) >= 0 )
    results = results.sortBy sortBy if sortBy
    results

  getItemsByParentMemoryId: (parentMemoryId, sortBy) ->
    results = Lazy(@collection).filter((item) -> item.parentMemoryId == parentMemoryId)
    results = results.sortBy sortBy if sortBy
    results

  getMemoriesByPersonId: (personId, sortBy) ->
    results = Lazy(@collection).filter((item) -> item.people && item.people.indexOf(personId) >= 0 )
    results = results.sortBy sortBy if sortBy
    results

  getAllParentMemories: (sortBy) ->
    results = Lazy(@collection).filter((item) -> !item.parentMemoryId && (!item.events || item.events.length == 0) )
    results = results.sortBy sortBy if sortBy
    results   

class EventsCollection extends Collection
  getItemsByMonthYear: (month, year, sortBy) ->
    if !sortBy && @sortColumn
      sortBy = @defaultSortFunction

    Lazy(@collection).filter((item) -> 
      date = moment(item.date)
      date.month() == month && date.year() == year
    ).sortBy(sortBy)

  getEventsByParticipantId: (participantId, sortBy) ->
    results = Lazy(@collection).filter((item) -> item.participantIds && item.participantIds.indexOf(participantId) >= 0 )
    results = results.sortBy sortBy if sortBy
    results 

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
      memories: db.createCollection(tablesList.memories, new MemoriesCollection($q, 'date'))
      events: db.createCollection(tablesList.events, new EventsCollection($q, 'date'))
      people: db.createCollection(tablesList.people, new Collection($q)),
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
      getTables: (tableList) =>
        defer = $q.defer()
        db.getTables(tableList).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList) ->
        db.saveTables(tableList)
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
      lineItems: db.createCollection(tablesList.lineItems, new LineItemCollection($q, 'date'))
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
      getTables: (tableList) =>
        defer = $q.defer()
        db.getTables(tableList).then((db) =>
          $rootScope.user = accessFunc.user()
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList) ->
        db.saveTables(tableList)
      dumpAllCollections: (tableList) -> 
        db.dumpAllCollections(tableList)
    }
  .factory 'budgetReportService', () ->
    getReportForYear: (db, year) ->
      budgetReport = new BudgetReportView(db, year)
      budgetReport
  .factory 'errorReporter', () ->
    errorCallbackToScope: ($scope) ->
      (reason) ->
        $scope.error = "failure for reason: " + reason

angular.module('app.directives', ['app.services', 'app.filters'])
  .directive 'currencyWithSign', ->
    {
      restrict: 'E',
      link: (scope, elm, attrs) ->
        scope.$watch attrs.amount, (value) ->
          if (typeof value == 'undefined' || value == null)
            elm.html('')
          else if value[0] == '-'
            elm.html('<span class="negative">' + value + '</span>')
          else
            elm.html('<span class="positive">' + value + '</span>')
    }
  
  .directive 'dateFormat', ($filter) ->
    dateFilter = $filter('localDate')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          dateFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          moment(value).valueOf()          
    }

  .directive 'floatToString', ($filter) ->
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          parseFloat(value)
        
        ngModelCtrl.$parsers.push (value) ->
          value.toString()
    }

  .directive 'typeFormat', ($filter) ->
    typeFilter = $filter('typeString')
    {  
      require: 'ngModel'
      link: (scope, element, attr, ngModelCtrl) ->
        ngModelCtrl.$formatters.unshift (value) ->
          typeFilter(value)
        
        ngModelCtrl.$parsers.push (value) ->
          if value == 'Expense' then LineItemCollection.EXPENSE else LineItemCollection.INCOME
    }

  .directive 'numbersOnly', () ->
    {
      require: 'ngModel',
      link: (scope, element, attrs, modelCtrl) ->
        modelCtrl.$parsers.push (inputValue) -> 
          parseInt(inputValue, 10)
    }

  .directive 'pickadate', () ->
    {
      link: (scope, element, attrs, modelCtrl) ->
        element.pickadate({
          format: 'mm/dd/yyyy'
        })
    }
  .directive "fileread", () ->
    scope: 
      fileread: "="
    link: (scope, element, attributes) ->
      element.bind "change", (changeEvent) ->
        scope.$apply () ->
          scope.fileread = changeEvent.target.files[0]
                

 angular.module('app.filters', [])
  .filter 'localDate', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd/yyyy')

  .filter 'monthDay', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd')

  .filter 'mbCurrency', ($filter) ->
    angularCurrencyFilter = $filter('currency')
    (number) ->
      result = angularCurrencyFilter(number)
      if result[0] == '('
        '-' + result[1..-2]
      else
        result

  .filter 'typeString', ($filter) ->
    (typeInt) ->
      if typeInt == LineItemCollection.EXPENSE then 'Expense' else 'Income'

   .filter 'bnToFixed', ($window) ->
     (value, format) -> 
      if (typeof value == 'undefined' || value == null)
        return ''

      value.toFixed(2)

  .filter 'joinBy', () ->
    (input, delimiter) ->
      (input || []).join(delimiter || ',')
        