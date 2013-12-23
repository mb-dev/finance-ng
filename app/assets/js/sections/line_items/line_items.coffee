angular.module('app.controllers')
  .controller 'LineItemsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.lineItems = db.lineItems().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).toArray()

    $scope.currentDate = moment('2012-01-01')
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
    $scope.allCategories = db.categories().getAll().toArray()  

    updateFunc = null
    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New line item'
      $scope.item = {event_date: moment().format('L'), tags: []}
      updateFunc = db.lineItems().insert
    else
      $scope.title = 'Edit line item'
      $scope.item = db.lineItems().findById($routeParams.itemId)
      updateFunc = db.lineItems().editById
    $scope.accounts = db.accounts().getAll().toArray()

    $scope.onSubmit = ->
      onSuccess = -> $location.path('/line_items/')
      saveTables = -> db.saveTables([db.tables.lineItems])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'LineItemShowController', ($scope, $routeParams, db) ->
    $scope.item = db.lineItems().findById($routeParams.itemId)
    $scope.account = db.accounts().findById($scope.item.account_id)