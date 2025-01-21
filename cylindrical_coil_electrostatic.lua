-- File name
ROOT_DIR = ""
SIM_NAME = "cylindrical_coil_electrostatic"
FEE_FILE = ROOT_DIR .. SIM_NAME .. ".fee"

-- Problem definition
UNITS = "meters"
TYPE = "axi"
PRECISION = 1e-12

-- Coil
RW = 0.4e-3 -- Radius of wire
N = 100 -- Number of turns
R = 35e-3 -- Radius of coil
H = 200e-3 -- Height of coil
COPPER_CONDUCTIVITY = 56
RESOLUTION_WIRE = 20

-- Boundary condition
R_IN = H * 4 -- Radius of interior region
R_EX = R_IN / 10 -- Radius of exterior region
RESOLUTION_AIR = 200


function main()
  showconsole()
  clearconsole()
  local t_start = now()
  run_electrostatic_analysis()
  local t_elapsed = now() - t_start
  print(format("Total Elapsed Time = %02d:%02d:%02d",
    t_elapsed/3600, t_elapsed/60, modulus(t_elapsed, 60)))
end


function now()
  return 3600*date("%H") + 60*date("%M") + date("%S")
end


function modulus(a, b)
  return a - floor(a/b)*b
end


function run_electrostatic_analysis()
  local ELECTROSTATIC = 1
  local STORED_ENERGY = 0
  local VOLTS = 1
  local MANUAL = 0
  local AUTO = 1

  -- Create a project
  newdocument(ELECTROSTATIC)
  ei_saveas(FEE_FILE)

  ei_probdef(UNITS, TYPE, PRECISION)
  ei_addmaterial("Air", 1, 1, 0, 0, 0)
  ei_addmaterial("Copper", 1, 1, 0, 0, COPPER_CONDUCTIVITY)

  -- Create a coil
  for i = 1, N do
    ei_addconductorprop(
        format("Cond%d", i), -- conductorname
        (i - 1)/(N - 1), -- Vc
        0, -- qc
        VOLTS -- conductortype
    )
  end
  add_cylindrical_coil(R, H, N, RW, 0, 0, RESOLUTION_WIRE)
  add_region_kelvin(R_IN, R_EX, AUTO, 0)
  ei_zoomnatural()

  -- Run the simulation
  ei_analyze()

  -- Get the simulation result
  ei_loadsolution()
  eo_zoomnatural()

  -- Calculate R+L
  eo_selectblock(R_IN / 10, -0.9 * R_IN)
  local stray_cap = 2 * eo_blockintegral(STORED_ENERGY)
  eo_clearblock()
  print(format("C1 = %.1e F", stray_cap))

  ei_saveas(FEE_FILE)
end


function add_cylindrical_coil(radius, height, n_turns, rw, z, offset, resolution)
  local MANUAL = 0
  local mesh_size = rw / resolution
  local hu = height / n_turns
  local center = 0
  local bottom = 0
  local top = 0
  for i = 1, n_turns do
    center = z + hu/2 + hu*(i - 1)
    bottom = center - rw
    top = center + rw
    ei_addnode(radius, bottom)
    ei_addnode(radius, top)
    ei_addarc(radius, bottom, radius, top, 180, 1)
    ei_addarc(radius, top, radius, bottom, 180, 1)
    ei_addblocklabel(radius, center)
    ei_selectlabel(radius, center)
    ei_setblockprop("Copper", MANUAL, mesh_size, 0, 0)

    ei_selectarcsegment(radius - rw, center)
    ei_selectarcsegment(radius + rw, center)
    ei_setarcsegmentprop(1, "", 0, 0, format("Cond%d", offset + i))
  end
end


function add_region_kelvin(rin, rex, auto, resolution)
  local PERIODIC = 4
  local MANUAL = 0
  local AUTO = 1

  ei_deleteboundprop("Periodic")
  ei_addboundprop("Periodic", 0, 0, 0, 0, 0, 0, 0, 0, PERIODIC)

  -- Add an interior region
  add_boundary(0, rin)
  if auto then
    add_region(0, rin, AUTO, 0)
  else
    add_region(0, rin, MANUAL, rin/resolution)
  end

  -- Add an exterior region
  add_boundary(rin + rex, rex)
  add_region(rin + rex, rex, AUTO, 0)

  ei_defineouterspace(rin + rex, rex, rin)
  ei_attachouterspace()
end

function add_boundary(center, radius)
  local bottom = center - radius
  local top = center + radius
  ei_addnode(0, bottom)
  ei_addnode(0, top)
  ei_addarc(0, bottom, 0, top, 180, 1)
  ei_addsegment(0, bottom, 0, top)
  ei_selectarcsegment(-radius, center)
  ei_setarcsegmentprop(1, "Periodic")
end

function add_region(center, radius, auto, mesh_size)
  local xl = radius / 10
  local yl = center - 0.9 * radius
  ei_addblocklabel(xl, yl)
  ei_selectlabel(xl, yl)
  ei_setblockprop("Air", auto, mesh_size, 0)
end

-- Call main function
main()