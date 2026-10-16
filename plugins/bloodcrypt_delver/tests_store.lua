local memory={}
_G.core={
 create_data_folder=function() end,
 create_data_file=function(path) memory[path]="";return true end,
 write_data_file=function(path,text) memory[path]=text;return true end,
 read_data_file=function(path) return memory[path] end,
}
local Store=require("bc_store")
local route={name="Kindo route",variant="Labyrinth of Kindo'jan",map=16913,instance=3043,entrance_map=2395,entrance={x=1,y=2,z=3},steps={{kind="move",position={x=4,y=5,z=6}}}}
local ok,why=Store.save(15,route,1);assert(ok,why)
local loaded,err=Store.load(15,1);assert(loaded and loaded.instance==3043,err)
assert(not pcall(Store.load,15,2),"Kindo'jan must reject a nonexistent story index")
assert(not pcall(Store.load,16,1),"unknown delve IDs must be rejected")
_G.core=nil
print("PASS catalog-backed route storage includes Kindo'jan")
