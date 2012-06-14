#!/usr/bin/env node

// Load modules
var fs     = require('fs');
var url    = require('url');
var ejs    = require('ejs');
var path   = require('path');
var mime   = require('mime');
var http   = require('http');
var https  = require('https');

// The root file path
var FILEPATH = path.dirname(__dirname);
var PID_FILE = __dirname + '/.pid';

// Load config
var conf = require('./config.json');

// Load the controller
var controller = require('./controller');

// Store the PID
fs.writeFileSync(PID_FILE, process.pid);

// Build the server
var server;
if (conf.https && conf.https.keyFile && conf.https.certFile) {
	conf.https.opts = {
		key: fs.readFileSync(path.join(__dirname, conf.https.keyFile)),
		cert: fs.readFileSync(path.join(__dirname, conf.https.certFile))
	};
	server = https.createServer(conf.https.opts, serverFunc);
} else {
	server = http.createServer(serverFunc);
}

// Start the server
server.listen(conf.port, conf.host, function() {
	console.log('Server running at ' + conf.host + ':' + conf.port + ' (process id ' + process.pid + ')');
});

// ------------------------------------------------------------------
//  Internals

function serverFunc(req, res) {
	
	// Parse the request url
	var urlData = url.parse(req.url);
	
	// Log the request
	console.log('HTTP ' + req.method + ' ' + urlData.pathname);
	
	// Resolve the file path
	var pathname = FILEPATH + (
		(urlData.pathname === '/') ? '/index.ejs' : urlData.pathname
	).split('/').map(removeDoubleDot).join('/');
	
	// See if there is an entry in the controller file
	var route = (urlData.pathname === '/') ? 'index' : urlData.pathname.substring(1);
	if (controller.hasOwnProperty(route)) {
		return controller[route](req, res);
	}
	
	// Test for an ejs extension
	var isEJS = (pathname.split('.').pop() === 'ejs');
	
	// Make sure the requested file exists
	path.exists(pathname, function(exists) {
		
		// Handle a 404 error
		if (! exists) {
			respond(res, {
				status: 404,
				headers: [
					['Content-Type', 'text/plain']
				],
				body: '404 Not Found'
			});
		}
		
		// Load the file contents
		else {
			fs.readFile(pathname, function(err, data) {
				
				// Start building the response
				var status = 200;
				var contentType = 'text/html';
				
				// Handle read errors
				if (err) {
					console.log(err);
					status = 500;
					contentType = 'text/plain';
					data = '500 Internal Server Error';
				}
				
				// Handle EJS files
				else if (isEJS) {
					data = ejs.render(String(data), {
						locals: {
							req: req,
							res: res
						}
					});
				}
				
				// Handle other files
				else {
					contentType = mime.lookup(pathname);
				}
				
				// Send output
				respond(res, {
					status: 200,
					headers: [
						['Content-Type', contentType]
					],
					body: data
				});
				
			});
		}
		
	});
	
}

// Sends a response
function respond(res, conf) {
	console.log(' HTTP ' + conf.status);
	res.writeHead(conf.status, conf.headers);
	if (conf.body) {
		res.write(conf.body);
	}
	res.end();
}

// Removes unsafe .. url segments
function removeDoubleDot(segment) {
	return (segment === '..' ? '.' : segment);
}

/* End of file server.js */
