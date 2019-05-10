const puppeteer = require('puppeteer');
const server = require('http-server-legacy').createServer({root: __dirname});
var url = 'http://localhost:8912/run.html';

(async () => {
  server.listen(8912);
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  page.on('console', msg => console.log(msg.text()));
  page.on('pageerror', err => console.log(err)); // should not happen because we should have caught all errors with window.onerror
  await Promise.all([
    page.exposeFunction('travixPrint', s => process.stdout.write(s)),
    page.exposeFunction('travixPrintln', s => process.stdout.write(s + '\n')),
    page.exposeFunction('travixExit', code => process.exit(code)),
    page.exposeFunction('travixThrow', e => {
      console.error('Uncaught error: ', e);
      process.exit(1);
    }),
  ]);
  await page.evaluateOnNewDocument(() => console.log(window.navigator.userAgent)); // print user agent as a hint that we are running in a browser
  await page.goto(url);
})();