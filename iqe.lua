--[[
------------------------------------------------------------------------------
Inter-Quake Export Loader is licensed under the MIT Open Source License.
(http://www.opensource.org/licenses/mit-license.html)
------------------------------------------------------------------------------

Copyright (c) 2014 Landon Manning - LManning17@gmail.com - LandonManning.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local path = ... .. "."
local loader = {}
local IQE = {}

loader.version = "0.1.2"

--[[ Helper Functions ]]--

-- http://wiki.interfaceware.com/534.html
local function string_split(s, d)
	local t = {}
	local i = 0
	local f
	local match = '(.-)' .. d .. '()'
	
	if string.find(s, d) == nil then
		return {s}
	end
	
	for sub, j in string.gmatch(s, match) do
		i = i + 1
		t[i] = sub
		f = j
	end
	
	if i ~= 0 then
		t[i+1] = string.sub(s, f)
	end
	
	return t
end

local function merge_quoted(t)
	local ret = {}
	local merging = false
	local buf = ""
	for k, v in ipairs(t) do
		local f, l = v:sub(1,1), v:sub(v:len())
		if f == "\"" and l ~= "\"" then
			merging = true
			buf = v
		else
			if merging then
				buf = buf .. " " .. v
				if l == "\"" then
					merging = false
					table.insert(ret, buf:sub(2,-2))
				end
			else
				if f == "\"" and l == f then
					table.insert(ret, v:sub(2, -2))
				else
					table.insert(ret, v)
				end
			end
		end
	end
	return ret
end

local function toboolean(v)
	return	(type(v) == "string" and v == "true") or
			(type(v) == "string" and v == "1") or
			(type(v) == "number" and v ~= 0) or
			(type(v) == "boolean" and v)
end


local function file_exists(file)
	if love then return love.filesystem.exists(file) end

	local f = io.open(file, "r")
	if f then f:close() end
	return f ~= nil
end

--[[ Load File ]]--

function loader.load(file, iqe)
	assert(file_exists(file), "File not found: " .. file)

	local get_lines

	if love then
		get_lines = love.filesystem.lines
	else
		get_lines = io.lines
	end

	local lines = {}

	for line in get_lines(file) do
		if line == "# Inter-Quake Export" or line[1] ~= "#" then
			line = string.gsub(line, "\t", "")
			table.insert(lines, line)
		end
	end

	if lines[1] == "# Inter-Quake Export" then
		local model = {}
		model = setmetatable(model, {__index = IQE})
		model:init(lines)
		
		return model
	else
		iqe:parse(lines)
	end
end

--[[ Inter-Quake Export ]]--

function IQE:init(lines)
	self.lines = lines
	self.current_mesh = false
	self.current_material = false
	self.current_joint = false
	self.current_animation = false
	self.current_frame = false
	self.current_vertexarray = false
	self.data = {}
	self.materials = {}
	self:parse()

	if love then
		math.random = love.math.random
		self:load_shader()
		if love.graphics.newVertexBuffer then
			self:buffer()
		end
	end
end

function IQE:parse(lines)
	self.lines = self.lines or lines
	for _, line in ipairs(self.lines) do
		local l = string_split(line, " ")
		local cmd = l[1]
		table.remove(l, 1)

		if self[cmd] then
			self[cmd](self, l)
		end
	end

	self.lines = nil
	self.current_mesh = nil
	self.current_material = nil
	self.current_joint = nil
	self.current_animation = nil
	self.current_frame = nil
	self.current_vertexarray = nil
	self.current_mtl = nil
end

function IQE:load_shader()
	local glsl = love.filesystem.read("assets/shader.glsl")
	self.shader = love.graphics.newShader(glsl, glsl)
end

--[[ Meshes ]]--

function IQE:mesh(line)
	line = merge_quoted(line)
	self.current_mesh = {}
end

function IQE:material(line)
	line = merge_quoted(line)

	self.data.material = self.data.material or {}
	self.data.material[line[1]] = self.data.material[line[1]] or {}
	table.insert(self.data.material[line[1]], self.current_mesh)
	self.current_material = self.data.material[line[1]]
end

--[[ Vertex Attributes ]]--

function IQE:vp(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vp = mesh.vp or {}
	local vp = {}
	for _, v in ipairs(line) do
		table.insert(vp, tonumber(v))
	end
	if #vp == 3 then
		table.insert(vp, 1)
	end
	table.insert(mesh.vp, vp)
end

function IQE:vt(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vt = mesh.vt or {}
	local vt = {}
	for _, v in ipairs(line) do
		table.insert(vt, tonumber(v))
	end
	table.insert(mesh.vt, vt)
end

function IQE:vn(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vn = mesh.vn or {}
	local vn = {}
	for _, v in ipairs(line) do
		table.insert(vn, tonumber(v))
	end
	table.insert(mesh.vn, vn)
end

function IQE:vx(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vx = mesh.vx or {}
	local vx = {}
	for _, v in ipairs(line) do
		table.insert(vx, tonumber(v))
	end
	table.insert(mesh.vx, vx)
end

function IQE:vb(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vb = mesh.vb or {}
	local vb = {}
	for _, v in ipairs(line) do
		table.insert(vb, tonumber(v))
	end
	table.insert(mesh.vb, vb)
end

function IQE:vc(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vc = mesh.vc or {}
	local vc = {}
	for _, v in ipairs(line) do
		table.insert(vc, tonumber(v))
	end
	if #vc == 3 then
		table.insert(vc, 1)
	end
	table.insert(mesh.vc, vc)
end

function IQE:v0(line, cmd)
	cmd = cmd or "v0"
	local mesh = self.current_material[#self.current_material]
	mesh[cmd] = mesh[cmd] or {}
	local v0 = {}
	for _, v in ipairs(line) do
		table.insert(v0, tonumber(v))
	end
	table.insert(mesh[cmd], v0)
end

function IQE:v1(line)
	IQE:v0(line, "v1")
end

function IQE:v2(line)
	IQE:v0(line, "v2")
end

function IQE:v3(line)
	IQE:v0(line, "v3")
end

function IQE:v4(line)
	IQE:v0(line, "v4")
end

function IQE:v5(line)
	IQE:v0(line, "v5")
end

function IQE:v6(line)
	IQE:v0(line, "v6")
end

function IQE:v7(line)
	IQE:v0(line, "v7")
end

function IQE:v8(line)
	IQE:v0(line, "v8")
end

function IQE:v9(line)
	IQE:v0(line, "v9")
end

--[[ Vertex Arrays ]]--

function IQE:vertexarray(line)
	line = merge_quoted(line)
	self.data.vertexarray = self.data.vertexarray or {}
	local va = {}
	va.type = line[1]
	va.component = line[2]
	va.size = tonumber(line[3])
	va.name = line[4] or line[1]
	table.insert(self.data.vertexarray, va)
	self.current_vertexarray = self.data.vertexarray[#self.data.vertexarray]
end

--[[ Triangle ]]--

function IQE:fa(line)
	local mesh = self.current_material[#self.current_material]
	mesh.fa = mesh.fa or {}
	local fa = {}
	for k, v in ipairs(line) do
		table.insert(fa, tonumber(v))
	end
	table.insert(mesh.fa, fa)
end

function IQE:fm(line)
	local mesh = self.current_material[#self.current_material]
	mesh.fm = mesh.fm or {}
	local fm = {}
	for k, v in ipairs(line) do
		table.insert(fm, tonumber(v))
	end
	table.insert(mesh.fm, fm)
end

--[[ Smoothing ]]--

function IQE:smoothuv(line)
	local mesh = self.current_material[#self.current_material]
	local n = tonumber(line[1])
	mesh.smoothuv = false

	if n > 0 then
		mesh.smoothuv = true
	end
end

function IQE:smoothgroup(line)
	local mesh = self.current_material[#self.current_material]
	local n = tonumber(line[1])
	mesh.smoothgroup = -1

	if n then
		mesh.smoothgroup = n
	end
end

function IQE:smoothangle(line)
	local mesh = self.current_material[#self.current_material]
	local angle = tonumber(line[1])
	mesh.smoothangle = 180

	if angle then
		mesh.smoothangle = angle
	end
end

function IQE:fs(line)
	local mesh = self.current_material[#self.current_material]
	mesh.fs = mesh.fs or {}
	local fs = {}
	for k, v in ipairs(line) do
		table.insert(fs, tonumber(v))
	end
	table.insert(mesh.fs, fs)
end

function IQE:vs(line)
	local mesh = self.current_material[#self.current_material]
	mesh.vs = mesh.vs or {}
	local vs = tonumber(line[1])
	table.insert(mesh.vs, vs)
end

--[[ Poses ]]--

function IQE:pq(line)
	local pq = {}
	for _, v in ipairs(line) do
		table.insert(pq, tonumber(v))
	end
	if #pq == 6 then
		table.insert(pq, -1)
		table.insert(pq, 1)
		table.insert(pq, 1)
		table.insert(pq, 1)
	end

	local joint
	if not self.current_animation then
		joint = self.current_joint
		joint.pq = pq
	else
		joint = self.current_frame
		joint.pq = joint.pq or {}
		table.insert(joint.pq, pq)
	end
end

function IQE:pm(line)
	local pm = {}
	for _, v in ipairs(line) do
		table.insert(pm, tonumber(v))
	end
	if #pm == 12 then
		table.insert(pm, 1)
		table.insert(pm, 1)
		table.insert(pm, 1)
	end

	local joint
	if not self.current_animation then
		joint = self.current_joint
		joint.pq = pq
	else
		joint = self.current_frame
		joint.pq = joint.pq or {}
		table.insert(joint.pq, pq)
	end
end

function IQE:pa(line)
	local pa = {}
	for _, v in ipairs(line) do
		table.insert(pa, tonumber(v))
	end
	if #pm == 6 then
		table.insert(pa, 1)
		table.insert(pa, 1)
		table.insert(pa, 1)
	end

	local joint
	if not self.current_animation then
		joint = self.current_joint
		joint.pq = pq
	else
		joint = self.current_frame
		joint.pq = joint.pq or {}
		table.insert(joint.pq, pq)
	end
end

--[[ Skeleton ]]--

function IQE:joint(line)
	line = merge_quoted(line)
	self.data.joint = self.data.joint or {}
	self.data.joint[line[1]] = {}

	self.current_joint = self.data.joint[line[1]]
	self.current_joint.parent = tonumber(line[2])
end

--[[ Animations ]]--

function IQE:animation(line)
	line = merge_quoted(line)
	self.data.animation = self.data.animation or {}
	local name = line[1] or tostring(math.random(0, 99999))
	self.data.animation[name] = {}
	self.current_animation = self.data.animation[name]
	self.current_frame = false
end

function IQE:loop(line)
	local animation = self.current_animation
	animation.loop = true
end

function IQE:framerate(line)
	local animation = self.current_animation
	animation.framerate = tonumber(line[1])
end

function IQE:frame(line)
	local animation = self.current_animation
	animation.frame = animation.frame or {}
	table.insert(animation.frame, {})
	self.current_frame = animation.frame[#animation.frame]
end

--[[ Wavefront Material File ]]--

function IQE:newmtl(line)
	line = merge_quoted(line)
	self.materials[line[1]] = self.materials[line[1]] or {}
	self.current_mtl = self.materials[line[1]]
end

function IQE:Ns(line)
	self.current_mtl.ns = tonumber(line[1])
end

function IQE:Ka(line)
	self.current_mtl.ka = { tonumber(line[1]), tonumber(line[2]), tonumber(line[3]) }
end

function IQE:Kd(line)
	self.current_mtl.kd = { tonumber(line[1]), tonumber(line[2]), tonumber(line[3]) }
end

function IQE:Ks(line)
	self.current_mtl.ks = { tonumber(line[1]), tonumber(line[2]), tonumber(line[3]) }
end

function IQE:Ni(line)
	self.current_mtl.ni = tonumber(line[1])
end

function IQE:d(line)
	self.current_mtl.d = tonumber(line[1])
end

function IQE:illum(line)
	self.current_mtl.illum = tonumber(line[1])
end

function IQE:map_Kd(line)
	line = merge_quoted(line)
	self.current_mtl.map_kd = line[1]
end

--[[ Render ]]--

function IQE:buffer()
	self.buffer = {}
	self.buffer.mesh = {}

	for k, material in pairs(self.data.material) do
		for _, mesh in ipairs(material) do
			local layout = {
				"float", 3,
				"float", 3,
				"float", 2,
				"byte", 4, -- bone indices
				"float", 4 -- bone weight
			}

			local data = {}
			for i = 1,#mesh.vp do
				local vp = mesh.vp[i]
				local vn = mesh.vn[i]
				local vt = mesh.vt[i]
				local vb = mesh.vb[i]

				local current = {}
				table.insert(current, vp[1])
				table.insert(current, vp[2])
				table.insert(current, vp[3])

				table.insert(current, vn[1] or 0)
				table.insert(current, vn[2] or 0)
				table.insert(current, vn[3] or 0)

				table.insert(current, vt[1] or 0)
				table.insert(current, vt[2] or 0)

				table.insert(current, vb[1] or 0)
				table.insert(current, vb[3] or 0)
				table.insert(current, vb[5] or 0)
				table.insert(current, vb[7] or 0)

				table.insert(current, vb[2] or 0)
				table.insert(current, vb[4] or 0)
				table.insert(current, vb[6] or 0)
				table.insert(current, vb[8] or 0)

				table.insert(data, current)
			end

			local tris = {}
			for _, v in ipairs(mesh.fm) do
				table.insert(tris, v[1] + 1)
				table.insert(tris, v[2] + 1)
				table.insert(tris, v[3] + 1)
			end

			-- HACK: Use the built in vertex positions for UV coords.
			local m = love.graphics.newMesh(mesh.vt, nil, "triangles")

			if m then
				table.insert(self.buffer.mesh, { material=k, mesh=m })
			else
				error("Something went terribly wrong creating the mesh.")
				break
			end

			local buffer = love.graphics.newVertexBuffer(layout, data, "static")

			if not buffer then
				error("Something went terribly wrong creating the vertex buffer.")
			end

			m:setVertexAttribute("v_position", buffer, 1)
			m:setVertexAttribute("v_normal", buffer, 2)
			m:setVertexAttribute("v_bone", buffer, 3)
			m:setVertexAttribute("v_weight", buffer, 4)
			m:setVertexMap(tris)
		end
	end
end

function IQE:update(dt)
	self.timer:update(dt)

	if self.animation then

	end
end

function IQE:draw()
	if self.shader then
		love.graphics.setShader(self.shader)
		for _, mesh in ipairs(self.buffer.mesh) do
			local mtl = self.materials[mesh.material]
			if mtl then
				self.shader:send("u_Ka", mtl.ka)
				self.shader:send("u_Kd", mtl.kd)
				self.shader:send("u_Ks", mtl.ks)
				self.shader:send("u_Ns", mtl.ns)
			end
			love.graphics.draw(mesh.mesh)
		end
		love.graphics.setShader()
	end
end

function IQE:animate(animation, Timer)
	self.timer = self.timer or assert(Timer.new(), "No timer loaded. vrld's HUMP.Timer recommended.")
	local ani = assert(self.data.animation[animation], string.format("No such animation: %s", animation))

	self.animation = {}
	self.animation.name = animation
	self.animation.frame = ani.frame
	self.animation.framerate = ani.framerate
	self.animation.loop = ani.loop
	self.animation.current_frame = 1
end

function IQE:next_frame()
	self.timer:tween() -- recursive
end

return loader
