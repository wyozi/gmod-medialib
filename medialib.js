medialib = {};

(function(exports) {
	exports.getParams = function() {
		var query = location.search.substr(1);
		var data = query.split("&");
		var result = {};
		for(var i=0; i<data.length; i++) {
			var item = data[i].split("=");
			result[item[0]] = item[1];
		}
		return result;
	};
	exports.flashVersion = function() {
		// Detect flash (http://stackoverflow.com/a/9865667)
		return (function() {
			var a = !1,
				b = "";

			function c(d) {
				d = d.match(/[\d]+/g);
				d.length = 3;
				return d.join(".")
			}
			if (navigator.plugins && navigator.plugins.length) {
				var e = navigator.plugins["Shockwave Flash"];
				e && (a = !0, e.description && (b = c(e.description)));
				navigator.plugins["Shockwave Flash 2.0"] && (a = !0, b = "2.0.0.11")
			} else {
				if (navigator.mimeTypes && navigator.mimeTypes.length) {
					var f = navigator.mimeTypes["application/x-shockwave-flash"];
					(a = f && f.enabledPlugin) && (b = c(f.enabledPlugin.description))
				} else {
					try {
						var g = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.7"),
							a = !0,
							b = c(g.GetVariable("$version"))
					} catch (h) {
						try {
							g = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.6"), a = !0, b = "6.0.21"
						} catch (i) {
							try {
								g = new ActiveXObject("ShockwaveFlash.ShockwaveFlash"), a = !0, b = c(g.GetVariable("$version"))
							} catch (j) {}
						}
					}
				}
			}
			return a ? b : false;
		})();
	};
	exports.emitEvent = function(id, obj) {
		obj = obj || {};

		if (!("medialiblua" in window)) {
			console.log("MediaLib event: " + id + JSON.stringify(obj));
			return;
		}

		medialiblua.Event(id, JSON.stringify(obj));
	};
	exports.checkFlash = function() {
		if (exports.flashVersion() !== false) {
			return true;
		}

		exports.emitEvent("noflash", {});

		// Show a black no flash page
		document.body.innerHTML = "";

		document.body.style.backgroundColor = "black";
		document.body.style.color = "white";

		// Add Roboto font
		WebFontConfig = {
			google: { families: [ 'Roboto::latin' ] }
		};
		(function() {
			var wf = document.createElement('script');
			wf.src = ('https:' == document.location.protocol ? 'https' : 'http') +
				'://ajax.googleapis.com/ajax/libs/webfont/1/webfont.js';
			wf.type = 'text/javascript';
			wf.async = 'true';

			document.body.appendChild(wf);
		})();

		var el = document.createElement("div");
		el.style.textAlign = "center";
		el.style.width = "100%";
		el.style.marginTop = 30;
		el.style.fontFamily = "'Roboto'";
		el.innerHTML = "<h1>No flash found!</h1>Type 'medialib_noflash' in console to find out how to install Flash.";

		document.body.appendChild(el);

		return false;
	}

	exports.loadAsync = function(js, cb) {
		var tag = document.createElement('script');

		tag.src = js;
		tag.onload = cb;

		var firstScriptTag = document.getElementsByTagName('script')[0];
		firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
	}

	function EventDelegate(map) {
		this.map = map;
		this.eventQueue = [];
	}

	EventDelegate.prototype.run = function(id, obj) {
		if (this.loaded) {
			var fun = this.map[id];

			// Event not implemented for this service; silently fail
			if (!fun) {
				return;
			}

			fun.call(this.loadedPlayer, obj, new Date().getTime());
			//console.log("calling event "+ id + " directly")
		}
		else {
			this.eventQueue.push({id: id, obj: obj, added: new Date().getTime()});
			//console.log("queueing event " + id);
		}
	};

	EventDelegate.prototype.playerLoaded = function(player) {
		this.loaded = true;
		this.loadedPlayer = player;

		console.log("[MediaLib] playerLoaded; running " + this.eventQueue.length + " pending commands");

		var that = this;
		this.eventQueue.forEach(function(item) {
			that.run(item.id, item.obj, item.added);
		});

		// Clear array
		this.eventQueue = [];

		// Notify gmod
		medialib.emitEvent("playerLoaded");
	};

	exports.createEventDelegate = function(handlerMap) {
		return new EventDelegate(handlerMap);
	};
})(medialib);
