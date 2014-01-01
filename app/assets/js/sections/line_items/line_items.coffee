angular.module('app.controllers')
  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      filter = {}
      filter.date = {month: $scope.currentDate.month(), year: $scope.currentDate.year()}
      filter.categories = $routeParams.categories.split(',') if $routeParams.categories
      filter.accountId = $routeParams.accountId if $routeParams.accountId
      $scope.lineItems = db.lineItems().getByDynamicFilter(filter).toArray().reverse()
        
    $scope.currentDate = moment()
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())

    return

  .controller 'LineItemsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = {
      name: 'categories'
      local: db.categories().getAll().toArray()
    }
    $scope.allPayees = {
      name: 'payees'
      local: db.payees().getAll().toArray()
    }
    $scope.tags = ['Cash', 'Exclude from Reports']
    $scope.accounts = db.accounts().getAll().toArray()

    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.type = 'new'
      $scope.title = 'New line item'
      $scope.item = {date: moment().valueOf(), tags: [], accountId: $scope.accounts[0].id}
      updateFunc = db.lineItems().insert
    else
      $scope.type = 'edit'
      $scope.title = 'Edit line item'
      $scope.item = db.lineItems().findById($routeParams.itemId)
      $scope.item.amount = parseFloat($scope.item.amount)
      updateFunc = db.lineItems().editById

    $scope.onChangePayee = ->
      # not sure if I want this:
      
      # return if !$scope.item.payeeName
      # processingRule = fdb.processingRules().get('name:' + $scope.item.payeeName)

    $scope.onSubmit = ->
      db.categories().findOrCreate($scope.item.categoryName)
      db.payees().findOrCreate($scope.item.payeeName)
      if $scope.type == 'new'
        $scope.item.originalDate = $scope.item.date
      updateFunc($scope.item)
      db.lineItems().reBalance($scope.item)
      onSuccess = -> 
        itemDate = moment($scope.item.date)
        $location.path($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()}")
      db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees]).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'LineItemShowController', ($scope, $routeParams, db) ->
    $scope.item = db.lineItems().findById($routeParams.itemId)
    $scope.account = db.accounts().findById($scope.item.accountId)