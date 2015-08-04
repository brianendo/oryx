mongoose = require 'mongoose'

Schema = mongoose.Schema 
eventSchema = new Schema {name: String, imageurl: String }
Event = mongoose.model 'Event', eventSchema

module.exports = mongoose.model 'Event', eventSchema