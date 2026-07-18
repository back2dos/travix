const puppeteer = require("puppeteer");
const handler = require("serve-handler");
const http = require("http");
const fs = require("fs");
const path = require("path");

function loadHooks() {
	const defaults = {
		port: 8912,
		htmlFile: fs.existsSync(path.join(__dirname, "run.html"))
			? "run.html"
			: "run.travix.html",
		serveOptions: (opts) => opts,
		launchOptions: (opts) => opts,
		beforeGoto: async () => {},
		afterGoto: async () => {},
	};
	const configDir =
		process.env.TRAVIX_CONFIG_DIR || path.join(process.cwd(), ".travix");
	const hooksPath = path.join(configDir, "js", "hooks.js");
	if (!fs.existsSync(hooksPath)) return defaults;
	return Object.assign({}, defaults, require(hooksPath));
}

(async () => {
	const hooks = loadHooks();
	const { port, htmlFile } = hooks;
	// $$ escapes for travix.Macro.loadFile (MacroStringTools.formatString).
	const url = `http://localhost:$${port}/$${htmlFile}`;

	const serveOptions = await hooks.serveOptions({ public: __dirname });

	const server = http.createServer((request, response) => {
		return handler(request, response, serveOptions);
	});

	server.listen(port, async () => {
		const launchOptions = await hooks.launchOptions({
			headless: true,
			devtools: true,
			args: [
				"--no-sandbox",
				"--disable-setuid-sandbox",
				"--disable-web-security",
				"--disable-features=IsolateOrigins",
				"--disable-site-isolation-trials",
			],
		});

		const browser = await puppeteer.launch(launchOptions);
		const page = await browser.newPage();

		page.on("console", (msg) => console.log(msg.text()));
		page.on("pageerror", (err) => console.log(err)); // should not happen because we should have caught all errors with window.onerror

		await Promise.all([
			page.exposeFunction("travixPrint", (s) => process.stdout.write(s)),
			page.exposeFunction("travixPrintln", (s) =>
				process.stdout.write(s + "\n")
			),
			page.exposeFunction("travixExit", (code) => process.exit(code)),
			page.exposeFunction("travixThrow", (e) => {
				console.error("Uncaught error: ", e);
				process.exit(1);
			}),
		]);

		await page.evaluateOnNewDocument(() =>
			console.log(window.navigator.userAgent)
		); // print user agent as a hint that we are running in a browser

		await hooks.beforeGoto(page);
		await page.goto(url);
		await hooks.afterGoto(page);
	});
})().catch((err) => {
	console.error(err);
	process.exit(1);
});
