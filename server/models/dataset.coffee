mongoose = require('mongoose')
Schema = mongoose.Schema

DataSetSchema = new Schema({
  _id: { type: Number, required: true }
  jsonData: { type: String, default: '' }
  deleted: { type: Boolean, default: false }
  createdAt: { type: Date }
  updatedAt: {type: Date}
})

DataSetSchema.pre 'save', (next) ->
  this.updatedAt = new Date();
  if !this.createdAt
    this.createdAt = new Date();
  next();

exports.DataSetSchema = DataSetSchema