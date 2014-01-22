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
   .controller 'UserLoginController', ($scope, $window, userService, storageService, $location) ->
    $scope.user = {}

    $scope.loginOauth = (provider) ->
      $window.location.href = '/auth/' + provider;

    $scope.register = ->
      userService.register($scope.user).then (successResponse) ->
        $location.path('/login_success')
      , (failedResponse) ->
        $scope.error = failedResponse.data.error

    $scope.login = ->
      userService.login($scope.user).then (successResponse) ->
        response = successResponse.data
        storageService.setUserDetails(response.user)
        if storageService.getEncryptionKey()
          $location.path('/welcome')
        else
          $location.path('/key')
      , (failedResponse) ->
        $scope.error = "Failed to login: " + failedResponse.data.message      

  .controller 'LoginOAuthSuccessController', ($scope, $window, userService, storageService, $location) ->
    userService.checkLogin().then (successResponse) ->
      response = successResponse.data
      storageService.setUserDetails(response.user)
      if storageService.getEncryptionKey()
        $location.path('/welcome')
      else
        $location.path('/key')
    , (failedResponse) ->
        $location.path '/login'

  .controller 'UserKeyController', ($scope, $window, storageService, $location, fileSystem, $q) ->
    setupFSState = setupFilesystem($q, fileSystem)
    $scope.key = ''

    if !storageService.getUserDetails()
      $location.path('/login')

    $scope.onSubmit = ->
      storageService.setEncryptionKey($scope.key)

      setupFilesystem($q, fileSystem).then ->
        $location.path('/welcome')
      , () ->
        $scope.error = 'Failed to set file system'

  .controller 'UserProfileController', ($scope, $window, $localStorage, $location, fdb, mdb) ->
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
    checkLogin: (user) ->
      $http.get('/auth/check_login')
    register: (user) ->
      $http.post('/auth/register', user)
    login: (user) ->
      $http.post('/auth/login', user)
    logout: ->
      $http.post('/auth/logout')
