angular.module('app.controllers')
  .controller 'MemoriesIndexController', ($scope, $routeParams, $location, db) ->
    applyDateChanges = ->
      $scope.items = db.memories().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).toArray().reverse()

    $scope.currentDate = moment()
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    applyDateChanges()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      applyDateChanges()
      $location.path('/memories/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
      applyDateChanges()
      $location.path('/memories/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())

    return

  .controller 'MemoriesFormController', ($scope, $routeParams, $location, db, errorReporter) ->
    $scope.allCategories = db.categories().getAll().toArray()
    $scope.people = db.people().getAll().toArray()
    $scope.categoriesOptions = {
      multiple: true,
      simple_tags: true,
      tags: $scope.allCategories
    }
    $scope.peopleOptions = {
      multiple: true
    }
    updateFunc = null
    if Lazy($location.$$url).indexOf('new') > 0
      $scope.type = 'new'
      $scope.categoryNames = ''
      $scope.title = 'New memory'
      $scope.item = {date: moment().valueOf()}
      updateFunc = db.memories().insert
      $scope.item.people = [$routeParams.personId] if $routeParams.personId
    else
      $scope.type = 'edit'
      $scope.title = 'Edit memory'
      $scope.item = db.memories().findById($routeParams.itemId)
      updateFunc = db.memories().editById

    if $routeParams.eventId
      $scope.event = db.events().findById($routeParams.eventId)
      $scope.item.events ||= []
      $scope.item.events.push($routeParams.eventId) if $scope.item.events.indexOf($routeParams.eventId) < 0
      $scope.item.date = $scope.event.date if $scope.type == 'new'

    if $routeParams.category
      $scope.item.categories ||= []
      $scope.item.categories.push($routeParams.category) if $scope.item.categories.indexOf($routeParams.category) < 0

    if $routeParams.parentMemoryId
      $scope.parentMemory = db.memories().findById($routeParams.parentMemoryId)
      $scope.item.parentMemoryId = $routeParams.parentMemoryId

    $scope.onSubmit = ->
      updateFunc($scope.item)
      db.categories().findOrCreate($scope.item.categories)

      onSuccess = -> 
        $location.path($routeParams.returnto || '/memories/')
      saveTables = -> db.saveTables([db.tables.memories, db.tables.categories])
      saveTables().then(onSuccess, errorReporter.errorCallbackToScope($scope))

  .controller 'MemoriesShowController', ($scope, $routeParams, db, $location) ->
    $scope.item = db.memories().findById($routeParams.itemId)
    $scope.people = db.people().findByIds($scope.item.people)
    if $scope.item.events
      $scope.events = db.events().findByIds($scope.item.events)
    if $scope.item.parentMemoryId
      $scope.parentMemory = db.memories().findById($scope.item.parentMemoryId)
    $scope.childMemories = db.memories().getItemsByParentMemoryId($scope.item.id).toArray()

    $scope.deleteItem = ->

      # delete child memory
      $scope.childMemories.forEach (childMemory) ->
        db.memories().deleteById(childMemory.id)

      # delete memory
      db.memories().deleteById($scope.item.id)

      db.saveTables([db.tables.memories]).then ->
        if $scope.item.events
          $location.path('/events/' + $scope.item.events[0])
        else
          date = moment($scope.item.events[0])
          $location.path('/memories/' + date.year().toString() + '/' + date.month().toString())