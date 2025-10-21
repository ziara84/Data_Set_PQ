let
    CurrentDate = Date.From(DateTime.LocalNow()),
    Source = Table.NestedJoin(#"PTP MW Dump", {"Path Name"}, #"Contractors Master Sheet", {"Path Name"}, "Contractors Master Sheet", JoinKind.LeftOuter),
    #"Renamed XNG Link ID" = Table.RenameColumns(Source, {{"Link ID", "XNG Link ID"}, {"Order Status", "XNG Order Status"}}),
    #"Expanded Contractors Master Sheet" =
        Table.ExpandTableColumn(
            #"Renamed XNG Link ID",
            "Contractors Master Sheet",
            {"Path Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"},
            {"Path Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"}
        ),
    #"Added Added Order Status Column" =
        Table.AddColumn(
            #"Expanded Contractors Master Sheet",
            "Order Status",
            each if [Installation Status] = "CANCELLED" then "CANCELLED"
                else if [Category] = "REPEATOR_MW" and [Installation Status] = "Ready for Installation" then "IN-PROCESS"
                else [XNG Order Status],
            type text
        ),
    #"Added Update Link ID" = Table.AddColumn(#"Added Added Order Status Column", "Link ID", each if [MW Design Link ID] <> null then [MW Design Link ID] else [XNG Link ID], type text),
    #"Removed No need Link ID" = Table.RemoveColumns(#"Added Update Link ID", {"XNG Link ID", "MW Design Link ID", "XNG Order Status"}),
    #"Filtered Rows1" = Table.SelectRows(#"Removed No need Link ID", each ([Order Type] <> "Undefined" and [Order Type] <> "Visibility") and ([MW Contractor] <> "")),
    #"Removed Duplicates" = Table.Distinct(#"Filtered Rows1", {"Order Number", "Path Name"}),
    #"Merged LIVE" = Table.NestedJoin(#"Removed Duplicates", {"Path Name"}, LIVE, {"Path Name"}, "LIVE", JoinKind.LeftOuter),
    #"Expanded LIVE" = Table.ExpandTableColumn(#"Merged LIVE", "LIVE", {"Order Stage"}, {"LIVE?"}),
    #"Merged DECOMMISSIONED" = Table.NestedJoin(#"Expanded LIVE", {"Path Name"}, DECOMMISSIONED_COMPLETED, {"Path Name"}, "DECOMMISSIONED_COMPLETED", JoinKind.LeftOuter),
    #"Expanded DECOMMISSIONED_COMPLETED1" = Table.ExpandTableColumn(#"Merged DECOMMISSIONED", "DECOMMISSIONED_COMPLETED", {"Order Stage"}, {"DECOMMISSIONED?"}),
    #"Renamed Columns" = Table.RenameColumns(#"Expanded DECOMMISSIONED_COMPLETED1", {{"Path Status", "Sys.Path Status"}}),
    #"Added Path Status" =
        Table.AddColumn(
            #"Renamed Columns",
            "Path Status",
            each if [Category] = "REPEATOR_MW" and [#"LIVE?"] = "LIVE" and [Installation Status] = "Ready for Installation" then "IN-PROCESS"
                else if [Category] = "REPEATOR_MW" and [#"LIVE?"] = "LIVE" and [Installation Status] = "MW Link Installed" then "LIVE"
                else if [Category] = "REPEATOR_MW" and [#"Order Status"] = "COMPLETED" then [Order Stage]
                else if [Order Status] = "CANCELLED" then "CANCELLED"
                else if [#"LIVE?"] = "LIVE" then "LIVE"
                else if [#"DECOMMISSIONED?"] = "DECOMMISSIONED" then "DECOMMISSIONED"
                else if [Order Type] <> "Visibility" and [Order Status] <> "COMPLETED" and [Installation Status] = "MW Link Installed" and [#"DECOMMISSIONED?"] <> "DECOMMISSIONED" then "LIVE!"
                else [Order Status],
            type text
        ),
    #"Selected Columns" = Table.SelectColumns(
        #"Added Path Status",
        {"Order Date", "PTP Assigned Date", "Order Number", "Path Name", "Bandwidth", "Category", "MW Contractor", "Order Status", "Order Stage", "Order Stage Start Date", "Path Status", "ProjectID", "A District", "FE Property ID", "NE Property ID", "FE Tower Owner", "NE Tower Owner", "Link ID", "In Service", "Decommissioned Date", "Rejected Reason Desc", "NI Number", "WGW ID", "WGW PAN Number", "Repeater Reference", "Domain Name", "Order Type"}
    ),
    #"Sorted Rows" = Table.Sort(#"Selected Columns", {{"PTP Assigned Date", Order.Descending}}),
    #"Removed Duplicates1" = Table.Distinct(#"Sorted Rows", {"Order Number"}),
    #"Filtered Rows" = Table.SelectRows(#"Removed Duplicates1", each ([MW Contractor] <> null))
in
    #"Filtered Rows"
