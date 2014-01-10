setupFilesystem = ($q, fileSystem) =>
  defer = $q.defer()

  fileSystem.getFolderContents('/db').then ->
    defer.resolve('ok')
  , ->
    fileSystem.requestQuotaIncrease(20)
    fileSystem.createFolder('/db').then ->
      defer.resolve('ok')
    , ->
      defer.reject('failed')

angular.module('app.controllers')
   .controller 'UserLoginController', ($scope, $window) ->
    $scope.loginOauth = (provider) ->
      $window.location.href = '/auth/' + provider;

  .controller 'UserKeyController', ($scope, $window, $localStorage, $location, fileSystem, $q) ->
    setupFSState = setupFilesystem($q, fileSystem)
    $scope.key = ''

    $scope.onSubmit = ->
      $localStorage.encryptionKey = $scope.key

      setupFilesystem($q, fileSystem).then ->
        $location.path('/line_items')
      , () ->
        $scope.error = 'Failed to set file system'

  .controller 'UserProfileController', ($scope, $window, $localStorage, $location, fdb, mdb) ->
    fdb.getTables(financeTables).then(mdb.getTables(memoryTables)).then( ->
      # do something
    () ->
      $scope.error = "failed to fetch tables"
    )

    financeTables = Object.keys(fdb.tables)
    memoryTables = Object.keys(mdb.tables)
    $scope.downloadBackup = ->
      fetchTables = -> fdb.getTables(financeTables).then(mdb.getTables(memoryTables))
      
      fetchTables().then ->
        content = {}
        angular.extend(content, fdb.dumpAllCollections(financeTables))
        angular.extend(content, mdb.dumpAllCollections(memoryTables))

        blob = new Blob([angular.toJson(content)], {type: 'application/json'})

        link = document.createElement('a')
        link.href = window.URL.createObjectURL(blob)
        link.download = 'financeNg' + moment().valueOf().toString() + '-backup.json'
        document.body.appendChild(link)
        link.click()

  .controller 'UserEditProfileController', ($scope, $window, $localStorage, $location) ->
    $scope.onSubmit = ->
      $localStorage.encryptionKey = $scope.key
      $location.path('/line_items')

