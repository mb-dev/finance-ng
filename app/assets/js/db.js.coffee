class Collection
  constructor: ->
    @collection = []

  findById: (id) ->
    Lazy(@collection).find (item) -> item.id == id

  insert: (details) ->
    if !details.id
      id = moment().unix()
      details.id = id

    @collection.push(details)
    details.id

  length: ->
    @collection.length

  removeById: (id) ->
    item = @findById(id)
    index = @collection.indexOf(item)
    @collection.splice(index, 1)

class Database
  constructor: ->
    @db = {
      accounts: new Collection
      line_items: new Collection
      budget_items: new Collection
      planned_items: new Collection
      user: {}
    }
    if root.env != 'ci'
      @importDatabase()
    
  accounts: ->
    @db.accounts

  lineItems: ->
    @db.line_items

  budgetItems: ->
    @db.budget_items

  user: ->
    @db.user

  plannedItems: ->
    @db.planned_items

  importDatabase: ->
    dateToJsStorage = (dateString) -> 
      moment(dateString).unix()

    cleanItem = (item) ->
      delete item['_id']
      delete item['processing_rule_ids']
      delete item['encrypted_password']

      item.id = item['_id']
      item.created_at = moment(item.created_at).unix() if item.created_at
      item.updated_at = moment(item.updated_at).unix() if item.updated_at

    importFile = (fileName, collection, itemConvert) ->
      $.getJSON fileName, (data) ->
        Lazy(data).each (item) ->
          itemConvert(item) if itemConvert
          collection.insert(item)

    
    importFile '/dumps/Account.json', @db.accounts()
    importFile '/dumps/LineItem.json', @db.lineItems(), (item) ->
      item.event_date = dateToJsStorage(item.event_date)
      item.original_event_date = dateToJsStorage(item.original_event_date) if item.original_event_date
    importFile '/dumps/BudgetItem.json', @db.budgetItems()
    importFile '/dumps/PlannedItem.json', @db.plannedItems(), (item) ->
      item.event_date_start = dateToJsStorage(item.event_date)
      item.event_date_end = dateToJsStorage(item.event_date)

        
