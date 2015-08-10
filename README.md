postoffice
=============

## The Postoffice Server

Backend for Slowpost app

## Initial Setup

### Installation
* Install Mongo DB locally
* bundle install
* Add development and production .pem certificates for Apple notifications to certificates directory

### Configure environment variables
* Set environment variable POSTOFFICE_BASE_URL to application root, ie 'http://localhost:9292'
* Set environment variable POSTOFFICE_POSTMAN_USERNAME to username for Postman (this is used for welcome messages)
* Set AWS environment variables

```
AWS_BUCKET=[bucket name]
AWS_SECRET_ACCESS_KEY=[Secret key]
AWS_REGION=[Region]
AWS_ACCESS_KEY_ID=[Access key id]
```

### Running the application
* Ensure 'mongod' is running
* Set up database indexes and demo data
```
bundle exec rake create_indexes
bundle exec rake setup_demo_data
```
* Start app with ```rackup```


## API

### People

Create a person (note that this also generates a welcome message automatically):

```
POST /person/new

{
	"name": "Person Name",
	"username": "username",
	"email": "person@test.com",
	"phone": "555-444-1234",
	"password": "password",
	"address1": "Street Address",
	"city": "City",
	"state": "ST",
	"zip": "11111"
}

Status: 201

Headers:
person_link = /person/id/{person_id}
```

Log in:

```
POST /login

{
	"username": "username",
	"password": "password"
}

Status: 200
```

Get a person record:

```
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
```

Update a person:

```
POST /person/id/{person_id}

{
	"address1": "Street Address",
	"city": "City",
	"state": "ST",
	"zip": "11111"
}

Status: 204
```

Reset a person's password:

```
POST /person/id/{person_id}/reset_password

{
	"old_password": "password",
	"new_password": "password123"
}

Status: 204
```

Get a collection of people:

```
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
	}
]
```

Search people:
* Search terms are case-sensitive
* Terms are used to search both name and username records
* If no limit to the number of results is set, the default limit is 25

```
GET /people/search?term=Evan&limit=3

Status: 200

Response body:
[
	{
		_id: {
			$oid: "uuid"
		},
		name: "Evan 1",
		username: "username1",
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
		name: "Evan 2",
		username: "username2",
		address1: "Street Address",
		city: "City",
		state: "ST",
		zip: "11111",
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]

```

Perform a bulk search of people using emails and phone numbers:
* The iOS app searches a person's contacts and passes in an array of these contacts, including email and phone numbers for each contact
* The postoffice server returns a unique list of any people who match the contact records

```

POST /people/bulk_search

[
	{
		"emails": ["person1@test.com", "person1@gmail.com"],
		"phoneNumbers": ["5554441243"]
	},
	{
		"emails": ["person2@test.com"],
		"phoneNumbers": ["5553332222"]
	}
]

Status: 200

Reponse body:
[
	{
		_id: {
			$oid: "uuid"
		},
		name: "Evan 1",
		username: "username1",
		email: "person1@test.com",
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
		name: "Evan 2",
		username: "username2",
		emails: "person2@test.com",
		address1: "Street Address",
		city: "City",
		state: "ST",
		zip: "11111",
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]
```

### Mail

Create new mail in DRAFT state:

```
POST /person/id/{person_id}/mail/new

{
	"to": "recipient_username",
	"content": "Message content",
	"image": "image.jpg"
}

Respoonse: 201

Headers:
mail_link = /mail/id/{mail_id}
```

Create new mail in SENT state:


```
POST /person/id/{person_id}/mail/send

{
	"to": "recipient_username",
	"content": "Message content",
	"image": "image.jpg"
}

Respoonse: 201

Headers:
mail_link = /mail/id/{mail_id}
```

Get a mail item (if mail is in SENT state with arrivale date in the past, it will be updated to DELIVERED state)

```
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
```

Get a collection of mail (any mail in SENT state with arrivale date in the past will be updated to DELIVERED state)

```
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
```

Send an item of mail that is currently in DRAFT state:

```
POST /mail/id/{mail_id}/send

Status: 204
```

Manually deliver an item of mail that is currently in SENT state, and has an arrival date in the future (sets arrival date to current date and time):

```
POST /mail/id/{mail_id}/deliver

Status: 204
```

Get delivered mail for a user (finds mail that has an arrival date in the past, and updates status to DELIVERED for these mail if necessary):

```
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
```

Get mail that has been created by a user (any mail in SENT state that arrived in the past will be updated to DELIVERED state):

```
GET /person/id/{person_id}/outbox

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
```

Get contacts for a user (any person who has sent mail to, or received mail from, the user):

```
GET /person/id/{person_id}/contacts

Status: 200

[
	{
		_id: {
			$oid: "uuid"
		},
		name: "Evan 1",
		username: "username1",
		email: "person1@test.com",
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
		name: "Evan 2",
		username: "username2",
		emails: "person2@test.com",
		address1: "Street Address",
		city: "City",
		state: "ST",
		zip: "11111",
		updated_at: "2015-06-17T20:36:39.024Z"
		created_at: "2015-06-17T20:36:39.009Z"
	}
]

```
