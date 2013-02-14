define (require)->
  $ = require 'jquery'
  _ = require 'underscore'
  marionette = require 'marionette'
  
  vent = require './core/vent'
  
  MenuView = require './core/menuView'
  ModalRegion = require './core/utils/modalRegion'
  
  Project = require './core/projects/project'
  ProjectBrowserView = require './core/projects/projectBrowseView'
  
  Settings = require './core/settings/settings'
  SettingsView = require './core/settings/settingsView'
   

  class CoffeeScadApp extends Backbone.Marionette.Application
    ###
    Main application class, gets instanciated only once on startup
    ###
    root: "/CoffeeSCad/index.html/"
    title: "Coffeescad"
    regions:
      headerRegion: "#header"
      
    constructor:(options)->
      super options
      @vent = vent
      @settings = new Settings()
      
      @editors = {}
      @exporters = {}
      @connectors = {}
      
      #Exporters
      BomExporter = require './exporters/bomExporter/bomExporter'
      StlExporter = require './exporters/stlExporter/stlExporter'
      @exporters["stl"] = new StlExporter()
      @exporters["bom"] = new BomExporter()
      
      #Connectors
      DropBoxConnector = require './connectors/dropbox/dropBoxConnector'
      #GithubConnector = require './connectors/github/gitHubConnector'
      BrowserConnector = require './connectors/browser/browserConnector'
      @connectors["dropBox"] = new DropBoxConnector()
      #@connectors["gitHub"] = new GithubConnector()
      @connectors["browser"] = new BrowserConnector()
      
      #events
      $(window).bind('beforeunload',@onAppClosing)
      @on("initialize:before",@onInitializeBefore)
      @on("initialize:after",@onInitializeAfter)
      @on("start", @onStart)
      @vent.on("app:started", @onAppStarted)
      @vent.on("settings:show", @onSettingsShow)
      @vent.on("bomExporter:start", ()=> @exporters["bom"].start({project:@project}))
      @vent.on("stlExporter:start", ()=> @exporters["stl"].start({project:@project}))
      
      #just temporary
      @vent.on("project:new", @onNewProject)
      @vent.on("project:saveAs", @onSaveAsProject)
      @vent.on("project:save", @onSaveProject)
      @vent.on("project:load", @onLoadProject)
      @vent.on("project:loaded",@onProjectLoaded)
      
      @addRegions @regions
      @initLayout()
      @initData()
     
    initLayout:=>
      @menuView = new MenuView
        connectors: @connectors
        exporters: @exporters
      @headerRegion.show @menuView
    
    initSettings:->
      @settings = new Settings()
      @bindTo(@settings.get("General"), "change", @settingsChanged)
    
    initData:->
      @project = new Project({"settings": @settings}) #settings : temporary hack
      @project.createFile
        name: @project.get("name")
        content:"""
        #some comment
        class Body extends Part
          constructor:(options)->
            super options
            outShellRes = 20
            @union new Sphere({r:50,$fn:outShellRes}).color([0.9,0.5,0.1]).rotate([90,0,0])
        
        body = new Body()
        assembly.add(body)
        """
        content_cool:"""
        #just a comment
        class Body extends Part
          constructor:(options)->
            super options
            
            outShellRes = 20
            @union new Sphere({r:50,$fn:outShellRes}).color([0.9,0.5,0.1]).rotate([90,0,0])
            
            sideIndent = new Sphere({r:30,$fn:15}).rotate([90,0,0])
            @subtract sideIndent.clone().translate([0,65,0])
            @subtract sideIndent.translate([0,-65,0])
            
            innerSphere = new Sphere({r:45,$fn:outShellRes}).color([0.3,0.5,0.8]).rotate([90,0,0])
            @subtract innerSphere
            
            c = new Circle({r:25,center:[10,50,20]})
            r = new Rectangle({size:10})
            hulled = hull(c,r).extrude({offset:[0,0,100],steps:150,twist:180}).color([0.8,0.3,0.1])
            hulled.rotate([0,90,90]).translate([35,-12,0])
            #
            @union hulled.clone()
            @union hulled.mirroredY()
        
        body = new Body()
        
        plane = Plane.fromNormalAndPoint([0, 1, 0], [0, 0, 0])
        body.cutByPlane(plane)
        
        assembly.add(body)
        """
        contentf:"""
        #just a comment
        
        #console.log intersect
        
        c = new Cylinder({r:50,$fn:15,h:200})
        s = new Sphere({r:50,$fn:15})
        
        #rotate([90,0,0],[c,s])
        rotate([25,0,0],[0,0,0],c)
        translate([25,-50,20],s)
        scale([1,1,1.5],[c,s])
        
        #union([c,s])
        #subtract([c,s])
        #intersect([c,s])
        
        assembly.add(c)
        assembly.add(s)
        """
        contentu:"""
        #just a comment
        c = new Cylinder({r:50,$fn:25,h:200})
        s = new Sphere({r:50,$fn:25})
        
        c.union(s)
        assembly.add(c)
        #assembly.add(s)
"""
        contentt:"""
        #just a comment
        #cube = new Cube({size:[50,100,100],center:[-25,-50,-50]})
        #cube.color([0.1,0.8,0.5])
        #minCube = new Cube({size:[25,25,25]}).translate([0,-50,0])
        #cube.subtract(minCube)
        #assembly.add(cube)
        
        #cylinder = new Cylinder({r:50,$fn:300,h:150})
        #cylinder.color([0.8,0.4,5])
        #assembly.add(cylinder)
        
        sphere = new Sphere({r:50,$fn:95})
        sphere.color([0.9,0.5,0.1])
        minSphere = new Sphere({r:15,$fn:50}).translate([0,-55,0])
        sphere.subtract(minSphere)
        
        class Toto extends Part
          constructor:(options)->
            super options
            @union new Sphere({r:50,$fn:15}).color([0.8,0.4,5])
            @subtract new Sphere({r:15,$fn:15}).translate([0,-55,0])
        
        tut = new Toto()
        
        assembly.add(tut)
        assembly.add(sphere)
        
        """
        content_:"""
        #just a comment
        include ("config.coffee")
        include ("someFile.coffee")
        
        console.log "testVariable:"+ testVariable
        
        class Thinga extends Part
          constructor:(options) ->
            super options
            @cb = new Cube({size:[50,100,50]})
            c = new Cylinder({h:300, r:20}).color([0.8,0.5,0.2])
            @union(@cb.color([0.2,0.8,0.5]))
            @subtract(c.translate([10,0,-150]))
        
        class WobblyBobbly extends Part
          constructor:(options) ->
            defaults = {pos:[0,0,0],rot:[0,0,0]}
            options = merge defaults, options
            {@pos, @rot} = options
            super options
            @union  new Cube(size:[50,100,50],center:@pos).rotate(@rot)
        
        thinga1 = new Thinga()
        thinga2 = new Thinga()
        assembly.add(thinga1.translate([testVariable,0,testVariable2]))
        #thinga1.getBounds()
        plane = Plane.fromNormalAndPoint([0, 0, 1], [0, 0, 25])
        thinga1.cutByPlane(plane)
        #thinga1.expand(3,5)
        assembly.add(thinga1.translate([100,0,0]))
        
        wobble = new WobblyBobbly(rot:[5,25,150],pos:[-100,150,10])
        wobble2 = new WobblyBobbly(pos:[0,10,20])
        wobble3 = new WobblyBobbly(pos:[-100,10,20])
        
        assembly.add(wobble)
        assembly.add(wobble2)
        assembly.add(wobble3)
        """
      ###
      @project.createFile
        name:"config"
        content:"""
        #just a comment
        testVariable = 25
        include ("someFile.coffee")
        """
      @project.createFile
        name:"someFile"
        content:"""
        testVariable2 = 12
        """
        
        #include ("config.coffee")
        #the above does not handle comments (inclusions processing)
        #include ("Project.coffee")
      ###
    onStart:()=>
      console.log "app started"
      @codeEditor.start()
      @visualEditor.start()
      #we check if we came back form an oauth redirect/if we have already been authorized
      for index, connector of @connectors
        connector.authCheck()
      
    onAppStarted:(appName)->
      console.log "I see app: #{appName} has started"
    
    onAppClosing:()=>
      console.log "app closing, bye"
      #if @project.dirty
      #  return 'You have unsaved changes!'
    
    onSettingsShow:()=>
      settingsView = new SettingsView
        model : @settings 
      
      modReg = new ModalRegion({elName:"settings",large:true})
      modReg.show settingsView
      
    onNewProject:()=>
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "new"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
    
    onSaveProject:=>
      #if project.pfiles.sync != null
      
      ###  
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "save"
        connectors: @connectors
      ###
    onSaveAsProject:=>
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "save"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
    
    onLoadProject:=>
      projectBrowserView = new ProjectBrowserView
        model: @project
        operation: "load"
        connectors: @connectors
      
      modReg = new ModalRegion({elName:"library",large:true})
      modReg.show projectBrowserView
    
    onProjectLoaded:(newProject)=>
      console.log "project loaded"
      @project = newProject
      
    onInitializeBefore:()->
      console.log "before init"
      CodeEditor = require './editors/codeEditor/codeEditor'
      @codeEditor = new CodeEditor
        regions: 
          mainRegion: "#code"
        project: @project
        appSettings: @settings
      
      VisualEditor = require './editors/visualEditor/visualEditor'
      @visualEditor = new VisualEditor
        regions: 
          mainRegion: "#visual"
        project: @project
        appSettings: @settings
      
      @settings.fetch()
      
      #TODO: clean this hack
      @project.settings = @settings.getByName("General")
      
    onInitializeAfter:()=>
      """For exampel here close and 'please wait while app loads' display"""
      console.log "after init"

  return CoffeeScadApp   
