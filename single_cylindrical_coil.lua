-- File name
ROOT_DIR = ""
SIM_NAME = "single_cylindrical_coil"
FEM_FILE = ROOT_DIR .. SIM_NAME .. ".fem"

-- Problem definition
UNITS = "meters"
TYPE = "axi"
PRECISION = 1e-12
FREQ = 100e3

-- Coil
RW = 0.4e-3 -- Radius of wire
N = 10 -- Number of turns
R = 20e-3 -- Radius of coil
H = 20e-3 -- Height of coil
COPPER_CONDUCTIVITY = 56
RESOLUTION_WIRE = 20

-- Boundary condition
R_IN = H * 4 -- Radius of interior region
R_EX = R_IN / 10 -- Radius of exterior region
RESOLUTION_AIR = 100


function main()
  showconsole()
  clearconsole()
  run_magnetic_analysis()
end


function run_magnetic_analysis()
  local MAGNETIC = 0
  local CURRENT = 1
  local MANUAL = 0
  local AUTO = 1

  -- Create a project
  newdocument(MAGNETIC)
  mi_saveas(FEM_FILE)

  mi_probdef(FREQ, UNITS, TYPE, PRECISION)
  mi_addmaterial("Air", 1, 1, 0, 0, 0)
  mi_addmaterial("Copper", 1, 1, 0, 0, COPPER_CONDUCTIVITY)
  print(format("f = %.1e Hz", FREQ))

  -- Add a current source and a coil
  mi_addcircprop("I1", 0, 1)

  add_cylindrical_coil(R, H, N, RW, 0, "I1", RESOLUTION_WIRE)
  add_region_kelvin(R_IN, R_EX, AUTO, 0)
  mi_zoomnatural()

  -- Run the simulation
  mi_modifycircprop("I1", CURRENT, 1)
  mi_analyze()

  -- Get the simulation result
  mi_loadsolution()
  mi_zoomnatural()

  -- Calculate R+L
  local current, volts = mo_getcircuitproperties("I1")
  local r = re(volts) -- Resistance
  local l = im(volts) / (2*PI*FREQ) -- Inductance
  print(format("R = %.1e Ohm, L = %.1e Henry", r, l))

  mi_saveas(FEM_FILE)
end


function add_cylindrical_coil(radius, height, n_turns, rw, z, circuit, resolution)
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
    mi_addnode(radius, bottom)
    mi_addnode(radius, top)
    mi_addarc(radius, bottom, radius, top, 180, 1)
    mi_addarc(radius, top, radius, bottom, 180, 1)
    mi_addblocklabel(radius, center)
    mi_selectlabel(radius, center)
    mi_setblockprop("Copper", MANUAL, mesh_size, circuit, 0, 0, 0)
  end
end


function add_region_kelvin(rin, rex, auto, resolution)
  local PERIODIC = 4
  local MANUAL = 0
  local AUTO = 1

  mi_deleteboundprop("Periodic")
  mi_addboundprop("Periodic", 0, 0, 0, 0 , 0, 0, 0, PERIODIC)

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

  mi_defineouterspace(rin + rex, rex, rin)
  mi_attachouterspace()
end

function add_boundary(center, radius)
  local bottom = center - radius
  local top = center + radius
  mi_addnode(0, bottom)
  mi_addnode(0, top)
  mi_addarc(0, bottom, 0, top, 180, 1)
  mi_addsegment(0, bottom, 0, top)
  mi_selectarcsegment(-radius, center)
  mi_setarcsegmentprop(1, "Periodic")
end

function add_region(center, radius, auto, mesh_size)
  local xl = radius / 10
  local yl = center - 0.9 * radius
  mi_addblocklabel(xl, yl)
  mi_selectlabel(xl, yl)
  mi_setblockprop("Air", auto, mesh_size, "", 0, 0, 0)
end

-- Call main function
main()