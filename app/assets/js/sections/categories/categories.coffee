angular.module('app.controllers')
  .controller 'CategoriesIndexController', ($scope, $routeParams, $location, db) ->
    categories = db.categories().getAll()
    categoryData = {}

    categories.each (item) ->
      categoryData[item] = []

    db.memories().getAllParentMemories().each (item) ->
      Lazy(item.categories).each (categoryName) ->
        categoryData[categoryName].push({type: 'memories', modifiedAt: item.modifiedAt, data: item, date: moment(item.modifiedAt).format('L')})

    db.events().getAll().each (item) ->
      Lazy(item.categories).each (categoryName) ->
        categoryData[categoryName].push({type: 'events', modifiedAt: item.modifiedAt, data: item, date: moment(item.modifiedAt).format('L')})

    categories.each (item) ->
      if categoryData[item].length == 0
        delete categoryData[item]
      else
        categoryData[item].sort().reverse()

    $scope.categories = categories.toArray().sort()
    $scope.categoryData = categoryData

    return