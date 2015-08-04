coffee_script = require 'coffee-script'
http = require 'http'
url = require 'url'
express = require 'express'
mongo = require 'mongodb'
#grid = mongo.Grid
mongoose = require 'mongoose'
assert = require 'assert'
#formidable = require 'formidable'
qt = require 'quickthumb'
fs = require 'fs-extra'
fsn = require 'fs'
util = require 'util'
jade = require 'jade'
passport = require 'passport'

Event = require './models/event_model.coffee'
User = require './models/user_model.coffee'

MongoClient = mongo.MongoClient
#ObjectId = require('mongodb').ObjectID

title = ''

app = express()
app.use qt.static( __dirname + '/' )
app.locals.title = 'Oryx'
app.set('views', './views')
app.set 'view engine', 'jade'

app.get '/', (req, res) ->
	res.render 'index.jade', {title: "index", fields: ["email", "password"] }
	
		
app.post '/addfriend', (req, res) ->
	json = JSON.parse req.body
	mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
			console.log "We are connected" if !err
			User.update {user: json.user}, { $push: {'friends': json.friend} }, (err, result) ->
				if !err
					req.json result

app.post './adduser', (req, res) ->
	store = (user) ->
		mongoose.connect 'mongodb://localhost:27017/oryx', (err, db) ->	
			console.log "We are connected" if !err
			user.save (err, result) ->
				assert.equal err, null 
				console.log "Created a new event"
	json = JSON.parse req.body
	newuser = new User(json)
	store newuser
	

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