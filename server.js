/*
VMS: Vessel Monitoring System - Control Box Software
Copyright (C) 2011 Ecotrust Canada
Knowledge Systems and Planning

This file is part of VMS.

VMS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

VMS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with VMS. If not, see <http://www.gnu.org/licenses/>.

You may contact Ecotrust Canada via our websitehttp://ecotrust.ca
*/

var path = require('path'),
    fs = require('fs'),
    express = require('express'),
    config = require('./lib/config.js'),
    routes = require('./lib/routes.js'),
    server = express(),
    exec = require('child_process').exec,
    port = 8081;

function fakenull(error, stdout, stderr) { }

console.log("INFO: Ecotrust EM Web Server v%s is starting", config.SERVER_VERSION);

process.chdir(__dirname); // ensure working directory is correct
config.setup();

server.configure(function() {
	server.set('views', path.join(__dirname, 'views'));
	server.enable('view cache');
	server.use(express.static(path.join(__dirname, 'public')));
	server.use(express.bodyParser());
	server.use(server.router);
});

server.get('/em',                   routes.index);
server.get('/em_state.json',        routes.em_state);
server.get('/sensorStates.json',    routes.sensorStates);
server.get('/500',                  function(req, res) { throw new Error("500 - Internal server error"); });

server.post('/report',              routes.report);
server.post('/reset_trip',          routes.resetTrip);
server.post('/reset_string',        routes.resetString);
server.post('/search_rfid',         routes.searchRFID);

server.listen(port);
// warm up the cache
exec("/usr/bin/wget -O - -q -t 1 http://127.0.0.1:8081/em/ > /dev/null", fakenull);
console.log("INFO: Listening on port " + port);