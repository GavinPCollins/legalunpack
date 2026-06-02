# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
puts "Creating users..."

gavin = User.find_or_initialize_by(email: "gavin@example.com")
gavin.update!(
  name: "Gavin",
  username: "gavin",
  password: "123456",
  password_confirmation: "123456"
)

halo = User.find_or_initialize_by(email: "halo@example.com")
halo.update!(
  name: "Halo",
  username: "halo",
  password: "123456",
  password_confirmation: "123456"
)

george = User.find_or_initialize_by(email: "george@example.com")
george.update!(
  name: "George",
  username: "george",
  password: "123456",
  password_confirmation: "123456"
)

puts "Users created"

# Alternative loop version, kept here as a reference:
#
# seeded_users = {}
#
# [
#   { name: "Gavin", username: "gavin", email: "gavin@example.com", password: "123456" },
#   { name: "Halo", username: "halo", email: "halo@example.com", password: "123456" },
#   { name: "George", username: "george", email: "george@example.com", password: "123456" }
# ].each do |user_attributes|
#   seeded_users[user_attributes[:username].to_sym] = User.find_or_initialize_by(email: user_attributes[:email]).tap do |user|
#     user.name = user_attributes[:name]
#     user.username = user_attributes[:username]
#     user.password = user_attributes[:password]
#     user.password_confirmation = user_attributes[:password]
#     user.save!
#   end
# end
#
# gavin = seeded_users.fetch(:gavin)
# halo = seeded_users.fetch(:halo)
# george = seeded_users.fetch(:george)
