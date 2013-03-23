require 'date-utils'
util        = require 'util'
request     = require 'request'
_           = require 'underscore'
parseString = require('xml2js').parseString


class Parature
    constructor: (config, graphite) ->
        @baseUrl    = util.format '%s://%s/api/v1/%s/%s', config.protocol, config.host, config.accountId, config.deptId
        @token      = config.token
        @graphite   = graphite

    get: (url, cb) =>
        console.log url
        if url[url.length-1] != '?'
            url += '&'
        url += '_token_='+@token
        request.get { uri: url }, (err, resp, body) ->
            cb(err) if err
            parseString body.trim(), (err, result) ->
                cb(err) if err
                cb(null, result)

    totalNew: ->
        url = @baseUrl + '/Ticket/?_total_=true&Date_Created=_today_'
        @get url, (err, result) ->
            console.log(err) if err
            console.log result.Entities['$'].total

    ticketTypes: ->
        url = @baseUrl + '/Ticket/status?_filter_queue=880'
        @get url, (err, result) ->
            console.log(err) if err
            _.each result.Entities.Status, (status) ->
                console.log status['$'].id, status.Name[0]['_']

    customerschema: ->
        url = @baseUrl + '/Customer/schema?'
        @get url, (err, result) ->
            console.log(err) if err
            console.log result.Customer
            console.log result.Customer.Sla
            console.log result.Customer.Customer_Role
            _.map result.Customer.Custom_Field, (field) ->
                console.log field.$.id, field.$['display-name']

    ticketschema: ->
        url = @baseUrl + '/Ticket/schema?'
        @get url, (err, result) ->
            console.log(err) if err
            console.log result.Ticket
            _.map result.Ticket.Custom_Field, (field) ->
                console.log field.$.id, field.$['display-name']

    ticketview: ->
        url = @baseUrl + '/Ticket/view?'
        @get url, (err, result) ->
            console.log(err) if err
            _.map result.Entities.View, (view) ->
                console.log view.$.id, view.Name[0]['_']

    platinum: ->
        url = @baseUrl + '/Ticket?_view_=1&_status_type_=open&_total_=true'
        @get url, (err, result) ->
            console.log(err) if err
            console.log result.Entities.$.total

    # Log new tickets created in the last 1min to graphite
    newTickets: =>
        now = new Date()
        now.addHours(7) #Ugh. GMT vs. PST

        # Now
        max = now.toFormat('YYYY-MM-DDTHH24:MI:SSZ')

        now.addMinutes(-1440*7) # TODO: Make this an optional parameter

        # 1 minute ago
        min = now.toFormat('YYYY-MM-DDTHH24:MI:SSZ')

        # Construct the URL
        url = util.format('%s/Ticket?_view_=134&Date_Created_min_=%s&Date_Created_max_=%s', @baseUrl, min, max)

        @get url, (err, result) =>
            return err if err?
            total = result.Entities.$.total
            console.log "New Tickets:", total
            @graphite.write {'parature.tickets.new':total}, (error) =>
                @graphite.end()

            # Count the number of JIRA tickets associated with parature tickets
            jiras = {}
            _.each result.Entities.Ticket, (ticket) ->
                jira = ticket.Custom_Field[0]._
                if (jira)
                    jiras[jira] = 1 if !jiras[jira]
                    jiras[jira]++
            console.log jiras


module.exports = Parature
