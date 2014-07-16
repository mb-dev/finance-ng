angular.module('app.controllers')
  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      filter = {}
      filter.date = {month: $scope.currentDate.month(), year: $scope.currentDate.year()}
      filter.categories = $routeParams.categories.split(',') if $routeParams.categories
      filter.accountId = parseInt($routeParams.accountId, 10) if $routeParams.accountId
      $scope.lineItems = db.lineItems().getByDynamicFilter(filter).toArray().reverse()
        
    $scope.currentDate = moment()
    if $routeParams.month? && $routeParams.year?
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)
      applyDateChanges()
    else if($routeParams.year? && $routeParams.groupedLabel?)
      $scope.currentDate.year(+$routeParams.year).month(0)
      $scope.lineItems = db.lineItems().getByDynamicFilter({date: {year: $scope.currentDate.year()}, groupedLabel: $routeParams.groupedLabel}).toArray().reverse()
    else if($routeParams.year? && $routeParams.categoryName?)
      $scope.currentDate.year(+$routeParams.year).month(0)
      $scope.lineItems = db.lineItems().getByDynamicFilter({date: {year: $scope.currentDate.year()}, categoryName: $routeParams.categoryName}).toArray().reverse()
    else
      applyDateChanges()

    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.deleteItem = (item) ->
      db.lineItems().deleteItemAndRebalance(item)
      db.saveTables([db.tables.lineItems]).then ->
        $scope.lineItems.splice($scope.lineItems.indexOf(item), 1)

      
    return

  .controller 'LineItemsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = db.categories().getAll().toArray()
    $scope.allPayees = db.payees().getAll().toArray()
    $scope.tags = ['Cash', 'Exclude from Reports']
    $scope.accounts = db.accounts().getAll().toArray()

    if($scope.accounts.length == 0)
      $scope.showError('No acounts found, add some on the main page')
      return

    updateFunc = null
    if $location.$$url.indexOf('new') > 0
      $scope.type = 'new'
      $scope.title = 'New line item'
      # TODO: Allow defining any account as default
      $scope.item = {type: 1, date: moment().valueOf(), tags: ['Cash'], accountId: $scope.accounts[0].id}
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
        $location.path($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()+1}")
      db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees]).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'LineItemsSplitController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = db.categories().getAll().toArray()

    $scope.item = db.lineItems().findById($routeParams.itemId)
    $scope.newItem = db.lineItems().cloneLineItem($scope.item)
    $scope.amount = new BigNumber($scope.item.amount)
    $scope.newAmount = 0
    $scope.amountLeft = $scope.item.amount

    $scope.onChangeSplitAmount = ->
      if $scope.newAmount
        $scope.amountLeft = parseFloat($scope.amount.minus($scope.newAmount).toFixed(2))

    $scope.onSubmit = ->
      $scope.item.amount = parseFloat($scope.amountLeft.toFixed(2)).toString()
      $scope.newItem.amount = parseFloat($scope.newAmount.toFixed(2)).toString()
      db.categories().findOrCreate($scope.newItem.categoryName)
      db.lineItems().editById($scope.item)
      db.lineItems().insert($scope.newItem)
      db.lineItems().reBalance($scope.item)
      db.saveTables([db.tables.lineItems, db.tables.categories]).then ->
        $location.path($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()}")

  .controller 'LineItemShowController', ($scope, $routeParams, db) ->
    $scope.item = db.lineItems().findById($routeParams.itemId)
    $scope.account = db.accounts().findById($scope.item.accountId)