angular.module('app.controllers')
  .controller 'EventsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.items = db.events().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).reverse().toArray()

    $scope.currentDate = moment()
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
      $location.path('/events/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()
      $location.path('/events/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())

    return

  .controller 'EventsFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = db.categories().getAll().toArray()
    $scope.allPeople = db.people().getAll().toArray()
    updateFunc = null

    if $location.$$url.indexOf('new') > 0
      $scope.title = 'New event'
      $scope.item = {date: moment().valueOf(), associatedMemories: []}
      updateFunc = db.events().insert
      $scope.item.participantIds = [parseInt($routeParams.personId, 10)] if $routeParams.personId
    else
      $scope.title = 'Edit event'
      $scope.item = db.events().findById($routeParams.itemId)
      updateFunc = db.events().editById

    $scope.onSubmit = ->
      db.categories().findOrCreate($scope.item.categories)
      onSuccess = -> $location.path($routeParams.returnto || '/events/' + $scope.item.id)
      saveTables = -> db.saveTables([db.tables.events, db.tables.categories])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'EventsShowController', ($scope, $routeParams, db) ->
    $scope.item = db.events().findById($routeParams.itemId)
    $scope.participants = $scope.item.$participants().getAll()
    $scope.associatedMemories = $scope.item.$memories().getAll().toArray()
    $scope.mentionedMemories = $scope.item.$mentioned().getAll().toArray()
    $scope.deleteItem = () ->
      db.events().deleteById($scope.item.id)
      db.saveTables([db.tables.events])
      $location.path('/events/')