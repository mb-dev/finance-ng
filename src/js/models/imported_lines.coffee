class ImportedLinesCollection extends IndexedDbCollection
  findByContent: (content) ->
    index = Lazy(@collection).pluck('content').indexOf(content)
    return null if index < 0
    @collection[index]