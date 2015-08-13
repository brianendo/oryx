coffee_script = require 'coffee-script'
http = require 'http'
express = require 'express'
session = require 'express-session'
mongo = require 'mongodb'
#grid = mongo.Grid
mongoose = require 'mongoose'
assert = require 'assert'
#formidable = require 'formidable'
#util = require 'util'
jade = require 'jade'
passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy
LocalStrategy = require('passport-local').Strategy
bodyParser = require 'body-parser'
cookieParser = require 'cookie-parser'
logger = require 'morgan'
methodOverride = require 'method-override'


Event = require './models/event_model.coffee'
User = require './models/user_model.coffee'

passport.serializeUser (user, done) ->
    console.log('serializeUser: ' + user.id)
    done null, user.username

passport.deserializeUser (user, done) ->
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
		User.findOne {username: user}, (err, user) ->
			done null, user

###
passport.use new FacebookStrategy { clientID: 975386195846106, clientSecret: "247f2b170ff3429fe6a4cdebca425325", callbackURL: "http://jackpack.org:2999/auth/facebook/callback", enableProof: false }, (accessToken, refreshToken, profile, done) ->
	console.log profile.id + ' is logging in'
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
		console.log "We are connected" if !err
		User.findOne {fb : profile.id}, (err, user) ->
			if user == null				
				newuser = new User({fb : profile.id, name : { first: profile.name.givenName, last: profile.name.familyName }, email: profile.email })
				newuser.save (err, result) ->
					assert.equal err, null 
					console.log "Created a new user"
			return done(err, user)
###

passport.use new LocalStrategy (username, password, done) ->
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
		console.log 'We are connected' if !err
		User.findOne { username: username }, (error, user) ->
			if user == null
				return done null, false, { message: 'Incorrect username.' }
			if user.password != password
				return done null, false, { message: 'Incorrect password.' }
			return done null, user 

app = express()

app.configure () ->
	app.locals.title = 'Oryx'
	app.set('views', './views')
	app.set 'view engine', 'jade'
	app.use '/js', express.static 'js'
	app.use '/css', express.static 'css'
	app.use '/img', express.static 'img'
	app.use session({ secret: 'keyboard cat' })
	app.use passport.initialize()
	app.use passport.session()
	#app.use logger()
	app.use cookieParser()
	app.use bodyParser()
	app.use bodyParser.urlencoded({ extended: true})
	app.use methodOverride()

app.get '/', (req, res) ->
	console.log req.user
	if typeof(req.user) == 'undefined'
		res.render 'form', {alert: req.query.alert, title: "Home", fields: ['username', 'password'], action: "/login", submit: "login" }
	else
		console.log req.user.username
		feed = []
		for friend in req.user.friends
			query = User.find {_id : friend._id}
			query.select 'posts'
			query.exec (err, posts) ->
				feed.concat posts[-10..]
		res.render 'feed.jade', {alert : req.query.alert, feed: feed, name: req.user.username}
	
app.get '/logout', (req, res) ->
	req.logout
	res.redirect '/'

app.get '/addevent', (req, res) ->
	res.render 'form', {title: "add event", fields: ["email", "password"], action: "/auth", submit: "go" }

app.get '/signup', (req, res) ->
        res.render 'form', {title: "Sign Up", fields: ["first", "last", "username", "password"], action: "/signup", submit: "Create Account"}

app.post '/signup', (req, res) ->
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
		console.log "We are connected" if !err
		User.find {username: req.body.username}, (err, user) ->
			if user != null
				res.redirect '/?alert=2'
			else
				newuser = new User({username: req.body.username, password: req.body.password, name : { first: req.body.first, last: req.body.last } })
				newuser.save (err, result) ->
					assert.equal err, null 
					console.log "Added user"
					res.redirect '/login'

app.get '/user/:username', (req, res) ->
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
		User.findOne {username: req.params.username}, (err, user) ->
			res.render 'users', {users: [user]}
    
app.get '/friends', (req, res) ->
	console.log req.user.username
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
		User.find { username: {$in : req.user.friends} }, (err, users) ->
			res.render 'users', {users: users, alert: req.query.alert}

app.post '/addfriend/:username', (req, res) ->
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
		console.log "We are connected" if !err
		User.update {username: req.user.username}, { $push: {'friends': req.params.username} }, (err, result) ->
			if !err
				res.redirect '/friends?alert=3'


app.get '/auth/facebook/callback', passport.authenticate('facebook', { failureRedirect: '/' }), (req, res) ->
    res.send 'Success'
					
app.post '/auth/facebook', passport.authenticate('facebook')

app.get '/login', (req, res) ->
    res.render 'form', { title: "Login", fields: ["username", "password"], action: "/login", submit: "login" }

app.post '/login', passport.authenticate('local', { successRedirect: '/?alert=1', failureRedirect: '/login?alert=0', failureFlash: true }), (req, res) ->
	console.log req.user.username
	res.redirect '/?alert=1'


app.post '/addevent', (req, res) ->
	store = (event) ->
		mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
			console.log "We are connected" if !err
			event.save (err, result) ->
				assert.equal err, null
				User.update {username: req.user.username}, {$push: {'posts': result._id} }
				console.log "Created a new event"
	
	form = new formidable.IncomingForm()
	form.parse req, (err, fields, files) ->
		res.end util.inspect({fields: fields, files: files})
		artist = fields.artist
		location = fields.location
		date = fields.date
	form.on 'end', (fields, files) ->
		temp_path = this.openedFiles[0].path
		file_name = this.openedFiles[0].name
		new_location = 'uploads/' + file_name
		newevent = new Event({artist: artist, imageurl: new_location, location: location, date: date, user: req.user.username})
		store newevent
		fs.copy temp_path, new_location, (err) ->
			if err 
				console.error err 
			else 
				console.log 'success!'		
		console.log req.body
			
app.post '/feed', (req, res) ->
	feed = []
	json = JSON.parse req.body
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
			console.log "We are connected" if !err
			User.findOne {_id : json.id}, 'friends', (err, friends) ->
				for friend in friends
					query = User.find {_id : friend._id}
					query.select 'posts'
					query.exec (err, posts) ->
						feed.concat posts[-10..]
	res.json feed

app.get '/profile', (req, res) ->
	json = JSON.parse req.body

app.get '/event', (req, res) ->
	json = JSON.parse req.body
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
			console.log "We are connected" if !err
			Event.findOne {_id: json.id}, (err, events) ->
				res.json events

server = app.listen 2999, () ->
	host = server.address().address
	port = server.address().port
	console.log 'Server running on' , host, port