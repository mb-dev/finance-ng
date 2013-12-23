# JS Functions

# Other

class window.LineItemCollection extends Collection
  @EXPENSE = 1
  @INCOME = 0

  getItemsByMonthYear: (month, year, sortBy) ->
    Lazy(@collection).filter((item) -> 
      date = moment(item.event_date)
      date.month() == month && date.year() == year
    ).sortBy(sortBy)

  getCategories: () ->
    Lazy(@collection).map((item) -> item.category_name).uniq().sortBy(Lazy.identity).toArray()

class BudgetItemCollection extends Collection
  getYearRange: ->
    Lazy(@collection).pluck('budget_year').uniq().sortBy(Lazy.identity).toArray()

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
      date = moment(item.event_date)
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
  .factory 'mdb', ($http, $q, $sessionStorage, $localStorage, $rootScope) ->
    tablesList = {
      memories: 'memories'
      events: 'events'
      people: 'people'
      categories: 'categories'
    }
    db = new Database('memoryng', $http, $q, $sessionStorage, $localStorage)
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
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList) ->
        db.saveTables(tableList)
    }

  .factory 'fdb', ($http, $q, $sessionStorage, $localStorage, $rootScope) ->
    db = new Database('financeng', $http, $q, $sessionStorage, $localStorage)

    tablesList = {
      accounts: 'accounts',
      lineItems: 'lineItems',
      budgetItems: 'budgetItems',
      plannedItems: 'plannedItems'
      categories: 'categories'
    }
    tables = {
      accounts: db.createCollection(tablesList.accounts, new Collection($q, 'name'))
      lineItems: db.createCollection(tablesList.lineItems, new LineItemCollection($q, 'event_date'))
      budgetItems: db.createCollection(tablesList.budgetItems, new BudgetItemCollection($q, 'budget_year'))
      plannedItems: db.createCollection(tablesList.plannedItems, new Collection($q))
      categories: db.createCollection(tablesList.plannedItems, new SimpleCollection($q))
    }
    
    tables.lineItems.setItemExtendFunc (item) ->
      item.$isExpense = ->
        @type == LineItemCollection.EXPENSE
      item.$isIncome = ->
        @type == LineItemCollection.INCOME
      item.$eventDate = ->
        moment(@event_date)
      item.$multiplier = ->
        if @type == LineItemCollection.EXPENSE then -1 else 1
      item.$signedAmount = ->
        parseFloat(@amount) * @$multiplier()

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
      categories: ->
        tables.categories
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
      getTables: (tableList) =>
        defer = $q.defer()
        db.getTables(tableList).then((db) =>
          defer.resolve(accessFunc)
        , (err) =>
          defer.reject(err)
        )
        defer.promise

      saveTables: (tableList) ->
        db.saveTables(tableList)
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
 
 angular.module('app.filters', [])
  .filter 'localDate', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd/yyyy')

  .filter 'monthDay', ($filter) ->
    angularDateFilter = $filter('date')
    (theDate) ->
      angularDateFilter(theDate, 'MM/dd')

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