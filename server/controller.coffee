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
bodyParser = require 'body-parser'
cookieParser = require 'cookie-parser'
logger = require 'morgan'
methodOverride = require 'method-override'


Event = require './models/event_model.coffee'
User = require './models/user_model.coffee'

passport.serializeUser (user, done) ->
    console.log('serializeUser: ' + user.id)
    done null, user

passport.deserializeUser (user, done) ->
	done null, user.id

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

MongoClient = mongo.MongoClient
#ObjectId = require('mongodb').ObjectID

title = ''

app = express()
app.locals.title = 'Oryx'
app.set('views', './views')
app.set 'view engine', 'jade'
app.use express.static '/'
app.use passport.initialize()
app.use passport.session()
#app.use logger()
app.use cookieParser()
app.use bodyParser()
app.use methodOverride()
app.use session({ secret: 'keyboard cat' })

app.get '/', (req, res) ->
	#req.user = passport.deserializeUser
	#console.log req.user
	if !req.user
		res.render 'index.jade', {title: "index", fields: [], action: "/auth/facebook", submit: "login" }
	else
		console.log req.user.id
		###
		feed = []
		mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
			console.log "We are connected" if !err
			User.findOne {_id : json.id}, 'friends', (err, friends) ->
				for friend in friends
					query = User.find {_id : friend._id}
					query.select 'posts'
					query.exec (err, posts) ->
						feed.concat posts[-10..]
		res.render 'feed.jade', {feed: [feed], name: req.user.displayName}
		###
	
app.get '/logout', (req, res) ->
	req.logout
	res.redirect '/'

app.get '/addevent', (req, res) ->
	res.render 'index.jade', {title: "add event", fields: ["email", "password"], action: "/auth", submit: "go" }
			
app.post '/addfriend', (req, res) ->
	json = JSON.parse req.body
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
			console.log "We are connected" if !err
			User.update {user: json.user}, { $push: {'friends': json.friend} }, (err, result) ->
				if !err
					req.json result
					
app.post '/auth/facebook', passport.authenticate('facebook')

app.get '/auth/facebook/callback', passport.authenticate('facebook', { failureRedirect: '/' }), (req, res) ->
    res.send 'Success'
	
app.post '/addevent', (req, res) ->
	store = (event) ->
		mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
			console.log "We are connected" if !err
			event.save (err, result) ->
				assert.equal err, null 
				console.log "Created a new event"
	
	form = new formidable.IncomingForm()
	form.parse req, (err, fields, files) ->
		res.end util.inspect({fields: fields, files: files})
		title = fields.title	
	form.on 'end', (fields, files) ->
		temp_path = this.openedFiles[0].path
		file_name = this.openedFiles[0].name
		new_location = 'uploads/' + file_name
		newevent = new Event({name: title, imageurl: new_location})
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