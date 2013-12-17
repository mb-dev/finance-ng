express = require('express')

RedisStore = require('connect-redis')(express)

module.exports = (app, config, passport) ->
  app.use(express.favicon())

  app.use(express.static(config.root + '/public'))
  
  if (process.env.NODE_ENV != 'test')
    app.use(express.logger('dev'))
  
  app.set('views', config.root + '/server/sections');
  app.set('view engine', 'jade');

  app.configure ->
    app.use(express.cookieParser(config.cookieSecret));

    app.use(express.bodyParser());

    sessionStore = new RedisStore(host: config.redis.host, port: config.redis.port, db: config.redis.db, ttl: 3600000)
    sessionStore.on 'disconnect', () ->
      console.log('Could not connect to redis/got disconnected');
      process.exit(1);

    app.use(express.session({
      secret: config.sessionSecret
      store: sessionStore
      cookie: { maxAge: 3600000 }
    }))

    app.use(passport.initialize());
    app.use(passport.session());

    app.use(app.router)

    app.use (err, req, res, next) ->
      console.log 'error'
      # treat as 404
      if err.message && (err.message.indexOf('not found') >= 0 || (err.message.indexOf('Cast to ObjectId failed') >= 0))
        return next()

      # log it
      # send emails if you want
      console.error(err.stack)

      # error page
      res.status(500).render('home/500', { error: err.stack })

    # assume 404 since no middleware responded
    app.use (req, res, next) ->
      res.status(404).render('home/404', {
        url: req.originalUrl,
        error: 'Not found'
      })
