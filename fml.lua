-- Filesystem Mapper Library
-- The /other/ FML. :3
-- by zorg § ISC @ 2018-

-- TODO:
-- - createDirectory dumps itself seemingly into the root of the vfs, but
--   after a restart, it's in the correct place; fix this.



-- Safeguards
assert(select(1, love.getVersion()) >= 10,
	"This library needs at least LÖVE 11.0.0 to function.")
assert(love.filesystem or love.system,
	"This library needs love.filesystem and love.system enabled to function.")

-- Relative paths
local path = (...):match("(.-)[^%.]+$")

-- FFI löve.
local ffi = require "ffi"
local liblove = ffi.C
if ffi.os == "Windows" then
	liblove = ffi.load("love")
	ffi.cdef('int GetLogicalDrives(void);')
end

-- Define PhysFS constants and functions through the FFI.
ffi.cdef(love.filesystem.load(path .. '/physfs_decl.h')())

-- Virtual FS Root directories (defaults included, renameable in init)
local vfsr_sys = 'drv' -- Real FS roots, simulated on Windows.
local vfsr_src = 'src' -- Points to project folder/inside zip (if fused).
local vfsr_usr = 'usr' -- Points to project save folder (default write dir).

-- PhysFS-version dependent unmount helper function
local unmount
do
	local ver = ffi.new('PHYSFS_Version[1]')
	liblove.PHYSFS_getLinkedVersion(ver)
	-- PhysFS unmount func. name depends on what version Löve was built with.
	if (ver[0].major == 2 and ver[0].minor > 0) or ver[0].major > 2 then
		unmount = liblove.PHYSFS_unmount
	else
		unmount = liblove.PHYSFS_removeFromSearchPath
	end
end

-- Used in setIdentity
local normalize = function(path)
	local s = {}
	local prev, curr = false, false
	path:gsub(".", function(c)
    	curr = (c == '/')
    	if not (curr and prev) then
    		table.insert(s,c)
    	end
    	prev = curr
	end)
	return table.concat(s)
end

--[[

	-- Windows-exclusive virtual root builder, and its helper functions
	-- Note: io.popen is not guaranteed to exist on all systems,
	--       hence the failsafe.
	local popen = function(cmd, mode)
		if io.popen then
			local tmp = io.popen('dir')
			if tmp ~= "'popen' not supported" then
				tmp:close()
				return io.popen(cmd, mode) -- File handle
			end
		end
		-- Fall back to worse method.
		local name = os.tmpname()
		os.execute(cmd .. ' > ' .. name)
		local file = io.open(name, mode)
		return file -- File handle
	end

	-- Capture the output of a command / external program.
	local capture = function(cmd, raw)
		local f = assert(popen(cmd, 'r'))
		local s = assert(f:read('*a'))
		f:close()
		if raw then return s end
		s = string.gsub(s, '^%s+', '')
		s = string.gsub(s, '%s+$', '')
		s = string.gsub(s, '[\n\r]+', ' ')
		return s
	end

--]]

