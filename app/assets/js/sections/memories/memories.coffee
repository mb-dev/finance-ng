angular.module('app.controllers')
  .controller 'MemoriesIndexController', ($scope, $routeParams, $location, db) ->
    $scope.currentDate = moment()
    if $routeParams.month && $routeParams.year
      $scope.currentDate.year(+$routeParams.year).month(+$routeParams.month - 1)

    $scope.items = db.memories().getItemsByMonthYear($scope.currentDate.month(), $scope.currentDate.year()).toArray().reverse()
    $scope.nextMonth = ->
      $scope.currentDate.add('months', 1)
      $location.path('/memories/' + $scope.currentDate.year().toString() + '/' + ($scope.currentDate.month()+1).toString())
    $scope.prevMonth = ->
      $scope.currentDate.add('months', -1)
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
    if $location.$$url.indexOf('new') > 0
      $scope.type = 'new'
      $scope.categoryNames = ''
      $scope.title = 'New memory'
      $scope.item = {date: moment().valueOf()}
      updateFunc = db.memories().insert
      $scope.item.people = [parseInt($routeParams.personId, 10)] if $routeParams.personId
      $scope.item.date = parseInt($routeParams.date, 10) if $routeParams.date
    else
      $scope.type = 'edit'
      $scope.title = 'Edit memory'
      $scope.item = db.memories().findById($routeParams.itemId)
      updateFunc = db.memories().editById

    if $routeParams.eventId
      $scope.event = db.events().findById($routeParams.eventId)
      $scope.item.events ||= []
      $scope.item.events.push($scope.event.id) if $scope.item.events.indexOf($scope.event.id) < 0
      $scope.item.date = $scope.event.date if $scope.type == 'new'

    if $routeParams.category
      $scope.item.categories ||= []
      $scope.item.categories.push($routeParams.category) if $scope.item.categories.indexOf($routeParams.category) < 0

    if $routeParams.parentMemoryId
      $scope.parentMemory = db.memories().findById($routeParams.parentMemoryId)
      $scope.item.parentMemoryId = $scope.parentMemory.id

    $scope.onSubmit = ->
      updateFunc($scope.item)
      db.categories().findOrCreate($scope.item.categories)

      onSuccess = -> 
        memoryDate = moment($scope.item.date)
        $location.path($routeParams.returnto || '/memories/' + memoryDate.format('YYYY/MM'))
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

  .controller 'MemoriesAddMentionController', ($scope, $routeParams, $location, db) ->
    associateCheck = null
    associate = null
    unassociate = null
    onSuccess = null

    $scope.availableMemories = []
    $scope.associatedMemories = []
    $scope.changedMemories = {}

    if $routeParams.eventId
      $scope.event = db.events().findById($routeParams.eventId)
      associateCheck = (memory) -> memory.mentionedIn && memory.mentionedIn.indexOf($scope.event.id) >= 0
      associate = (memory) -> 
        memory.mentionedIn ||= []
        memory.mentionedIn.push($scope.event.id)
      unassociate = (memory) -> memory.mentionedIn.splice(memory.mentionedIn.indexOf($scope.event.id), 1)
      onSuccess = -> $location.url("/events/#{$scope.event.id}")
    else if $routeParams.personId
      $scope.person = db.people().findById($routeParams.personId)
      associateCheck = (memory) -> memory.mentionedTo && memory.mentionedTo.indexOf($scope.person.id) >= 0
      associate = (memory) -> 
        memory.mentionedTo ||= [] 
        memory.mentionedTo.push($scope.person.id)
      unassociate = (memory) -> memory.mentionedTo.splice(memory.mentionedTo.indexOf($scope.person.id), 1)
      onSuccess = -> $location.url("/people/#{$scope.person.id}")

    memoriesGrouped = db.memories().getAll().reverse().groupBy (memory) -> if associateCheck(memory) then 'associated' else 'unassociated'

    $scope.availableMemories = memoriesGrouped.get('unassociated') || []
    $scope.associatedMemories = memoriesGrouped.get('associated') || []

    $scope.associateMemory = (memoryId, memory, index) ->
      associate(memory)
      db.memories().editById(memory)
      $scope.availableMemories.splice(index, 1)
      $scope.associatedMemories.unshift(memory)

    $scope.unAssociateMemory = (memoryId, memory, index) ->
      unassociate(memory)
      db.memories().editById(memory)
      $scope.associatedMemories.splice(index, 1)
      $scope.availableMemories.unshift(memory)

    $scope.saveChanges = ->
      db.saveTables([db.tables.memories]).then(onSuccess)