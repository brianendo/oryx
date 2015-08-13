mongoose = require 'mongoose'

Schema = mongoose.Schema 
eventSchema = new Schema {artist: String, imageurl: String, date: String, location: String }
Event = mongoose.model 'Event', eventSchema

module.exports = mongoose.model 'Event', eventSchema