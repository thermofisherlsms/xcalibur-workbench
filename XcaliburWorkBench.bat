:: Set LUA_PATH and LUA_CPATH so all libraries can be found
:: These will only be active for this session and won't impact the global environment variables
:: To get the LUA_PATH for your installation, start Xcalibur Workbench, and from the command entry
:: bar at the bottom of the main window, type 'print (package.path)'.  The results will show up
:: in the ZBS console
set LUA_PATH=";.\?.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin\lua\?.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin\lua\?\init.lua;;C:\Program Files (x86)\Lua\5.1\lua\?.luac;./?.lua;./?/init.lua;./lua/?.lua;./lua/?/init.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\lualibs/?/?.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\lualibs/?.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\lualibs/?/?/init.lua;C:\Users\michael.senko\Documents\ZeroBraneStudio\lualibs/?/init.lua;C:\Program Files (x86)\Lua\5.1/?.lua;C:\Program Files (x86)\Lua\5.1/?/init.lua;C:\Program Files (x86)\Lua\5.1/lua/?.lua;C:\Program Files (x86)\Lua\5.1/lua/?/init.lua;.\Utilities/?.lua"
:: To get the LUA_CPATH for your installation, start Xcalibur Workbench, and from the command entry
:: bar at the bottom of the main window, type 'print (package.cpath)'.  The results will show up
:: in the ZBS console
set LUA_CPATH=";.\?.dll;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin\?.dll;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin\loadall.dll;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin/?.dll;C:\Users\michael.senko\Documents\ZeroBraneStudio\bin/clibs/?.dll;C:\Program Files (x86)\Lua\5.1/?.dll;C:\Program Files (x86)\Lua\5.1/?51.dll;C:\Program Files (x86)\Lua\5.1/clibs/?.dll;C:\Program Files (x86)\Lua\5.1/clibs/?51.dll"
:: Switch directories
:: Set this to the directory where you have Xcalibur Workbench installed
cd C:\Users\michael.senko\Documents\ZeroBraneStudio\myprograms\LuaBrowser\xcalibur-workbench
:: Launch Luajit, starting the workbench and passing command line arguments, which should be file names
:: Set this to the directory you have ZBS installed
C:\Users\michael.senko\Documents\ZeroBraneStudio\bin\lua.exe Workbench.lua %*
