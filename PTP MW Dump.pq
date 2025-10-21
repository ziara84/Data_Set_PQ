let
    ReplaceColumnValues = (inputTable as table, columnName as text, replacements as list) as table =>
        List.Accumulate(replacements, inputTable, (state, pair) => Table.ReplaceValue(state, pair{0}, pair{1}, Replacer.ReplaceText, {columnName})),
    StatusReplacements = {{"ON-HOLD", "IN-PROCESS"}, {"READY", "IN-PROCESS"}},
    ContractorReplacements = {{"BeitAletisalat", "CTC"}, {"HUAWEI", "Huawei"}},
    DomainReplacements = {{"wbu__domain", "WBU"}, {"ebu__domain", "EBU"}},
    BandwidthReplacements = {{"MBPS_E2E", " Mbps"}, {"MBPS_AAC", " Mbps"}, {"MBPS_WGW", " Mbps"}, {"MBPS_BW", " Mbps"}},
    OrderTypeMap = [I = "New", T = "IP Change", C = "Change", E = "Re-Active", D = "Suspend", O = "Decommission", M = "Migration", F = "Visibility", W = "Change", S = "Migration"],
    Source = Excel.Workbook(File.Contents("C:\\Users\\PC\\Downloads\\EBU - EFO MW PTP (44).xlsx"), null, true),
    #"Expanded Data" = Table.ExpandTableColumn(Source, "Data", {"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8", "Column9", "Column10", "Column11", "Column12", "Column13", "Column14", "Column15", "Column16", "Column17", "Column18", "Column19", "Column20", "Column21", "Column22", "Column23", "Column24", "Column25", "Column26", "Column27", "Column28", "Column29", "Column30", "Column31", "Column32", "Column33", "Column34", "Column35", "Column36", "Column37", "Column38", "Column39", "Column40", "Column41", "Order Date", "PTP Assigned Date", "Order Number", "Path Name", "Customer Name", "Bandwidth", "Category", "MW Contractor", "Order Status", "Order Stage", "Order Stage Start Date", "Path Status", "EFO Project ID", "ProjectID", "A District", "FE Property ID", "FE Latitude", "FE Lontidue", "NE Property ID", "NE Latitude", "NE Longitude", "Radio Equipment Type", "Radio Equipment Vendor", "Link ID", "Link Capacity", "HOP Length", "MRS Router", "In Service", "Decommissioned Date", "Rejected Reason Code", "Rejected Reason Desc", "Vlan ID", "PE Aggregator Name", "NI Number", "Frequency Band", "WGW PAN Number", "Repeater Reference", "WGW ID", "Access Type", "Domain Name", "EFO Project ID Old"}, {"Data.Column1", "Data.Column2", "Data.Column3", "Data.Column4", "Data.Column5", "Data.Column6", "Data.Column7", "Data.Column8", "Data.Column9", "Data.Column10", "Data.Column11", "Data.Column12", "Data.Column13", "Data.Column14", "Data.Column15", "Data.Column16", "Data.Column17", "Data.Column18", "Data.Column19", "Data.Column20", "Data.Column21", "Data.Column22", "Data.Column23", "Data.Column24", "Data.Column25", "Data.Column26", "Data.Column27", "Data.Column28", "Data.Column29", "Data.Column30", "Data.Column31", "Data.Column32", "Data.Column33", "Data.Column34", "Data.Column35", "Data.Column36", "Data.Column37", "Data.Column38", "Data.Column39", "Data.Column40", "Data.Column41", "Data.Order Date", "Data.PTP Assigned Date", "Data.Order Number", "Data.Path Name", "Data.Customer Name", "Data.Bandwidth", "Data.Category", "Data.MW Contractor", "Data.Order Status", "Data.Order Stage", "Data.Order Stage Start Date", "Data.Path Status", "Data.EFO Project ID", "Data.ProjectID", "Data.A District", "Data.FE Property ID", "Data.FE Latitude", "Data.FE Lontidue", "Data.NE Property ID", "Data.NE Latitude", "Data.NE Longitude", "Data.Radio Equipment Type", "Data.Radio Equipment Vendor", "Data.Link ID", "Data.Link Capacity", "Data.HOP Length", "Data.MRS Router", "Data.In Service", "Data.Decommissioned Date", "Data.Rejected Reason Code", "Data.Rejected Reason Desc", "Data.Vlan ID", "Data.PE Aggregator Name", "Data.NI Number", "Data.Frequency Band", "Data.WGW PAN Number", "Data.Repeater Reference", "Data.WGW ID", "Data.Access Type", "Data.Domain Name", "Data.EFO Project ID Old"}),
    #"Promoted Headers" = Table.PromoteHeaders(#"Expanded Data", [PromoteAllScalars = true]),
    #"Renamed Columns" = Table.RenameColumns(#"Promoted Headers", {{"Ptp Assigned Date", "PTP Assigned Date"}, {"Mw Contractor", "MW Contractor"}, {"Projectid", "ProjectID"}, {"Mrs Router", "MRS Router"}, {"Ni Number", "NI Number"}, {"Wgw Pan Number", "WGW PAN Number"}, {"Wgw Id", "WGW ID"}, {"Pe Aggregator Name", "PE Aggregator Name"}, {"Link Id", "Link ID"}}),
    #"Filtered Rows2" = Table.SelectRows(#"Renamed Columns", each ([Order Stage Start Date] <> null)),
    #"Normalized Status" = ReplaceColumnValues(#"Filtered Rows2", "Order Status", StatusReplacements),
    #"Add New Status" = Table.AddColumn(
        #"Normalized Status",
        "New Stats",
        each
            let
                pathStatus = [Path Status],
                stage = [Order Stage],
                orderStatus = [Order Status]
            in
                if pathStatus = "TO BE CANCELLED" then "CANCELLED"
                else if pathStatus = "CANCELLED" then "CANCELLED"
                else if stage = "SALES" then "REJECTED"
                else if stage = "WBU-SALES" then "REJECTED"
                else if orderStatus = "SALES OPERATIONS" then "REJECTED"
                else if stage = "INST. POSTPONED" then "REJECTED"
                else if pathStatus = "LIVE" then "COMPLETED"
                else if pathStatus = "DECOMMISSIONED" then "COMPLETED"
                else if stage = "SALES OPERATIONS" then "REJECTED"
                else if stage = "WBU-DESIGN-N-DIR" then "REJECTED"
                else if stage = "EBU-SO-CANCELATION" then "CANCELLED"
                else orderStatus,
        type text
    ),
    #"Removed Old Status" = Table.RemoveColumns(#"Add New Status", {"Order Status"}),
    #"Renamed New Status" = Table.RenameColumns(#"Removed Old Status", {{"New Stats", "Order Status"}}),
    #"Added Stage" = Table.AddColumn(
        #"Renamed New Status",
        "Update Stage",
        each
            let
                stage = [Order Stage],
                pathStatus = [Path Status]
            in
                if Text.Contains(stage, "MW BACKHAUL TRANSPORT") then "MW BACKHAUL TRANSPORT"
                else if Text.Contains(stage, "WSO") then "WSO BAT"
                else if pathStatus = "CANCELLED" then "CANCELLED"
                else if pathStatus = "LIVE" then "LIVE"
                else if pathStatus = "DECOMMISSIONED" then "DECOMMISSIONED"
                else if pathStatus = "SUSPENDED" then "LIVE"
                else stage,
        type text
    ),
    #"Removed Old Stage" = Table.RemoveColumns(#"Added Stage", {"Order Stage"}),
    #"Renamed New Stage" = Table.RenameColumns(#"Removed Old Stage", {{"Update Stage", "Order Stage"}}),
    #"Added Conditional Column" = Table.AddColumn(
        #"Renamed New Stage",
        "Order Type",
        each
            let
                category = [Category],
                firstCharacter = Text.Upper(Text.Start([Order Number], 1)),
                mappedType = Record.FieldOrDefault(OrderTypeMap, firstCharacter, "Undefined")
            in
                if category = "REPEATOR_MW" then "Repeater" else mappedType,
        type text
    ),
    #"Removed Other Columns" = Table.SelectColumns(#"Added Conditional Column", {"Order Date", "PTP Assigned Date", "Order Number", "Path Name", "Customer Name", "Bandwidth", "Category", "MW Contractor", "Order Stage", "Order Stage Start Date", "ProjectID", "A District", "MRS Router", "In Service", "Decommissioned Date", "Rejected Reason Desc", "NI Number", "WGW PAN Number", "Repeater Reference", "WGW ID", "Access Type", "Domain Name", "Order Status", "Order Type", "PE Aggregator Name", "Link Capacity", "Link ID"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Removed Other Columns", {{"Order Date", type date}, {"PTP Assigned Date", type date}, {"Order Number", type text}, {"Path Name", type text}, {"Customer Name", type text}, {"Bandwidth", type text}, {"Category", type text}, {"MW Contractor", type text}, {"Order Stage", type text}, {"Order Stage Start Date", type date}, {"ProjectID", type text}, {"A District", type text}, {"MRS Router", type text}, {"In Service", type date}, {"Decommissioned Date", type date}, {"Rejected Reason Desc", type text}, {"NI Number", type text}, {"WGW PAN Number", type text}, {"Repeater Reference", type text}, {"WGW ID", type text}, {"Access Type", type text}, {"Domain Name", type text}, {"Order Status", type text}, {"Order Type", type text}}),
    #"Replaced MW Contractor" = ReplaceColumnValues(#"Changed Type", "MW Contractor", ContractorReplacements),
    #"Replaced Domain Name" = ReplaceColumnValues(#"Replaced MW Contractor", "Domain Name", DomainReplacements),
    #"Filtered Rows" = Table.SelectRows(#"Replaced Domain Name", each [Order Type] <> "Undefined" or [MW Contractor] = ""),
    #"Replaced Bandwidth" = ReplaceColumnValues(#"Filtered Rows", "Bandwidth", BandwidthReplacements),
    #"Removed Duplicates" = Table.Distinct(#"Replaced Bandwidth", {"Path Name", "Order Number", "Order Status"})
in
    #"Removed Duplicates"
