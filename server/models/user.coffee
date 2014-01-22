mongoose = require('mongoose')
bcrypt = require('bcrypt')

SALT_WORK_FACTOR = 10

Schema = mongoose.Schema

authTypes = ['google']

UserSchema = new Schema({
  name: { type: String, default: '' }
  email: { type: String, default: '', unique: true }
  password: { type: String }
  provider: { type: String, default: '' }
  authToken: { type: String, default: '' }
  googleId: {type: String, default: ''}
  approved: {type: Boolean, default: false}
  lastModifiedDate: {type: Schema.Types.Mixed, default: {}}
})

UserSchema.path('email').validate((email) ->
  # if you are authenticating by any of the oauth strategies, don't validate
  return true if authTypes.indexOf(this.provider) != -1
  email.length
, 'Email cannot be blank')

UserSchema.pre 'save', (next) ->
  user = this
  return next() if !user.isModified('password')
  bcrypt.genSalt SALT_WORK_FACTOR, (err, salt) ->
    return next(err) if err
    bcrypt.hash user.password, salt, (err, hash) ->
      return next(err) if err
      user.password = hash
      next()
    
UserSchema.methods.comparePassword = (candidatePassword, callback) ->
  bcrypt.compare candidatePassword, this.password, (err, isMatch) ->
    return callback(err) if err
    callback(null, isMatch)

UserSchema.methods.generateRandomToken = () ->
  user = this
  chars = "_!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
  token = new Date().getTime() + '_'
  for x in [0..15]
    i = Math.floor( Math.random() * 62 );
    token += chars.charAt( i );
  token

exports.User = mongoose.model('User', UserSchema)
