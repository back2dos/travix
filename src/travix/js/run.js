const puppeteer = require('puppeteer');
var url = 'file://' + __dirname + '/index.html';

(async () => {
  const browser = await puppeteer.launch();
  const page = await browser.newPage();
  page.on('console', msg => console.log(msg.text()));
  await Promise.all([
    page.exposeFunction('travixPrint', s => process.stdout.write(s)),
    page.exposeFunction('travixPrintln', s => process.stdout.write(s + '\n')),
    page.exposeFunction('travixExit', code => process.exit(code)),
  ]);
  await page.goto(url);
  await browser.close();
})();