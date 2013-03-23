require('coffee-script');
var util = require('util');
var config = require('./config');
var Parature = require('./lib/parature');

var graphite = require('graphite').createClient(util.format('http://%s:%s', config.graphite.host, config.graphite.port));

var parature = new Parature(config.parature, graphite);
parature.newTickets();
