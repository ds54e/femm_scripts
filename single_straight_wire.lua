-- File name
ROOT_DIR = ""
SIM_NAME = "single_straight_wire"
FEM_FILE = ROOT_DIR .. SIM_NAME .. ".fem"

-- Problem definition
UNITS = "meters"
TYPE = "planar"
PRECISION = 1e-12
FREQ = 100e3

-- Copper wire
RW = 0.4e-3 -- Radius of wire
COPPER_CONDUCTIVITY = 56
RESOLUTION = 20

-- Boundary condition
R_IN = RW * 20 -- Radius of interior region
R_EX = R_IN/10 -- Radius of exterior region


function main()
  showconsole()
  clearconsole()
  run_magnetic_analysis()
end


function run_magnetic_analysis()
  local MAGNETIC = 0
  local CURRENT = 1

  -- Create a project
  newdocument(MAGNETIC)
  mi_saveas(FEM_FILE)

  mi_probdef(FREQ, UNITS, TYPE, PRECISION)
  mi_addmaterial("Air", 1, 1, 0, 0, 0)
  mi_addmaterial("Copper", 1, 1, 0, 0, COPPER_CONDUCTIVITY)
  print(format("f = %.1e Hz", FREQ))

  -- Add current sources and wires
  mi_addcircprop("I1", 0, 1)

  add_wire(0, RW, "I1", RESOLUTION)
  add_region_kelvin(R_IN, R_EX)
  mi_zoomnatural()

  -- Run the simulation
  mi_modifycircprop("I1", CURRENT, 1)
  mi_analyze()

  -- Get the simulation result
  mi_loadsolution()
  mi_zoomnatural()

  -- Calculate R+L
  local current, volts = mo_getcircuitproperties("I1")
  local ru = re(volts) -- Resistance per meter
  local lu = re(volts) / (2*PI*FREQ) -- Inductance per meter
  print(format("R = %.1e Ohm / meter, L = %.1e Henry / meter", ru, lu))

  mi_saveas(FEM_FILE)
end

function add_wire(x, rw, circuit, resolution)
  local MANUAL = 0
  local mesh_size = rw / resolution
  mi_addnode(x, -rw)
  mi_addnode(x, rw)
  mi_addarc(x, -rw, x, rw, 180, 1)
  mi_addarc(x, rw, x, -rw, 180, 1)
  mi_addblocklabel(x, 0)
  mi_selectlabel(x, 0)
  mi_setblockprop("Copper", MANUAL, mesh_size, circuit, 0, 0, 0)
end


function add_region_kelvin(rin, rex)
  local PERIODIC = 4

  mi_deleteboundprop("Periodic")
  mi_addboundprop("Periodic", 0, 0, 0, 0 , 0, 0, 0, PERIODIC)

  -- Add an interior region
  add_boundary(0, rin)
  add_region(0, rin)

  -- Add an exterior region
  add_boundary(rin + rex, rex)
  add_region(rin + rex, rex)

  mi_defineouterspace(rin + rex, rex, rin)
  mi_attachouterspace()
end

function add_boundary(center, radius)
  mi_addnode(0, center - radius)
  mi_addnode(0, center + radius)
  mi_addarc(0, center - radius, 0, center + radius, 180, 1)
  mi_addarc(0, center + radius, 0, center - radius, 180, 1)
  mi_selectarcsegment(-radius, center)
  mi_setarcsegmentprop(1, "Periodic")
  mi_selectarcsegment(radius, center)
  mi_setarcsegmentprop(1, "Periodic")
end

function add_region(center, radius)
  local AUTO = 1
  local mesh_size = 0
  local xl = radius / 10
  local yl = center - 0.9 * radius
  mi_addblocklabel(xl, yl)
  mi_selectlabel(xl, yl)
  mi_setblockprop("Air", AUTO, mesh_size, "", 0, 0, 0)
end

-- Call main function
main()
