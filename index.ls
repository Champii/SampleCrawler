global import require \prelude-ls
child = require 'child_process'
async = require 'async'
fs = require 'fs'
progress = require 'progress-stream'
req = require 'request'
readline = require 'readline'
unzip = require \unzip

if process.argv.length < 3
  console.log 'Usage: ./lsc . PATH [MAX_PROCESSING=20]'
  process.exit!

class Crawler

  (@path, @maxFiles = 20) ->
    @files = []
    @start!

  start: ->
    fs.unlink \./error.log, ->

    child.exec 'curl http://www.musicradar.com/news/tech/free-music-samples-download-loops-hits-and-multis-627820', (err, stdout, stderr) ~>
      return console.error err if err?

      @pages = map (.[til -1]*''), stdout.match /\/sampleradar-[0-9]{6}.([0-9]+")*/g
      async.each @pages, @~get-page, ~>
      setInterval @~download-progress, 1000

  get-page: (id, done) ->
    child.exec "curl http://www.musicradar.com/news/tech#id", (err, stdout, stderr) ~>
      return done err if err?
      files = stdout.match /http:\/\/cdn.mos.musicradar.com\/audio\/samples\/([a-z]|[0-9]|-)+\.zip/g
      return done! if not files?
      names = files |> map (.match /.+musicradar-(.+\.zip)/ .1)
      files = zip files, names
        |> map ->
          url: it.0
          name: it.1
          downloaded: 0
          speed: 0
          finished: false
          downloading: false
          unzipping: false

      if not files?
        @write-error "Didnt found files for #id\n"

      @files = @files ++ files
      done!

  get-file: (file) ->

    file.downloading = true
    str = progress time: 1000

    str.on \progress (prog) ~>
      file.downloaded = Math.floor prog.transferred / (1024 ^ 2)
      file.speed = Math.floor prog.speed / 1024

    req file.url
      .pipe str
      .pipe fs.createWriteStream "/tmp/#{file.name}"
      .on \finish ~>
        file.downloading = false
        @unzip-file file

  download-progress: ->
    if (@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length < @maxFiles
      @get-file find (-> not it.finished and not (it.downloading or it.unzipping)), @files

    @download-aff!

  unzip-file: (file) ->
    file.unzipping = true
    fs.createReadStream "/tmp/#{file.name}"
      .pipe unzip.Extract path: "/tmp"
      .on \close ~>
        file.unzipping = false
        file.finished = true

  download-aff: ->
    readline.clearScreenDown process.stdout
    @files |> filter (-> !it.finished and it.downloading) |> map -> console.log "#{it.downloaded}Mo, #{it.speed}Ko/s -> #{it.name}"
    @files |> filter (-> !it.finished and it.unzipping) |> map ->   console.log "Unzipping...  -> #{it.name}"
    console.log '---'
    console.log "Processing       : #{(@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length}/#{@maxFiles} files"
    console.log "Finished         : #{(@files |> filter (.finished)).length}/#{@files.length}"
    console.log "Total speed      : #{fold1 (+), map (.speed), @files}Ko/s"
    console.log "Total downloaded : #{fold1 (+), map (.downloaded), @files}Mo"
    readline.moveCursor process.stdout, 0, -(@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length - 5

  write-error: ->
    fs.appendFile \./error.log it, console.error

new Crawler process.argv[2], process.argv[3]