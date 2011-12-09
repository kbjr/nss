module.exports = {
	
	test: function(req, res) {
		res.writeHead(200, {'content-type': 'text/plain'});
		res.write('Hello, World!');
		res.end();
	}
	
};
