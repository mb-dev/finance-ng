resolvedPromise = ->
  deferred = RSVP.defer()
  deferred.resolve()
  deferred.promise

angular.module('app.controllers')
  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db, $modal) ->
    accounts = {}
    accountIndex = 0
    applyDateChanges = ->
      filter = {}
      filter.date = {month: $scope.currentDate.month(), year: $scope.currentDate.year()}
      filter.categories = $routeParams.categories.split(',') if $routeParams.categories
      filter.accountId = parseInt($routeParams.accountId, 10) if $routeParams.accountId
      filter.sortBy = 'originalDate' if $routeParams.sortBy == 'originalDate'
      db.lineItems().getByDynamicFilter(filter).then (lineItems) -> $scope.$apply ->
        $scope.lineItems = lineItems.reverse()
        db.lineItems().addHelpers($scope.lineItems)
        for lineItem in lineItems
          unless accounts[lineItem.accountId]?
            accounts[lineItem.accountId] = accountIndex
            accountIndex += 1
          lineItem.$accountIndex = accounts[lineItem.accountId]

        
    $scope.currentDate = moment()
    refresh = ->
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
    refresh()

    $scope.createLineItem = ->
      db.preloaded.item = null
      dialog = $modal({template: '/partials/line_items/formDialog.html', show: true})
      dialog.$scope.$on 'itemEdited', (event) ->
        refresh()

    $scope.editLineItem = (item) ->
      db.preloaded.item = angular.copy(item)
      dialog = $modal({template: '/partials/line_items/formDialog.html', show: true})
      dialog.$scope.$on 'itemEdited', (event) ->
        refresh()

    $scope.splitLineItem = (item) ->
      db.preloaded.item = angular.copy(item)
      dialog = $modal({template: '/partials/line_items/splitDialog.html', show: true})
      dialog.$scope.$on 'itemEdited', (event) ->
        refresh()


    $scope.nextMonth = ->
      $scope.currentDate.add(1, 'months')
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add(-1, 'months')
      $location.path('/line_items/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.deleteItem = (item) ->
      db.lineItems().deleteItemAndRebalance(item)
      db.saveTables([db.tables.lineItems]).then ->
        $scope.lineItems.splice($scope.lineItems.indexOf(item), 1)

      
    return

  .controller 'LineItemsFormController', ($scope, $routeParams, $location, financeidb, errorReporter) ->
    db = financeidb
    $scope.tags = ['Cash', 'Exclude from Reports']

    db.loaders.loadCategories().then(db.loaders.loadPayees).then(db.loaders.loadAccounts).then -> $scope.$apply ->
      $scope.allCategories = db.preloaded.categories
      $scope.allPayees = db.preloaded.payees
      $scope.accounts = db.preloaded.accounts

      if($scope.accounts.length == 0)
        $scope.showError('No acounts found, add some on the main page')
      else if !$scope.item.accountId
        $scope.item.accountId = $scope.accounts[0].id

    updateFunc = null
    if db.preloaded.item
      $scope.type = 'edit'
      $scope.title = 'Edit line item'
      $scope.item = db.preloaded.item
      $scope.item.amount = parseFloat($scope.item.amount)
      updateFunc = db.lineItems().updateById 
    else
      $scope.type = 'new'
      $scope.title = 'New line item'
      # TODO: Allow defining any account as default
      $scope.item = {type: 1, date: moment().valueOf(), tags: ['Cash'], accountId: null}
      updateFunc = db.lineItems().insert

    $scope.onChangePayee = ->
      # not sure if I want this:
      
      # return if !$scope.item.payeeName
      # processingRule = fdb.processingRules().get('name:' + $scope.item.payeeName)

    onSuccess = -> $scope.$apply ->
      if $scope.$hide?
        $scope.$emit('itemEdited', $scope.item)
        $scope.$hide()
      else
        itemDate = moment($scope.item.date)
        $location.url($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()+1}")

    $scope.onSubmit = ->
      if $scope.type == 'new'
        $scope.item.originalDate = $scope.item.date
      db.categories().findOrCreate($scope.item.categoryName)
      .then -> db.payees().findOrCreate($scope.item.payeeName)
      .then -> updateFunc($scope.item)
      .then -> db.lineItems().reBalance($scope.item)
      .then -> db.saveTables([db.tables.lineItems, db.tables.categories, db.tables.payees]).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'LineItemsSplitController', ($scope, $routeParams, $location, financeidb, errorReporter) ->
    db = financeidb
    db.loaders.loadCategories().then(db.loaders.loadPayees).then(db.loaders.loadAccounts).then -> $scope.$apply ->
      $scope.allCategories = db.preloaded.categories

    $scope.title = 'Split Line Item'
    $scope.item = db.preloaded.item
    $scope.newItem = db.lineItems().cloneLineItem($scope.item)
    $scope.newItem.categoryName = ''
    $scope.meta = {}
    $scope.meta.amount = new BigNumber($scope.item.amount)
    $scope.meta.newAmount = 0
    $scope.meta.amountLeft = $scope.item.amount

    $scope.onChangeSplitAmount = ->
      if $scope.meta.newAmount
        $scope.meta.amountLeft = parseFloat($scope.meta.amount.minus($scope.meta.newAmount).toFixed(2))

    onSuccess = -> $scope.$apply ->
      if $scope.$hide?
        $scope.$emit('itemEdited', $scope.item)
        $scope.$hide()
      else
        itemDate = moment($scope.item.date)
        $location.url($routeParams.returnto || "/line_items/#{itemDate.year()}/#{itemDate.month()}")
      

    $scope.onSubmit = ->
      $scope.item.amount = parseFloat($scope.meta.amountLeft.toFixed(2)).toString()
      $scope.newItem.amount = parseFloat($scope.meta.newAmount.toFixed(2)).toString()
      db.categories().findOrCreate($scope.newItem.categoryName)
      .then ->  db.lineItems().updateById($scope.item)
      .then ->  db.lineItems().insert($scope.newItem)
      .then ->  db.lineItems().reBalance($scope.item)
      .then ->  db.saveTables([db.tables.lineItems, db.tables.categories])
      .then(onSuccess)

  .controller 'LineItemShowController', ($scope, $routeParams, db) ->
    $scope.item = db.preloaded.item
    $scope.account = db.preloaded.account