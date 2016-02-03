// Generated by LiveScript 1.4.0
(function(){
  var child, async, fs, progress, req, readline, unzip, Crawler, join$ = [].join, slice$ = [].slice;
  import$(global, require('prelude-ls'));
  child = require('child_process');
  async = require('async');
  fs = require('fs');
  progress = require('progress-stream');
  req = require('request');
  readline = require('readline');
  unzip = require('unzip');
  if (process.argv.length < 3) {
    console.log('Usage: ./lsc . PATH [MAX_PROCESSING=20]');
    process.exit();
  }
  Crawler = (function(){
    Crawler.displayName = 'Crawler';
    var prototype = Crawler.prototype, constructor = Crawler;
    function Crawler(path, maxFiles){
      this.path = path;
      this.maxFiles = maxFiles != null ? maxFiles : 20;
      this.files = [];
      this.start();
    }
    prototype.start = function(){
      var this$ = this;
      fs.unlink('./error.log', function(){});
      return child.exec('curl http://www.musicradar.com/news/tech/free-music-samples-download-loops-hits-and-multis-627820', function(err, stdout, stderr){
        if (err != null) {
          return console.error(err);
        }
        this$.pages = map(function(it){
          return join$.call(slice$.call(it, 0, -1), '');
        }, stdout.match(/\/sampleradar-[0-9]{6}.([0-9]+")*/g));
        async.each(this$.pages, bind$(this$, 'getPage'), function(){});
        return setInterval(bind$(this$, 'downloadProgress'), 1000);
      });
    };
    prototype.getPage = function(id, done){
      var this$ = this;
      return child.exec("curl http://www.musicradar.com/news/tech" + id, function(err, stdout, stderr){
        var files, names;
        if (err != null) {
          return done(err);
        }
        files = stdout.match(/http:\/\/cdn.mos.musicradar.com\/audio\/samples\/([a-z]|[0-9]|-)+\.zip/g);
        if (files == null) {
          return done();
        }
        names = map(function(it){
          return it.match(/.+musicradar-(.+\.zip)/)[1];
        })(
        files);
        files = map(function(it){
          return {
            url: it[0],
            name: it[1],
            downloaded: 0,
            speed: 0,
            finished: false,
            downloading: false,
            unzipping: false
          };
        })(
        zip(files, names));
        if (files == null) {
          this$.writeError("Didnt found files for " + id + "\n");
        }
        this$.files = this$.files.concat(files);
        return done();
      });
    };
    prototype.getFile = function(file){
      var str, this$ = this;
      if (file == null) {
        return;
      }
      file.downloading = true;
      str = progress({
        time: 1000
      });
      str.on('progress', function(prog){
        file.downloaded = Math.floor(prog.transferred / Math.pow(1024, 2));
        return file.speed = Math.floor(prog.speed / 1024);
      });
      return req(file.url).pipe(str).pipe(fs.createWriteStream("/tmp/" + file.name)).on('finish', function(){
        file.downloading = false;
        return this$.unzipFile(file);
      });
    };
    prototype.downloadProgress = function(){
      if (filter(function(it){
        return !it.finished && (it.downloading || it.unzipping);
      })(
      this.files).length < this.maxFiles) {
        this.getFile(find(function(it){
          return !it.finished && !(it.downloading || it.unzipping);
        }, this.files));
      }
      return this.downloadAff();
    };
    prototype.unzipFile = function(file){
      var this$ = this;
      file.unzipping = true;
      return fs.createReadStream("/tmp/" + file.name).pipe(unzip.Extract({
        path: "/tmp"
      })).on('close', function(){
        file.unzipping = false;
        return file.finished = true;
      });
    };
    prototype.downloadAff = function(){
      readline.clearScreenDown(process.stdout);
      map(function(it){
        return console.log(it.downloaded + "Mo, " + it.speed + "Ko/s -> " + it.name);
      })(
      filter(function(it){
        return !it.finished && it.downloading;
      })(
      this.files));
      map(function(it){
        return console.log("Unzipping...  -> " + it.name);
      })(
      filter(function(it){
        return !it.finished && it.unzipping;
      })(
      this.files));
      console.log('---');
      console.log("Processing       : " + filter(function(it){
        return !it.finished && (it.downloading || it.unzipping);
      })(
      this.files).length + "/" + this.maxFiles + " files");
      console.log("Finished         : " + filter(function(it){
        return it.finished;
      })(
      this.files).length + "/" + this.files.length);
      console.log("Total speed      : " + fold1(curry$(function(x$, y$){
        return x$ + y$;
      }), map(function(it){
        return it.speed;
      }, this.files)) + "Ko/s");
      console.log("Total downloaded : " + fold1(curry$(function(x$, y$){
        return x$ + y$;
      }), map(function(it){
        return it.downloaded;
      }, this.files)) + "Mo");
      return readline.moveCursor(process.stdout, 0, -filter(function(it){
        return !it.finished && (it.downloading || it.unzipping);
      })(
      this.files).length - 5);
    };
    prototype.writeError = function(it){
      return fs.appendFile('./error.log', it, console.error);
    };
    return Crawler;
  }());
  new Crawler(process.argv[2], process.argv[3]);
  function import$(obj, src){
    var own = {}.hasOwnProperty;
    for (var key in src) if (own.call(src, key)) obj[key] = src[key];
    return obj;
  }
  function bind$(obj, key, target){
    return function(){ return (target || obj)[key].apply(obj, arguments) };
  }
  function curry$(f, bound){
    var context,
    _curry = function(args) {
      return f.length > 1 ? function(){
        var params = args ? args.concat() : [];
        context = bound ? context || this : this;
        return params.push.apply(params, arguments) <
            f.length && arguments.length ?
          _curry.call(context, params) : f.apply(context, params);
      } : f;
    };
    return _curry();
  }
}).call(this);