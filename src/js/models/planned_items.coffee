class PlannedItemCollection extends IndexedDbCollection
  getAllForYear: (year) ->
    new RSVP.Promise (resolve, reject) =>
      @dba.plannedItems.query('eventDateStart').only(year).execute().then (results) ->
        resolve(results)