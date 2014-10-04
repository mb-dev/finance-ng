class ImportedLinesCollection extends IndexedDbCollection
  getAllContentsAsObject: ->
    @getAll().then (importedLines) ->
      result = {}
      result[item.content] = true for item in importedLines
      result

  findByContent: (content) ->
    index = Lazy(@collection).pluck('content').indexOf(content)
    return null if index < 0
    @collection[index]