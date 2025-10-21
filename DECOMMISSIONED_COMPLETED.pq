let
    Source = #"PTP MW Dump",
    #"Filtered Rows" = Table.SelectRows(Source, each ([Order Type] = "Decommission") and ([Order Stage] = "DECOMMISSIONED")),
    #"Removed Other Columns" = Table.SelectColumns(#"Filtered Rows",{"Order Number", "Path Name", "Order Status", "Order Stage", "Decommissioned Date"})
in
    #"Removed Other Columns"