local getWinDrives = function()
	local bits, drives = ffi.C.GetLogicalDrives(), {}
	for i = 0,25 do
		drives[#drives + 1] = bit.band(bits, 2^i) > 0 and string.char(string.byte('a') + i) or nil
	end

	return drives
end

local __mount_drives_hack
-- Replace Löve's own mount and unmount functions
love.filesystem.mount = function(path, mountPoint, appendToPath)
	if liblove.PHYSFS_isInit() == 0 then return false end

	-- Get rid of initial slashes.
	if mountPoint:sub(1,1) == '/' then
		mountPoint = mountPoint:sub(2)
	end

	-- We do want to mount the drives to the vfsr_sys dir internally...
	if not __mount_drives_hack then
		-- Prevent mounting into the vfsr_sys directory, since it kinda is a
		-- reflection of the real file system... but only if it's not overlapped
		-- by the other two virtual roots
		if vfsr_sys ~= vfsr_src and vfsr_sys ~= vfsr_usr then
			local same = true
			for i=1, #vfsr_sys do
				if vfsr_sys:sub(i,i) ~= mountPoint:sub(i,i) then
					same = false
					break
				end
			end
			if same then return false end
		end
	end

	local result = liblove.PHYSFS_mount(
		path, mountPoint, appendToPath and 1 or 0)
	if result ~= 0 then
		return true
	else
		return false--, liblove.PHYSFS_getLastError()
	end
end

love.filesystem.unmount = function(path)
	if liblove.PHYSFS_isInit() == 0 then return false end
	local result = unmount(path)
	if result ~= 0 then
		return true
	else
		return false--, liblove.PHYSFS_getLastError()
	end
end

-- We need to hook setIdentity so it doesn't barf the new savefolder into the
-- vfs root, rather it removes and mounts the new one in the correct location.
love.filesystem.setIdentity = function(ident, appendToPath)
	local LOVE_APPDATA_PREFIX = (love.system.getOS() == 'Linux') and
	                            '.' or ''
	local LOVE_APPDATA_FOLDER = (love.system.getOS() == 'Linux') and
	                            'love' or 'LOVE'
	local LOVE_PATH_SEPARATOR = '/'

	if liblove.PHYSFS_isInit() == 0 then return false end

	local old_save_path = love.filesystem.getSaveDirectory()

	-- Store the save directory
	local save_identity = ident -- char* -> std:string conv.; unnecessary?

	-- Generate the relative path to the game save folder.
	local save_path_relative = LOVE_APPDATA_PREFIX .. LOVE_APPDATA_FOLDER ..
	                           LOVE_PATH_SEPARATOR .. save_identity

	-- Generate the full path to the game save folder.
	local save_path_full = love.filesystem.getAppdataDirectory() ..
	                       LOVE_PATH_SEPARATOR
	if love.filesystem.isFused() then
		save_path_full = save_path_full .. LOVE_APPDATA_PREFIX .. save_identity
	else
		save_path_full = save_path_full .. save_path_relative
	end

	-- Get rid of double separators.
	save_path_full = normalize(save_path_full)

	if love.system.getOS() == 'Android' then

		if save_identity == '' then
			save_identity = 'unnamed'
		end

		local storage_path

		-- zorg: I kinda forgot why this was commented like this...
		--if liblove.isAndroidSaveExternal() then
			storage_path = liblove.SDL_AndroidGetExternalStoragePath()
		-- else
			storage_path = liblove.SDL_AndroidGetInteralStoragePath()
		-- end

		local save_directory = storage_path .. '/save'

		save_path_full = storage_path .. '/save/' .. save_identity

		-- Are these two the same as the love::android:* ones, on Android?
		if love.filesystem.exists(save_path_full) and
			not love.filesystem.createDir(save_path_full) then
			print(("Error: Could not create save directory %s!"):format(
				save_path_full))
		end

	end

	-- We now have something like:
	-- save_identity: game
	-- save_path_relative: ./LOVE/game
	-- save_path_full: C:\Documents and Settings\user\Application Data/LOVE/game

	-- We don't want old read-only save paths to accumulate when we set a new
	-- identity.
	if old_save_path or #old_save_path > 0 then
		love.filesystem.unmount(old_save_path) -- intricacies handled!
	end

	-- Try to add the save directory to the search path.
	-- (No error on fail, it means that the path doesn't exist).
	-- zorg: This is basically the only line we needed to change...
	love.filesystem.mount(save_path_full, vfsr_usr, appendToPath)

	-- HACK: This forces setupWriteDirectory to be called the next time a file
	-- is opened for writing - otherwise it won't be called at all if it was
	-- already called at least once before.
	liblove.PHYSFS_setWriteDir(nil)

	return true
end

-- Maybe we need to replace delete as well? - not yet anyway...
--[[
love.filesystem.remove = function(path)
	if liblove.PHYSFS_isInit() == 0 then return false end

	local writeDir = ffi.string(liblove.PHYSFS_getWriteDir())

	print('write dir: ' .. writeDir)

	-- Return early if the write directory isn't set.
	if not writeDir then return false end

	if not liblove.PHYSFS_delete(path) then return false end

	return true
end
--]]



-- Init function.
local init = function(usr, src, sys)
	-- If supplied, use those parameters as virtual root directories.
	assert(usr == nil or type(usr) == 'string',
		"First parameter not nil or string.")
	assert(src == nil or type(src) == 'string',
		"Second parameter not nil or string.")
	assert(sys == nil or type(sys) == 'string',
		"Third parameter not nil or string.")
	vfsr_usr = usr or vfsr_usr
	vfsr_src = src or vfsr_src
	vfsr_sys = sys or vfsr_sys

	-- Re-point both the save and source paths.
	local usrp = love.filesystem.getSaveDirectory()
	love.filesystem.unmount(usrp)
	love.filesystem.mount(usrp, vfsr_usr, true)

	local srcp = love.filesystem.getSource()
	love.filesystem.unmount(srcp)
	love.filesystem.mount(srcp, vfsr_src, true)

	-- Mount filesystem roots
	__mount_drives_hack = true
	local OS = love.system.getOS()
	if OS == 'Windows' then
		-- Will not mount disk drives that are empty / aren't mounted.
		for _, letter in ipairs(getWinDrives()) do
			love.filesystem.mount(
				letter .. ':\\', vfsr_sys .. '/' .. letter, true)
		end
	elseif OS == 'OS X' or OS == 'Linux' then
		-- Desperately needs testing.
		love.filesystem.mount('/', vfsr_sys, true)
	end
	__mount_drives_hack = false

	-- Do we need to set the lua and C require paths?
	local RPath = vfsr_usr .. "/?.lua;" .. vfsr_usr .. "/?/init.lua"
	if vfsr_src ~= vfsr_usr then
		RPath = RPath .. vfsr_src .. "/?.lua;" .. vfsr_src .. "/?/init.lua"
	end
	love.filesystem.setRequirePath(RPath)
	if ({love.getVersion()})[1] >= 11 then
		love.filesystem.setCRequirePath(RPath)
	end
end

-----------
return init
