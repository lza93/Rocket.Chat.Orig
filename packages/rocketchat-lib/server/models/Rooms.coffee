class ModelRooms extends RocketChat.models._Base
	constructor: ->
		super(arguments...)

		@tryEnsureIndex { 'name': 1 }, { unique: 1, sparse: 1 }
		@tryEnsureIndex { 'default': 1 }
		@tryEnsureIndex { 'usernames': 1 }
		@tryEnsureIndex { 't': 1 }
		@tryEnsureIndex { 'u._id': 1 }

		this.cache.ignoreUpdatedFields.push('msgs', 'lm')
		this.cache.ensureIndex(['t', 'name'], 'unique')
		this.cache.options = {fields: {usernames: 0}}

	findOneByIdOrName: (_idOrName, options) ->
		query = {
			$or: [{
				_id: _idOrName
			}, {
				name: _idOrName
			}]
		}

		return this.findOne(query, options)

	findOneByImportId: (_id, options) ->
		query =
			importIds: _id

		return @findOne query, options

	findOneByName: (name, options) ->
		query =
			name: name

		return @findOne query, options

	findOneByNameAndType: (name, type, options) ->
		query =
			name: name
			t: type

		return @findOne query, options

	findOneByIdContainingUsername: (_id, username, options) ->
		query =
			_id: _id
			usernames: username

		return @findOne query, options

	findOneByNameAndTypeNotContainingUsername: (name, type, username, options) ->
		query =
			name: name
			t: type
			usernames:
				$ne: username

		return @findOne query, options


	# FIND

	findById: (roomId, options) ->
		return @find { _id: roomId }, options

	findByIds: (roomIds, options) ->
		return @find { _id: $in: [].concat roomIds }, options

	findByType: (type, options) ->
		query =
			t: type

		return @find query, options

	findByTypes: (types, options) ->
		query =
			t:
				$in: types

		return @find query, options

	findByUserId: (userId, options) ->
		query =
			"u._id": userId

		return @find query, options

	findBySubscriptionUserId: (userId, options) ->
		if this.useCache
			data = RocketChat.models.Subscriptions.findByUserId(userId).fetch()
			data = data.map (item) ->
				if item._room
					return item._room
				console.log('Empty Room for Subscription', item);
				return {}
			return this.arrayToCursor this.processQueryOptionsOnResult(data, options)

		data = RocketChat.models.Subscriptions.findByUserId(userId, {fields: {rid: 1}}).fetch()
		data = data.map (item) -> item.rid

		query =
			_id:
				$in: data

		this.find query, options

	findBySubscriptionUserIdUpdatedAfter: (userId, _updatedAt, options) ->
		if this.useCache
			data = RocketChat.models.Subscriptions.findByUserId(userId).fetch()
			data = data.map (item) ->
				if item._room
					return item._room
				console.log('Empty Room for Subscription', item);
				return {}
			data = data.filter (item) -> item._updatedAt > _updatedAt
			return this.arrayToCursor this.processQueryOptionsOnResult(data, options)

		ids = RocketChat.models.Subscriptions.findByUserId(userId, {fields: {rid: 1}}).fetch()
		ids = ids.map (item) -> item.rid

		query =
			_id:
				$in: ids
			_updatedAt:
				$gt: _updatedAt

		this.find query, options

	findByNameContaining: (name, options) ->
		nameRegex = new RegExp s.trim(s.escapeRegExp(name)), "i"

		query =
			$or: [
				name: nameRegex
			,
				t: 'd'
				usernames: nameRegex
			]

		return @find query, options

	findByNameContainingTypesWithUsername: (name, types, options) ->
		nameRegex = new RegExp s.trim(s.escapeRegExp(name)), "i"

		$or = []
		for type in types
			obj = {name: nameRegex, t: type.type}
			if type.username?
				obj.usernames = type.username
			if type.ids?
				obj._id = $in: type.ids
			$or.push obj

		query =
			$or: $or

		return @find query, options

	findContainingTypesWithUsername: (types, options) ->

		$or = []
		for type in types
			obj = {t: type.type}
			if type.username?
				obj.usernames = type.username
			if type.ids?
				obj._id = $in: type.ids
			$or.push obj

		query =
			$or: $or

		return @find query, options

	findByNameContainingAndTypes: (name, types, options) ->
		nameRegex = new RegExp s.trim(s.escapeRegExp(name)), "i"

		query =
			t:
				$in: types
			$or: [
				name: nameRegex
			,
				t: 'd'
				usernames: nameRegex
			]

		return @find query, options

	findByNameAndTypeNotContainingUsername: (name, type, username, options) ->
		query =
			t: type
			name: name
			usernames:
				$ne: username

		return @find query, options

	findByNameStartingAndTypes: (name, types, options) ->
		nameRegex = new RegExp "^" + s.trim(s.escapeRegExp(name)), "i"

		query =
			t:
				$in: types
			$or: [
				name: nameRegex
			,
				t: 'd'
				usernames: nameRegex
			]

		return @find query, options

	findByDefaultAndTypes: (defaultValue, types, options) ->
		query =
			default: defaultValue
			t:
				$in: types

		return @find query, options

	findByTypeContainingUsername: (type, username, options) ->
		query =
			t: type
			usernames: username

		return @find query, options

	findByTypeContainingUsernames: (type, username, options) ->
		query =
			t: type
			usernames: { $all: [].concat(username) }

		return @find query, options

	findByTypesAndNotUserIdContainingUsername: (types, userId, username, options) ->
		query =
			t:
				$in: types
			uid:
				$ne: userId
			usernames: username

		return @find query, options

	findByContainingUsername: (username, options) ->
		query =
			usernames: username

		return @find query, options

	findByTypeAndName: (type, name, options) ->
		if this.useCache
			return this.cache.findByIndex('t,name', [type, name], options)

		query =
			name: name
			t: type

		return @find query, options

	findByTypeAndNameContainingUsername: (type, name, username, options) ->
		query =
			name: name
			t: type
			usernames: username

		return @find query, options

	findByTypeAndArchivationState: (type, archivationstate, options) ->
		query =
			t: type

		if archivationstate
			query.archived = true
		else
			query.archived = { $ne: true }

		return @find query, options

	# UPDATE
	addImportIds: (_id, importIds) ->
		importIds = [].concat(importIds);
		query =
			_id: _id

		update =
			$addToSet:
				importIds:
					$each: importIds

		return @update query, update

	archiveById: (_id) ->
		query =
			_id: _id

		update =
			$set:
				archived: true

		return @update query, update

	unarchiveById: (_id) ->
		query =
			_id: _id

		update =
			$set:
				archived: false

		return @update query, update

	addUsernameById: (_id, username, muted) ->
		query =
			_id: _id

		update =
			$addToSet:
				usernames: username

		if muted
			update.$addToSet.muted = username

		return @update query, update

	addUsernamesById: (_id, usernames) ->
		query =
			_id: _id

		update =
			$addToSet:
				usernames:
					$each: usernames

		return @update query, update

	addUsernameByName: (name, username) ->
		query =
			name: name

		update =
			$addToSet:
				usernames: username

		return @update query, update

	removeUsernameById: (_id, username) ->
		query =
			_id: _id

		update =
			$pull:
				usernames: username

		return @update query, update

	removeUsernamesById: (_id, usernames) ->
		query =
			_id: _id

		update =
			$pull:
				usernames:
					$in: usernames

		return @update query, update

	removeUsernameFromAll: (username) ->
		query =
			usernames: username

		update =
			$pull:
				usernames: username

		return @update query, update, { multi: true }

	removeUsernameByName: (name, username) ->
		query =
			name: name

		update =
			$pull:
				usernames: username

		return @update query, update

	setNameById: (_id, name) ->
		query =
			_id: _id

		update =
			$set:
				name: name

		return @update query, update

	incMsgCountById: (_id, inc=1) ->
		query =
			_id: _id

		update =
			$inc:
				msgs: inc

		return @update query, update

	incMsgCountAndSetLastMessageTimestampById: (_id, inc=1, lastMessageTimestamp) ->
		query =
			_id: _id

		update =
			$set:
				lm: lastMessageTimestamp
			$inc:
				msgs: inc

		return @update query, update

	replaceUsername: (previousUsername, username) ->
		query =
			usernames: previousUsername

		update =
			$set:
				"usernames.$": username

		return @update query, update, { multi: true }

	replaceMutedUsername: (previousUsername, username) ->
		query =
			muted: previousUsername

		update =
			$set:
				"muted.$": username

		return @update query, update, { multi: true }

	replaceUsernameOfUserByUserId: (userId, username) ->
		query =
			"u._id": userId

		update =
			$set:
				"u.username": username

		return @update query, update, { multi: true }

	setJoinCodeById: (_id, joinCode) ->
		query =
			_id: _id

		if joinCode?.trim() isnt ''
			update =
				$set:
					joinCodeRequired: true
					joinCode: joinCode
		else
			update =
				$set:
					joinCodeRequired: false
				$unset:
					joinCode: 1

		return @update query, update

	setUserById: (_id, user) ->
		query =
			_id: _id

		update =
			$set:
				u:
					_id: user._id
					username: user.username

		return @update query, update

	setTypeById: (_id, type) ->
		query =
			_id: _id

		update =
			$set:
				t: type

		return @update query, update

	setTopicById: (_id, topic) ->
		query =
			_id: _id

		update =
			$set:
				topic: topic

		return @update query, update

	muteUsernameByRoomId: (_id, username) ->
		query =
			_id: _id

		update =
			$addToSet:
				muted: username

		return @update query, update

	unmuteUsernameByRoomId: (_id, username) ->
		query =
			_id: _id

		update =
			$pull:
				muted: username

		return @update query, update

	saveDefaultById: (_id, defaultValue) ->
		query =
			_id: _id

		update =
			$set:
				default: defaultValue is 'true'

		return @update query, update

	setTopicAndTagsById: (_id, topic, tags) ->
		setData = {}
		unsetData = {}

		if topic?
			if not _.isEmpty(s.trim(topic))
				setData.topic = s.trim(topic)
			else
				unsetData.topic = 1

		if tags?
			if not _.isEmpty(s.trim(tags))
				setData.tags = s.trim(tags).split(',').map((tag) => return s.trim(tag))
			else
				unsetData.tags = 1

		update = {}

		if not _.isEmpty setData
			update.$set = setData

		if not _.isEmpty unsetData
			update.$unset = unsetData

		if _.isEmpty update
			return

		return @update { _id: _id }, update

	# INSERT
	createWithTypeNameUserAndUsernames: (type, name, user, usernames, extraData) ->
		room =
			name: name
			t: type
			usernames: usernames
			msgs: 0
			u:
				_id: user._id
				username: user.username

		_.extend room, extraData

		room._id = @insert room
		return room

	createWithIdTypeAndName: (_id, type, name, extraData) ->
		room =
			_id: _id
			ts: new Date()
			t: type
			name: name
			usernames: []
			msgs: 0

		_.extend room, extraData

		@insert room
		return room


	# REMOVE
	removeById: (_id) ->
		query =
			_id: _id

		return @remove query

	removeByTypeContainingUsername: (type, username) ->
		query =
			t: type
			usernames: username

		return @remove query

RocketChat.models.Rooms = new ModelRooms('room', true)
