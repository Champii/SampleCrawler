global import require \prelude-ls
require! {
  async
  fs
  \progress-stream
  request
  readline
  \adm-zip
  path
}

class Crawler

  (@path = \., @maxFiles = 20) ->
    @files = []
    @start!

  start: ->
    fs.unlink \./error.log, ->

    request 'http://www.musicradar.com/news/tech/free-music-samples-download-loops-hits-and-multis-627820', (err, res, body) ~>
      return console.error err if err?

      @pages = map (.[til -1]*''), body.match /\/sampleradar-[0-9]{6}.([0-9]+")*/g

      async.eachSeries @pages, @~get-page, ~>
      setInterval @~download-progress, 1000

  get-page: (id, done) ->
    request "http://www.musicradar.com/news/tech#id", (err, res, body) ~>
      return done err if err?

      files = body.match /http:\/\/cdn.mos.musicradar.com\/audio\/samples\/([a-z]|[0-9]|-)+\.zip/g
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

      file-exists = (file) -> try fs.statSync file .isDirectory!

      each (~> if file-exists (path.resolve @path, 'musicradar-' + it.name[til -4]*'') => then it.finished = true), files

      @files = @files ++ files

      done!

  get-file: (file) ->
    return if not file?
    file.downloading = true
    str = progress-stream time: 1000

    str.on \progress (prog) ~>
      file.downloaded = Math.floor prog.transferred / (1024 ^ 2)
      file.speed = Math.floor prog.speed / 1024

    request file.url
      .pipe str
      .pipe fs.createWriteStream path.resolve @path, file.name
      .on \error  @~write-error
      .on \finish ~>
        file.downloading = false
        file.speed = 0
        file.unzipping = true
        @unzip-file file

  download-progress: ->
    if (@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length < @maxFiles
      @get-file find (-> not it.finished and not (it.downloading or it.unzipping)), @files

    @download-aff!

  unzip-file: (file) ->
    zip = new adm-zip path.resolve @path, file.name
    zip.extractAllTo @path, true
    file.finished = true
    file.unzipping = false


    # minizip.unzip path.resolve(@path, file.name), @path, (err) ~>
    #   file.finished = true
    #   file.unzipping = false
    #   @write-error err if err?


      # file.unz
    # fs.createReadStream "#{path.resolve @path, file.name}"
    #   .pipe unzip.Extract path: @path
    #   .on \error  @~write-error
    #   .on \close ~>
        # file.unzipping = false
        # file.finished = true

  download-aff: ->
    readline.clearScreenDown process.stdout
    @files |> filter (-> !it.finished and it.downloading) |> map -> console.log "#{it.downloaded}Mo, #{it.speed}Ko/s -> #{it.name}"
    @files |> filter (-> !it.finished and it.unzipping)   |> map -> console.log "Unzipping...  -> #{it.name}"
    console.log '---'
    console.log "Extracting to    : #{path.resolve @path}"
    console.log "Processing       : #{(@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length}/#{@maxFiles} files"
    console.log "Finished         : #{(@files |> filter (.finished)).length}/#{@files.length}"
    console.log "Total speed      : #{fold1 (+), map (.speed), @files}Ko/s"
    console.log "Total downloaded : #{fold1 (+), map (.downloaded), @files}Mo"
    readline.moveCursor process.stdout, 0, -(@files |> filter (-> !it.finished and (it.downloading or it.unzipping))).length - 6

  write-error: ->
    fs.appendFile \./error.log it + '\n', ->

new Crawler process.argv[2], process.argv[3]
