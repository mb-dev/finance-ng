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
    $scope.people = db.people().getAll().toArray()
    $scope.allCategories = db.categories().getAll().toArray()
    updateFunc = null
    $scope.categoriesOptions = {
      multiple: true,
      simple_tags: true,
      tags: $scope.allCategories
    }
    $scope.peopleOptions = {
      multiple: true
    }

    if Lazy($location.$$url).endsWith('new')
      $scope.title = 'New event'
      $scope.item = {date: moment().valueOf(), associatedMemories: []}
      $scope.participants = []
      updateFunc = db.events().insert
      $scope.item.participantIds = [$routeParams.personId] if $routeParams.personId
    else
      $scope.title = 'Edit event'
      $scope.item = db.events().findById($routeParams.itemId)
      $scope.categories = $scope.item.categories
      $scope.participants = $scope.item.$participants()
      updateFunc = db.events().editById

    $scope.onSubmit = ->
      db.categories().findOrCreate($scope.item.categories)
      onSuccess = -> $location.path($routeParams.returnto || '/events/')
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

  .controller 'EventsAddMentionController', ($scope, $routeParams, $location, db) ->
    $scope.item = db.events().findById($routeParams.itemId)
    $scope.memories = db.memories().getAll().toArray()
    $scope.changedMemories = {}

    $scope.memories.forEach (memory) ->
      if memory.mentionedIn && memory.mentionedIn.indexOf($scope.item.id) >= 0
        memory.$associated = true
      else
        memory.$associated = false

    $scope.associateMemory = (memoryId, memory) ->
      memory.mentionedIn = [] if !memory.mentionedIn
      memory.mentionedIn.push($scope.item.id)
      db.memories().editById(memory)
      memory.$associated = true

    $scope.unAssociateMemory = (memoryId, memory) ->
      memory.mentionedIn.splice(memory.mentionedIn.indexOf($scope.item.id), 1)
      db.memories().editById(memory)
      memory.$associated = false      

    $scope.saveChanges = ->
      db.saveTables([db.tables.memories]).then ->
        $location.path("/events/#{$scope.item.id}")
