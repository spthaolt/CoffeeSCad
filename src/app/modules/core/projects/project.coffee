define (require)->
  $ = require 'jquery'
  _ = require 'underscore'
  Backbone = require 'backbone'
  buildProperties = require 'modules/core/utils/buildProperties'
  Compiler = require './compiler'
  
  debug  = false
  
  class ProjectFile extends Backbone.Model
    idAttribute: 'name'
    defaults:
      name:     "testFile.coffee"
      content:  ""
      isSaveAdvised: false
      isCompileAdvised: false
    attributeNames: ['name','content','isSaveAdvised','isCompileAdvised']
    persistedAttributeNames : ['name','content']
    buildProperties @
      
    constructor:(options)->
      super options
      #This is used for "dirtyness compare" , might be optimisable (storage vs time , hash vs direct compare)
      @storedContent = @content
      @on("save",   @_onSaved)
      @on("change:name", @_onNameChanged)
      @on("change:content", @_onContentChanged)
    
    _onNameChanged:()=>
      @isSaveAdvised = true

    _onContentChanged:()=>
      @isCompileAdvised = true
      if (@storedContent is @content)
        @isSaveAdvised = false
      else
        @isSaveAdvised = true
    
    _onSaved:()=>
      #when save is sucessfull
      @storedContent = @content
      @isSaveAdvised = false
   
    save: (attributes, options)=>
      backup = @toJSON
      @toJSON= =>
        attributes = _.clone(@attributes)
        for attrName, attrValue of attributes
          if attrName not in @persistedAttributeNames
            delete attributes[attrName]
        return attributes
       
      super attributes, options 
      @toJSON=backup
      @trigger("save",@)
     
     destroy:(options)=>
      options = options or {}
      @trigger('destroy', @, @collection, options)
      
      
  class Folder extends Backbone.Collection
    model: ProjectFile
    sync : null
    constructor:(options)->
      super options
      @_storageData = []

    save:=>
      for index, file of @models
        file.sync = @sync
        file.save() 
      
    changeStorage:(storeName,storeData)->
      for oldStoreName in  @_storageData
        delete @[oldStoreName]
      @_storageData = []  
      @_storageData.push(storeName)
      @[storeName] = storeData
      for index, file of @models
        file.sync = @sync 
        #file.pathRoot= project.get("name")
   
  class Project extends Backbone.Model
    """Main aspect of coffeescad : contains all the files
    * project is a top level element ("folder"+metadata)
    * a project contains files 
    * a project can reference another project (includes)
    """
    idAttribute: 'name'
    defaults:
      name:     "Project"
      lastModificationDate: null
      isSaveAdvised:false #based on propagation from project files : if a project file is changed, the project is tagged as "dirty" aswell
      isCompiled: false
      isCompileAdvised:false
    
    attributeNames: ['name','lastModificationDate','isCompiled','isSaveAdvised','isCompileAdvised']
    persistedAttributeNames : ['name','lastModificationDate']
    buildProperties @
    
    constructor:(options)->
      options = options or {}
      super options
      @compiler = options.compiler ? new Compiler()
      
      @rootFolder = new Folder()
      @rootFolder.on("reset",@_onFilesReset)
      
      classRegistry={}
      @bom = new Backbone.Collection()
      @rootAssembly = {}
      @dataStore = null
      
      @on("change:name", @_onNameChanged)
      @on("compiled",@_onCompiled)
      @on("compile:error",@_onCompileError)
      
    addFile:(options)->
      file = new ProjectFile
        name: options.name ? @name+".coffee"
        content: options.content ? " \n\n"  
      @_addFile file   
      return file
      
    removeFile:(file)=>
      @rootFolder.remove(file)
      @isSaveAdvised = true
    
    save: (attributes, options)=>
      #project is only a container, if really necessary data could be stored inside the metadata file (.project)
      @dataStore.saveProject(@)
      @isSaveAdvised = false
      @isCompileAdvised = false  
      @trigger("save",@)
      
    compile:(options)=>
      if not @compiler?
        throw new Error("No compiler specified")
      @compiler.project = @
      @compiler.compile(options)
      
    _addFile:(file)=>
      @rootFolder.add file
      @_setupFileEventHandlers(file)
      @isSaveAdvised = true
    
    _setupFileEventHandlers:(file)=>
      file.on("change",@_onFileChanged)
      file.on("save",@_onFileSaved)
      file.on("destroy",@_onFileDestroyed)
      
    _clearFlags:=>
      #used to reset project into a "neutral" state (no save and compile required)
      for file in @rootFolder.models
        file.isSaveAdvised = false
        file.isCompileAdvised = false
      @isSaveAdvised = false
      @isCompileAdvised = false
      
    _onCompiled:=>
      @compiler.project = null
      @isCompileAdvised = false
      for file in @rootFolder.models
        file.isCompileAdvised = false
      @isCompiled = true
      
    _onCompileError:=>
      @compiler.project = null
      
    _onNameChanged:(model, name)=>
      try
        mainFile = @rootFolder.get(@previous('name')+".coffee")
        if mainFile?
          console.log "project name changed from #{@previous('name')} to #{name}"
          mainFile.name = "#{name}.coffee"
      catch error
        console.log "error in rename : #{error}"
    
    _onFilesReset:()=>
      #add various event bindings, reorder certain specific files
      mainFileName ="#{@name}.coffee"
      mainFile = @rootFolder.get(mainFileName)
      @rootFolder.remove(mainFileName)
      @rootFolder.add(mainFile, {at:0})
      
      configFileName = "config.coffee"
      configFile = @rootFolder.get(configFileName)
      @rootFolder.remove(configFileName)
      @rootFolder.add(configFile, {at:1})
      
      for file in @rootFolder.models
        @_setupFileEventHandlers(file)
        
      @_clearFlags()
    
    _onFileSaved:(fileName)=>
      @lastModificationDate = new Date()
      for file of @rootFolder
        if file.isSaveAdvised
          return
      
    _onFileChanged:(file)=>
      @isSaveAdvised = file.isSaveAdvised if file.isSaveAdvised is true
      @isCompileAdvised = file.isCompileAdvised if file.isCompileAdvised is true
    
    _onFileDestroyed:(file)=>
      if @dataStore
        @dataStore.destroyFile(@name, file.name)
      
  return Project
