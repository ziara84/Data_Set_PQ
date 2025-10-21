let
    Source = #"PTP MW Dump",
    #"Filtered Rows" = Table.SelectRows(Source, each ([Order Type] <> "Visibility") and ([Order Stage] = "LIVE")),
    #"Removed Other Columns" = Table.SelectColumns(#"Filtered Rows",{"Order Number", "Path Name", "Order Status", "Order Stage", "Order Type"})
in
    #"Removed Other Columns"