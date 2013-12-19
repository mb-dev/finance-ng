angular.module('app.controllers')
  .controller 'EventsIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.items = db.events().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).toArray()

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
    updateFunc = null
    $scope.categoriesOptions = {
      multiple: true,
      simple_tags: true,
      tags: []
    }
    $scope.participantsOptions = {
      multiple: true
    }
    $scope.people = db.people().getAll().toArray()

    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New event'
      $scope.item = {date: moment().format('L')}
      $scope.categories = []
      $scope.participants = []
      updateFunc = db.events().insert
    else
      $scope.title = 'Edit event'
      $scope.item = db.events().findById($routeParams.itemId)
      $scope.categories = $scope.item.$categories()
      $scope.participants = $scope.item.$participants()
      updateFunc = db.events().editById

    $scope.onSubmit = ->
      updateFunc($scope.item)
      Lazy($scope.categories.split(',')).each (category) ->
        db.memoryGraph().associate(db.graphs.eventToCategory, $scope.item.id, category)
      onSuccess = -> $location.path('/events/')
      saveTables = -> db.saveTables([Database.EVENTS_TBL])
      updateFunc($scope.item).then(saveTables).then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'EventsShowController', ($scope, $routeParams, db) ->
    $scope.item = db.events().findById($routeParams.itemId)
    $scope.categories = $scope.item.$categories()
    $scope.participants = $scope.item.$participants()
    $scope.associatedMemories = $scope.item.$memories()