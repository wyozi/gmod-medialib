-- This file loads required modules in the correct order.
-- For development version: this file is automatically called after autorun/medialib.lua
-- For distributable:       this file is loaded after packed modules have been added to medialib

medialib.load("mediabase")
medialib.load("serviceloader")

medialib.load("media")