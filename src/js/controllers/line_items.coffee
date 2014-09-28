resolvedPromise = ->
  deferred = RSVP.defer()
  deferred.resolve()
  deferred.promise

angular.module('app.controllers')
  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      filter = {}
      filter.date = {month: $scope.currentDate.month(), year: $scope.currentDate.year()}
      filter.categories = $routeParams.categories.split(',') if $routeParams.categories
      filter.accountId = parseInt($routeParams.accountId, 10) if $routeParams.accountId
      db.lineItems().getByDynamicFilter(filter).then (lineItems) -> $scope.$apply ->
        $scope.lineItems = lineItems.toArray().reverse()
        db.lineItems().addHelpers($scope.lineItems)
        
    $scope.currentDate = moment()
    if $routeParams.month? && $routeParams.year?
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)
      applyDateChanges()
    else if($routeParams.year? && $routeParams.groupedLabel?)
      $scope.currentDate.year(+$routeParams.year).month(0)
      db.lineItems().getByDynamicFilter({date: {year: $scope.currentDate.year()}, groupedLabel: $routeParams.groupedLabel}).toArray().reverse()
    else if($routeParams.year? && $routeParams.categoryName?)
      $scope.currentDate.year(+$routeParams.year).month(0)
      db.lineItems().getByDynamicFilter({date: {year: $scope.currentDate.year()}, categoryName: $routeParams.categoryName}).toArray().reverse()
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
    $scope.tags = ['Cash', 'Exclude from Reports']

    updateFunc = null
    if $location.$$url.indexOf('new') > 0
      $scope.type = 'new'
      $scope.title = 'New line item'
      # TODO: Allow defining any account as default
      $scope.item = {type: 1, date: moment().valueOf(), tags: ['Cash'], accountId: null}
      updateFunc = db.lineItems().insert
    else
      $scope.type = 'edit'
      $scope.title = 'Edit line item'
      $scope.item = db.preloaded.item
      $scope.item.amount = parseFloat($scope.item.amount)
      updateFunc = db.lineItems().updateById
      
    $scope.allCategories = db.preloaded.categories
    $scope.allPayees = db.preloaded.payees
    $scope.accounts = db.preloaded.accounts
      
    if($scope.accounts.length == 0)
      $scope.showError('No acounts found, add some on the main page')
    else if !$scope.item.accountId
      $scope.item.accountId = $scope.accounts[0].id

    $scope.onChangePayee = ->
      # not sure if I want this:
      
      # return if !$scope.item.payeeName
      # processingRule = fdb.processingRules().get('name:' + $scope.item.payeeName)

    onSuccess = -> $scope.$apply ->
      itemDate = moment($scope.item.date)
      $location.path($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()+1}")

    $scope.onSubmit = ->
      if $scope.type == 'new'
        $scope.item.originalDate = $scope.item.date
      db.categories().findOrCreate($scope.item.categoryName)
      .then -> db.payees().findOrCreate($scope.item.payeeName)
      .then -> updateFunc($scope.item)
      .then -> db.lineItems().reBalance($scope.item)
      .then -> db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees]).then(onSuccess, errorReporter.errorCallbackToScope($scope))

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