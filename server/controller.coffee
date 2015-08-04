coffee_script = require 'coffee-script'
http = require 'http'
express = require 'express'
mongo = require 'mongodb'
#grid = mongo.Grid
mongoose = require 'mongoose'
assert = require 'assert'
#formidable = require 'formidable'
#util = require 'util'
jade = require 'jade'
passport = require 'passport'
FacebookStrategy = require('passport-facebook').Strategy

Event = require './models/event_model.coffee'
User = require './models/user_model.coffee'

passport.use new FacebookStrategy { clientID: 975386195846106, clientSecret: "247f2b170ff3429fe6a4cdebca425325", callbackURL: "http://jackpack.org:2999/auth/facebook/callback", enableProof: false }, (accessToken, refreshToken, profile, done) ->
		User.findOrCreate { facebookId: profile.id }, (err, user) ->	
			mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->
				console.log "We are connected" if !err
				User.findOne {fb : user.id}, (err, user) ->
					if user == null				
						newuser = new User({fb : user.id, name : { first: user.name.givenName, last: user.name.familyName }, email: user.email[0] })
						newuser.save (err, result) ->
									assert.equal err, null 
									console.log "Created a new user"
						return done(err, user)
					else 
						return done(err, user)

MongoClient = mongo.MongoClient
#ObjectId = require('mongodb').ObjectID

title = ''

app = express()
app.use express.static( __dirname + '/' )
app.locals.title = 'Oryx'
app.set('views', './views')
app.set 'view engine', 'jade'

app.get '/', (req, res) ->
	if !req.user
		res.render 'index.jade', {title: "index", fields: [], action: "/auth/facebook", submit: "login" }
	else 
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