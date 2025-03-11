using Graphs

g = Graphs.SimpleGraphs.kronecker(20, 16) # 20, 16 is more interesting
savegraph("kro_20_16.lgz", g)