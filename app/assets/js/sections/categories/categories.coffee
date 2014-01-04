angular.module('app.controllers')
  .controller 'CategoriesIndexController', ($scope, $routeParams, $location, db) ->
    items = []

    db.memories().getAllParentMemories().each (item) ->
      Lazy(item.categories).each (categoryName) ->
        items.push({categoryName: categoryName, type: 'memories', modifiedAt: item.modifiedAt, data: item, itemDate: item.date, date: moment(item.modifiedAt).format('L')})

    db.events().getAll().each (item) ->
      Lazy(item.categories).each (categoryName) ->
        items.push({categoryName: categoryName, type: 'events', modifiedAt: item.modifiedAt, data: item, itemDate: item.date, date: moment(item.modifiedAt).format('L')})

    categoryData = Lazy(items).groupBy((item) -> item.categoryName).toObject()
    categories = Lazy(categoryData).keys().uniq().sortBy(Lazy.identity).toArray()

    categories.forEach (item) ->
      if categoryData[item].length == 0
        delete categoryData[item]
      else
        categoryData[item] = Lazy(categoryData[item]).sortBy((item) -> item.itemDate).reverse().toArray()

    $scope.categories = categories
    $scope.categoryData = categoryData

    return