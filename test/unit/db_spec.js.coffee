
# describe 'graph db', ->
#   beforeEach(module('app'))
#   beforeEach(inject((_$rootScope_, $q) ->
#     root.$q = $q
#   ))
#   it 'should allow associate connections', ->
#     db = new Database(root.$http, root.$q, root.$sessionStorage)
#     db.memoryGraph().associate('memoryToCategory', '1', '1')
#     expect(db.memoryGraph().isAssociated('memoryToCategory', '1', '1')).toEqual(true)
#     expect(db.memoryGraph().getAssociated('memoryToCategory', '1')).toEqual(['1'])

root = {}

describe 'Database', ->
  beforeEach(module('app'))
  beforeEach(inject(($httpBackend, $http, $q) ->
    root.timeNow = Date.now()
    root.$httpBackend = $httpBackend
    root.$http = $http
    root.appName = 'finance'
    root.fileSystemFileName = '/db/finance-people.json'
    root.tableName = 'people'
    root.authenticateURL = '/data/authenticate'
    root.getURL = '/data/datasets?' + $.param({appName: root.appName, tableList: [root.tableName]})
    root.authenticateOkResponseDataStale = {user: {email: 'a@a.com', lastModifiedByApp: {finance: root.timeNow}}}
    root.authenticateOkResponseDataOk = {user: {email: 'a@a.com', lastModifiedByApp: {finance: 1} }}
    root.getResponse = {tablesResponse: []}
    root.postResponse = {success: true}
    root.item = {name: 'Moshe'}
    root.originalName = 'Moshe'
    root.encryptionKey = "ABC"
    root.storageContent = {
      version: '1.0'
      data: [{id: 1, name: 'Moshe'}],
      modifiedAt: root.timeNow
    }
    root.sessionKey = root.appName + '-' + root.tableName
    root.getResponse.tablesResponse.push {
      name: root.tableName,
      content: sjcl.encrypt(root.encryptionKey, angular.toJson(root.storageContent))
    }
    
    root.$httpBackend.when('GET', root.getURL).respond(root.getResponse)
    root.$httpBackend.when('POST', root.postURL).respond(root.postResponse)
    root.$q = $q
    root.$sessionStorage = {}
    root.$localStorage = {encryptionKey: root.encryptionKey}
    root.fileSystemContent = {}
    root.fileSystem = {
      readFile: (fileName) =>
        defer = root.$q.defer()
        if root.fileSystemContent[fileName]
          defer.resolve(root.fileSystemContent[fileName])
        else
          defer.reject('no_file')
        defer.promise
      writeText: (fileName, content) =>
        defer = root.$q.defer()
        root.fileSystemContent[fileName] = content
        defer.resolve()
        defer.promise
    }
  ))
  afterEach ->
   root.$httpBackend.verifyNoOutstandingExpectation();
   root.$httpBackend.verifyNoOutstandingRequest();
  describe 'loadTables', ->
    it 'should load data from the network when session has no data', ->
      root.$httpBackend.when('GET', root.authenticateURL).respond(root.authenticateOkResponseDataOk)
      root.$httpBackend.expectGET(root.authenticateURL)
      root.$httpBackend.expectGET(root.getURL)
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage, root.fileSystem)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      db.getTables([root.tableName])
      root.$httpBackend.flush()
      expect(testCollection.getAll().toArray()).toEqual([{id: 1, name: 'Moshe'}])
      expect(root.fileSystemContent[root.fileSystemFileName]).toEqual(angular.toJson(root.storageContent))
    it 'should load data from the session when session has data', ->
      root.$httpBackend.when('GET', root.authenticateURL).respond(root.authenticateOkResponseDataOk)
      root.$httpBackend.expectGET(root.authenticateURL)
      root.fileSystemContent[root.fileSystemFileName] = angular.toJson(root.storageContent)
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage, root.fileSystem)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      db.getTables([root.tableName])
      root.$httpBackend.flush()
      expect(testCollection.getAll().toArray()).toEqual([{id: 1, name: 'Moshe'}])
  describe 'saveTables', ->
    it 'should save to the server', ->
      db = new Database(root.appName, root.$http, root.$q, root.$sessionStorage, root.$localStorage, root.fileSystem)
      testCollection = db.createCollection(root.tableName, new Collection(root.$q, 'name'))
      testCollection.insert(root.item)

      root.postURL = '/data/datasets?' + $.param({appName: root.appName, lastModifiedDate: testCollection.modifiedAt - 10})
      root.$httpBackend.expectPOST(root.postURL)

      db.saveTables([root.tableName])
      root.$httpBackend.flush()
      expect(JSON.parse(root.fileSystemContent[root.fileSystemFileName]).data[0].name).toEqual('Moshe')

describe 'SimpleCollection', ->
  

describe 'Box', ->
  it 'should allow setting values', ->
    item = {name: 'Groceries'}
    box = new Box()
    box.addRow(item)
    box.setColumns([0..11], ['expense', 'future_expense', 'planned_expense'])
    box.addToValue(item, 0, 'expense', 100)
    box.addToValue(item, 1, 'expense', 100)

    firstColumnValue = box.rowColumnValues(item)[0]
    expect(firstColumnValue.column).toEqual('0')
    expect(firstColumnValue.values.expense.toFixed(0)).toEqual('100')

    totals = box.rowTotals(item)
    expect(totals['expense'].toFixed(0)).toEqual('200')