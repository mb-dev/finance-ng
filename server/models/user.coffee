mongoose = require('mongoose')
Schema = mongoose.Schema

authTypes = ['google']

UserSchema = new Schema({
  name: { type: String, default: '' }
  email: { type: String, default: '' }
  provider: { type: String, default: '' }
  authToken: { type: String, default: '' }
  googleId: {type: String, default: ''}
  lastModifiedByApp: {type: Schema.Types.Mixed, default: {}}
})

UserSchema.path('email').validate((email) ->
  # if you are authenticating by any of the oauth strategies, don't validate
  return true if authTypes.indexOf(this.provider) != -1
  email.length
, 'Email cannot be blank')

mongoose.model('User', UserSchema)