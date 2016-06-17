var system = require('system');
var page = require('webpage').create();
var fs = require('fs');
var path = system.args[0].split('/');
fs.changeWorkingDirectory(path.slice(0, path.length - 1).join('/'));
var url = './index.html';

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onCallback = function(data) {
	if(!data) return;
	switch (data.cmd) {
		case 'travix:print':
			system.stdout.write(data.message);
			break;
		case 'travix:println':
			system.stdout.writeLine(data.message);
			break;
		case 'travix:exit':
			phantom.exit(data.exitCode);
			break;
		default:
			// ignore
			break;
	}
}

page.open(url, function (status) {
	// system.stdout.writeLine(url + " loaded.");
});