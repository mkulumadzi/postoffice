postoffice
=============

The SnailMail Server

## Initial Setup

* Install Mongo DB locally
* bundle install
* Ensure 'mongod' is running
* Set up database indexes and demo data
** bundle exec rake create_indexes
** bundle exec rake setup_demo_data
* Set environment variable SNAILMAIL_BASE_URL to application root, ie 'http://localhost:9292'
* Start app with 'rackup'

## API

### People

Create a person (note that this also generates a welcome message automatically):

''
POST /person/new

{
	"name": "Person Name",
	"username": "username",
	"password": "password",
	"address1": "Street Address",
	"city": "City",
	"state": "ST",
	"zip": "11111"
}

Status: 201

Headers:
person_link = /person/id/{person_id}
''

Log in:

''
POST /login

{
	"username": "username",
	"password": "password"
}

Status: 200
''

Get a person record:

''
GET /person/id/{person_id}

Status: 200

Response body:

{
	_id: {
		$oid: "uuid"
	},
	name: "Person Name",
	username: "username",
	address1: "Street Address",
	city: "City",
	state: "ST",
	zip: "11111",
	updated_at: "2015-06-17T20:36:39.024Z"
	created_at: "2015-06-17T20:36:39.009Z"
}
''

Update a person:

''
POST /person/id/{person_id}

{
	"address1": "Street Address",
	"city": "City",
	"state": "ST",
	"zip": "11111"
}

Status: 204
''

Get a collection of people:

''
GET  /people?parameter=value

Status: 200

Response body:

[
	{
		_id: {
			$oid: "uuid"
		},
		name: "Person Name",
		username: "username",
		address1: "Street Address",
		city: "City",
		state: "ST",
		zip: "11111",
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	},
	{
		_id: {
			$oid: "uuid"
		},
		name: "Person Name",
		username: "username",
		address1: "Street Address",
		city: "City",
		state: "ST",
		zip: "11111",
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]
''

### Mail

Create new mail in DRAFT state:

''
POST /person/id/{person_id}/mail/new

{
	"to": "recipient_username",
	"content": "Message content",
	"image": "image.jpg"
}

Respoonse: 201

Headers:
mail_link = /mail/id/{mail_id}
''

Create new mail in SENT state:


''
POST /person/id/{person_id}/mail/send

{
	"to": "recipient_username",
	"content": "Message content",
	"image": "image.jpg"
}

Respoonse: 201

Headers:
mail_link = /mail/id/{mail_id}
''

Get a mail item (if mail is in SENT state with arrivale date in the past, it will be updated to DELIVERED state)

''
GET /mail/id/{mail_id}

Status: 200

Response body:

{
	_id: {
		$oid: "uuid"
	},
	from: "from_username",
	to: "to_username",
	content: "Message content",
	image: "image.jpg",
	status: "DRAFT",
	scheduled_to_arrive: nil,
	updated_at: "2015-06-17T20:36:39.024Z"
	created_at: "2015-06-17T20:36:39.009Z"
}
''

Get a collection of mail (any mail in SENT state with arrivale date in the past will be updated to DELIVERED state)

''
GET /mail/id/{mail_id}?parameter=value

Status: 200

Response body:

[
	{
		_id: {
			$oid: "uuid"
		},
		from: "from_username",
		to: "to_username",
		content: "Message content",
		image: "image.jpg",
		status: "DRAFT",
		scheduled_to_arrive: nil,
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	},
	{
		_id: {
			$oid: "uuid"
		},
		from: "from_username",
		to: "to_username",
		content: "Message content",
		image: "image.jpg",
		status: "SENT",
		scheduled_to_arrive: 2015-06-20T20:36:39.024Z,
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]
''

Send an item of mail that is currently in DRAFT state:

''
POST /mail/id/{mail_id}/send

Status: 204
''

Manually deliver an item of mail that is currently in SENT state, and has an arrival date in the future (sets arrival date to current date and time):

''
POST /mail/id/{mail_id}/deliver

Status: 204
''

Get delivered mail for a user (finds mail that has an arrival date in the past, and updates status to DELIVERED for these mail if necessary):

''
GET /person/id/{person_id}/mailbox

Status: 200

[
	{
		_id: {
			$oid: "uuid"
		},
		from: "from_username",
		to: "to_username",
		content: "Message content",
		image: "image.jpg",
		status: "DELIVERED",
		scheduled_to_arrive: 2015-06-17T20:36:39.024Z,
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]
''

Get mail that has been created by a user (any mail in SENT state that arrived in the past will be updated to DELIVERED state):

''
GET /person/id/{person_id}/mailbox

Status: 200

[
	{
		_id: {
			$oid: "uuid"
		},
		from: "from_username",
		to: "to_username",
		content: "Message content",
		image: "image.jpg",
		status: "DRAFT",
		scheduled_to_arrive: nil,
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]
''








