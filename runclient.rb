require "./client"
require "./models"
client = Client.new Player.first_or_create(name:"James"), "192.168.1.130", 50500
client.greet

