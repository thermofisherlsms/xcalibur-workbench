-- Copyright (c) 2016 Thermo Fisher Scientific
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
-- (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify,
-- merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished
-- to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- menu.lua

-- Load necessary libraries

-- Get assemblies

-- Get constructors
local MainMenu = luanet.import_type("System.Windows.Forms.MainMenu")
local MenuItem = luanet.import_type("System.Windows.Forms.MenuItem")
local FolderBrowserDialog = luanet.import_type("System.Windows.Forms.FolderBrowserDialog")

-- Get enumerations
local DialogResult = luanet.import_type("System.Windows.Forms.DialogResult")

-- local variables
local menu = {}
local itemList = {}               -- List of items on the menu
menu.mainMenu = MainMenu()        -- Create a new main menu

-- Forward declarations for local helper functions

-- local functions

-- Global variables

function menu.AddMenu(args)
  args = args or {}
  if not args.name then
    print ("menu.AddMenu({name = x,  [label = y, callBack = z, parentName = xx, beforeName = yy]})")
    return nil
  end
  args.label = args.label or args.name      -- Use name for label if not specified
  
  -- Confirm name is unique
  for key, item in pairs(itemList) do
    if key == args.name then
      print ("menu.AddMenu(): name not unique")
      return nil
    end
  end
  
  -- Get parent
  local parent
  if args.parentName then
    parent = itemList[args.parentName]
  else
    parent = menu.mainMenu
  end
  if not parent then
    print ("No valid parent for name ", args.parentName)
    return nil
  end
  
  -- Get index for insertion
  local menuIndex
  if args.beforeName then                                         -- if requested to insert before a menu item
    local before = itemList[args.beforeName]                 -- get the menu item based on name
    menuIndex = parent.MenuItems:IndexOf(before)                  -- get the index of that item
    if menuIndex == -1 then
      print ("No valid before for name ", args.beforeName)
      return nil
    end
  end
  
  local menuItem = MenuItem(args.label)                           -- Get a new MenuItem
  menuItem.Name = args.name                                       -- Set it's name
  if args.callBack then menuItem.Click:Add(args.callBack) end     -- Set callback if supplied
  if args.shortCut then menuItem.Shortcut = args.shortCut end     -- Set shortcut if supplied
  itemList[args.name] = menuItem                                  -- Add item to our list for easy search
  if menuIndex then
    parent.MenuItems:Add(menuIndex, menuItem)
  else
    parent.MenuItems:Add(menuItem)                                -- Add the MenuItem to the parent
  end
  return menuItem
end

return menu
