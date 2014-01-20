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
   .controller 'UserLoginController', ($scope, $window, userService, $localStorage, $location) ->
    $scope.user = {}

    $scope.loginOauth = (provider) ->
      $window.location.href = '/auth/' + provider;

    $scope.register = ->
      userService.register($scope.user).then (successResponse) ->
        $location.path('/login')
      , (failedResponse) ->
        $scope.error = failedResponse.data.error

    $scope.login = ->
      userService.login($scope.user).then (successResponse) ->
        response = successResponse.data
        $localStorage.user = {id: response.user.id, email: response.user.email, lastModifiedDate: response.user.lastModifiedDate}
        $location.path('/key')
      , (failedResponse) ->
        $scope.error = failedResponse.data.error      

  .controller 'UserKeyController', ($scope, $window, $localStorage, $location, fileSystem, $q) ->
    setupFSState = setupFilesystem($q, fileSystem)
    $scope.key = ''

    if !$localStorage.user
      $location.path('/login')

    $scope.onSubmit = ->
      $localStorage["#{$localStorage.user.id}-encryptionKey"] = $scope.key

      setupFilesystem($q, fileSystem).then ->
        $location.path('/line_items')
      , () ->
        $scope.error = 'Failed to set file system'

  .controller 'UserProfileController', ($scope, $window, $localStorage, $location, fdb, mdb) ->
    $scope.email = $localStorage.user.email
    
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
      $localStorage["#{$localStorage.user.id}-encryptionKey"] = $scope.key
      $location.path('/line_items')

  .controller 'WelcomePageController', ($scope, $window, $localStorage, $location) ->
    $scope.user = $localStorage.user
    
  .controller 'UserLogoutController', ($scope, $window, $localStorage, userService, $location) ->
    if $localStorage.user
      userService.logout().then ->
        delete $localStorage["#{$localStorage.user.id}-encryptionKey"]
        $localStorage.user = null
        $location.path('/login')
    else      
      $location.path('/login')

angular.module('app.services')
  .factory 'userService', ($http, $localStorage) ->
    register: (user) ->
      $http.post('/auth/register', user)
    login: (user) ->
      $http.post('/auth/login', user)
    logout: ->
      $http.post('/auth/logout')
