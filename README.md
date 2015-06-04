postoffice
=============

The SnailMail Server

## Setup

* Install Mongo DB locally
* bundle install
* Ensure 'mongod' is running
* Set up database indexes and demo data
** bundle exec rake create_indexes
** bundle exec rake setup_demo_data
* Set environment variable SNAILMAIL_BASE_URL to application root, ie 'http://localhost:9292'
* Start app with 'rackup'
