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
		//console.log("MediaLib event: " + id + obj);
		if (!("medialiblua" in window)) {
			return;
		}

		medialiblua.Event(id, JSON.stringify(obj));
	};

	function EventDelegate(map) {
		this.map = map;
		this.eventQueue = [];
	}

	EventDelegate.prototype.run = function(id, obj) {
		if (this.loaded) {
			this.map[id].call(this.loadedPlayer, obj);
			//console.log("calling event "+ id + " directly")
		}
		else {
			this.eventQueue.push({id: id, obj: obj});
			//console.log("queueing event " + id);
		}
	};

	EventDelegate.prototype.playerLoaded = function(player) {
		this.loaded = true;
		this.loadedPlayer = player;

		var that = this;
		this.eventQueue.forEach(function(item) {
			that.run(item.id, item.obj);
		});

		// Clear array
		this.eventQueue = [];
	};

	exports.createEventDelegate = function(handlerMap) {
		return new EventDelegate(handlerMap);
	};
})(medialib);
