mongoose = require 'mongoose'

Schema = mongoose.Schema 
userSchema = new Schema {name: {first: String, last: String} , friends: Array, posts: Array }
User = mongoose.model 'User', userSchema

module.exports = mongoose.model 'users', userSchema