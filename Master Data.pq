let
    CurrentDate = Date.From(DateTime.LocalNow()),
    Source = Table.NestedJoin(#"PTP MW Dump", {"Path Name"}, #"Contractors Master Sheet", {"Path Name"}, "Contractors Master Sheet", JoinKind.LeftOuter),
    #"Renamed XNG Link ID" = Table.RenameColumns(Source, {{"Link ID", "XNG Link ID"}, {"Order Status", "XNG Order Status"}}),
    #"Expanded Contractors Master Sheet" =
        Table.ExpandTableColumn(
            #"Renamed XNG Link ID",
            "Contractors Master Sheet",
            {"Path Status", "Current Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"},
            {"Path Status", "Current Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"}
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
    #"Merged EBU Classification" = Table.NestedJoin(#"Removed No need Link ID", {"ProjectID"}, #"EBU Classification", {"EBU Projects"}, "EBU Classification", JoinKind.LeftOuter),
    #"Converted EBU Classification" = Table.TransformColumns(#"Merged EBU Classification", {{"EBU Classification", each if Table.IsEmpty(_) then "Normal" else "Project", type text}}),
    #"Merged Trends Data" = Table.NestedJoin(#"Converted EBU Classification", {"Link ID"}, TrendsData, {"LinkID"}, "TrendsData", JoinKind.LeftOuter),
    #"Expanded TrendsData" = Table.ExpandTableColumn(#"Merged Trends Data", "TrendsData", {"Band", "Lat_A", "Lng_A", "Lat_B", "Lng_B", "IsActive"}, {"Frequency Band", "NE Latitude", "NE Longitude", "FE Latitude", "FE Lontidue", "IsActive"}),
    #"Added MRS Contractor" = Table.AddColumn(#"Expanded TrendsData", "MRS Contractor", each if [MRS Router] = "YES" then "YES" else "NO", type text),
    #"Rejected Reason?" = Table.AddColumn(#"Added MRS Contractor", "Rejected Reason", each if [Order Type] = "New" or [Order Type] = "Repeater" then [Rejection Reason] else [Rejected Reason Desc], type text),
    #"Merged OwnerTable" = Table.NestedJoin(#"Rejected Reason?", {"Order Stage"}, OwnerTable, {"Order Stage"}, "OwnerTable", JoinKind.LeftOuter),
    #"Expanded OwnerTable" = Table.ExpandTableColumn(#"Merged OwnerTable", "OwnerTable", {"Owner", "SLA", "EBU Status"}, {"Owner", "SLA.1", "EBU Status"}),
    #"Inserted Year" = Table.AddColumn(#"Expanded OwnerTable", "Year", each Date.Year([Order Stage Start Date]), Int64.Type),
    #"Inserted Week of Year" = Table.AddColumn(#"Inserted Year", "Week", each Date.WeekOfYear([Order Stage Start Date]), Int64.Type),
    #"Inserted SLA Subtraction" = Table.AddColumn(
        #"Inserted Week of Year",
        "SLA",
        each if [Order Status] = "IN-PROCESS" or [Order Status] = "REJECTED"
            then Duration.Days(CurrentDate - [Order Stage Start Date])
            else null,
        Int64.Type
    ),
    #"SLA Check" = Table.AddColumn(#"Inserted SLA Subtraction", "SLA Check", each if [SLA] <> null and [SLA.1] <> null and [SLA] > [SLA.1] then "Exceed SLA" else null, type text),
    #"Merged Region" = Table.NestedJoin(#"SLA Check", {"A District"}, #"District Region", {"A District"}, "District Region", JoinKind.LeftOuter),
    #"Expanded District Region" = Table.ExpandTableColumn(#"Merged Region", "District Region", {"Region"}, {"Region"}),
    #"Filtered Rows1" = Table.SelectRows(#"Expanded District Region", each ([Order Type] <> "Undefined" and [Order Type] <> "Visibility") and ([MW Contractor] <> "")),
    #"Removed Duplicates" = Table.Distinct(#"Filtered Rows1", {"Order Number", "Path Name"}),
    #"Merged Queries" = Table.NestedJoin(#"Removed Duplicates", {"Rejected Reason"}, Rejection_Reasons, {"Rejection Reason"}, "Rejection_Reasons", JoinKind.LeftOuter),
    #"Expanded Rejection_Reasons" = Table.ExpandTableColumn(#"Merged Queries", "Rejection_Reasons", {"Rejected Related"}, {"Rejected Related"}),
    #"Merged LIVE" = Table.NestedJoin(#"Expanded Rejection_Reasons", {"Path Name"}, LIVE, {"Path Name"}, "LIVE", JoinKind.LeftOuter),
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
                else if [Current Status] = "CANCELLED" then "CANCELLED"
                else if [#"LIVE?"] = "LIVE" then "LIVE"
                else if [#"DECOMMISSIONED?"] = "DECOMMISSIONED" then "DECOMMISSIONED"
                else if [Order Type] <> "Visibility" and [Order Status] <> "COMPLETED" and [Installation Status] = "MW Link Installed" and [#"DECOMMISSIONED?"] <> "DECOMMISSIONED" then "LIVE!"
                else [Order Status],
            type text
        ),
    #"Selected Columns" = Table.SelectColumns(
        #"Added Path Status",
        {"Order Date", "PTP Assigned Date", "Order Number", "Path Name", "Customer Name", "Bandwidth", "Category", "MW Contractor", "Order Status", "Order Stage", "Order Stage Start Date", "Path Status", "EBU Classification", "ProjectID", "A District", "FE Property ID", "FE Latitude", "FE Lontidue", "NE Property ID", "NE Latitude", "NE Longitude", "FE Tower Owner", "NE Tower Owner", "Link ID", "Link Capacity", "MRS Contractor", "MRS Router", "In Service", "Decommissioned Date", "Current Status", "Rejected Reason Desc", "IsActive", "Rejected Related", "NI Number", "Frequency Band", "WGW ID", "WGW PAN Number", "Repeater Reference", "Access Type", "Domain Name", "Order Type", "SLA", "Year", "Week", "Owner", "EBU Status", "Region", "SLA Check"}
    ),
    #"Sorted Rows" = Table.Sort(#"Selected Columns", {{"PTP Assigned Date", Order.Descending}}),
    #"Removed Duplicates1" = Table.Distinct(#"Sorted Rows", {"Order Number"}),
    #"Extracted First Characters" = Table.TransformColumns(#"Removed Duplicates1", {{"Customer Name", each Text.Start(_, 0), type text}}),
    #"Extracted First Characters1" = Table.TransformColumns(#"Extracted First Characters", {{"FE Latitude", each Text.Start(Text.From(_, "en-US"), 0), type text}, {"FE Lontidue", each Text.Start(Text.From(_, "en-US"), 0), type text}, {"NE Latitude", each Text.Start(Text.From(_, "en-US"), 0), type text}, {"NE Longitude", each Text.Start(Text.From(_, "en-US"), 0), type text}, {"Link Capacity", each Text.Start(_, 0), type text}, {"MRS Contractor", each Text.Start(_, 0), type text}, {"MRS Router", each Text.Start(_, 0), type text}, {"Access Type", each Text.Start(_, 0), type text}}),
    #"Filtered Rows" = Table.SelectRows(#"Extracted First Characters1", each ([MW Contractor] <> null))
in
    #"Filtered Rows"
