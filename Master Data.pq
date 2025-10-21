let
    SafeTable = (value as any, tableName as text) as table =>
        let
            attempt = try value,
            result =
                if attempt[HasError] then
                    let
                        _ = Diagnostics.Trace(TraceLevel.Error, Text.Format("Master Data: failed to load '{0}'. Returning empty table.", {tableName}), attempt[Error])
                    in
                        #table({}, {})
                else if Value.Is(attempt[Value], type table) then
                    attempt[Value]
                else
                    let
                        _ = Diagnostics.Trace(TraceLevel.Error, Text.Format("Master Data: '{0}' is not a table. Returning empty table.", {tableName}))
                    in
                        #table({}, {})
        in
            result,
    SafeNestedJoin = (
        left as table,
        leftKeys as list,
        right as table,
        rightKeys as list,
        newColumn as text
    ) as table =>
        let
            attempt = try Table.NestedJoin(left, leftKeys, right, rightKeys, newColumn, JoinKind.LeftOuter)
        in
            if attempt[HasError] then
                let
                    _ = Diagnostics.Trace(TraceLevel.Error, Text.Format("Master Data: join '{0}' failed. Returning original table.", {newColumn}), attempt[Error])
                in
                    left
            else
                attempt[Value],
    SafeExpandTable = (
        tbl as table,
        column as text,
        columnsToExpand as list,
        newColumnNames as list
    ) as table =>
        let
            attempt = try Table.ExpandTableColumn(tbl, column, columnsToExpand, newColumnNames)
        in
            if attempt[HasError] then
                let
                    _ = Diagnostics.Trace(TraceLevel.Error, Text.Format("Master Data: expand on '{0}' failed. Column removed.", {column}), attempt[Error])
                in
                    Table.RemoveColumns(tbl, {column}, MissingField.Ignore)
            else
                attempt[Value],
    SafeDistinct = (tbl as table, columns as list) as table =>
        let
            attempt = try Table.Distinct(tbl, columns)
        in
            if attempt[HasError] then
                let
                    _ = Diagnostics.Trace(TraceLevel.Error, "Master Data: distinct operation failed.", attempt[Error])
                in
                    tbl
            else
                attempt[Value],
    ToTextOrNull = (value as any) as nullable text => if value = null then null else Text.From(value),
    ToTrimmedText = (value as any) as nullable text =>
        let
            textValue = ToTextOrNull(value),
            trimmed = if textValue = null then null else Text.Trim(textValue)
        in
            if trimmed = "" then null else trimmed,
    SourceColumns = {
        "Order Date",
        "PTP Assigned Date",
        "Order Number",
        "Path Name",
        "Bandwidth",
        "Category",
        "MW Contractor",
        "Order Status",
        "Order Stage",
        "Order Stage Start Date",
        "ProjectID",
        "A District",
        "In Service",
        "Decommissioned Date",
        "Rejected Reason Desc",
        "NI Number",
        "WGW ID",
        "WGW PAN Number",
        "Repeater Reference",
        "Domain Name",
        "Order Type",
        "Link ID"
    },
    ContractorColumns = {
        "Path Name",
        "Path Status",
        "FE Tower Owner",
        "NE Tower Owner",
        "Installation Status",
        "FE Property ID",
        "NE Property ID",
        "Rejection Reason",
        "MW Design Link ID"
    },
    SourceRaw = SafeTable(#"PTP MW Dump", "PTP MW Dump"),
    SourceReduced = Table.SelectColumns(SourceRaw, SourceColumns, MissingField.UseNull),
    RenamedSource = Table.RenameColumns(SourceReduced, {{"Link ID", "XNG Link ID"}, {"Order Status", "XNG Order Status"}}, MissingField.Ignore),
    FilteredSource = Table.SelectRows(
        RenamedSource,
        each
            let
                orderTypeText = Text.Upper(Text.From(Record.FieldOrDefault(_, "Order Type", ""))),
                contractorText = ToTrimmedText(Record.FieldOrDefault(_, "MW Contractor"))
            in
                orderTypeText <> "UNDEFINED" and orderTypeText <> "VISIBILITY" and contractorText <> null
    ),
    ContractorRaw = SafeTable(#"Contractors Master Sheet", "Contractors Master Sheet"),
    ContractorReduced = Table.SelectColumns(ContractorRaw, ContractorColumns, MissingField.UseNull),
    LiveRaw = SafeTable(LIVE, "LIVE"),
    LiveReduced = Table.SelectColumns(LiveRaw, {"Path Name", "Order Stage"}, MissingField.UseNull),
    DecommissionedRaw = SafeTable(DECOMMISSIONED_COMPLETED, "DECOMMISSIONED_COMPLETED"),
    DecommissionedReduced = Table.SelectColumns(DecommissionedRaw, {"Path Name", "Order Stage"}, MissingField.UseNull),
    JoinedContractors = SafeNestedJoin(FilteredSource, {"Path Name"}, ContractorReduced, {"Path Name"}, "ContractorInfo"),
    ExpandedContractors = SafeExpandTable(
        JoinedContractors,
        "ContractorInfo",
        {"Path Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"},
        {"Path Status", "FE Tower Owner", "NE Tower Owner", "Installation Status", "FE Property ID", "NE Property ID", "Rejection Reason", "MW Design Link ID"}
    ),
    AddedOrderStatus = Table.AddColumn(
        ExpandedContractors,
        "Order Status",
        each
            let
                installation = ToTrimmedText(Record.FieldOrDefault(_, "Installation Status")),
                category = ToTrimmedText(Record.FieldOrDefault(_, "Category")),
                xngStatus = ToTrimmedText(Record.FieldOrDefault(_, "XNG Order Status"))
            in
                if installation = "CANCELLED" then "CANCELLED"
                else if category = "REPEATOR_MW" and installation = "Ready for Installation" then "IN-PROCESS"
                else xngStatus,
        type text
    ),
    AddedLinkId = Table.AddColumn(
        AddedOrderStatus,
        "Link ID",
        each
            let
                mwDesign = ToTrimmedText(Record.FieldOrDefault(_, "MW Design Link ID")),
                xngLink = ToTrimmedText(Record.FieldOrDefault(_, "XNG Link ID"))
            in
                if mwDesign <> null then mwDesign else xngLink,
        type text
    ),
    CleanedColumns = Table.RemoveColumns(AddedLinkId, {"XNG Link ID", "MW Design Link ID", "XNG Order Status"}, MissingField.Ignore),
    DistinctPaths = SafeDistinct(CleanedColumns, {"Order Number", "Path Name"}),
    JoinedLive = SafeNestedJoin(DistinctPaths, {"Path Name"}, LiveReduced, {"Path Name"}, "LIVE"),
    ExpandedLive = SafeExpandTable(JoinedLive, "LIVE", {"Order Stage"}, {"LIVE?"}),
    JoinedDecommissioned = SafeNestedJoin(ExpandedLive, {"Path Name"}, DecommissionedReduced, {"Path Name"}, "DECOMMISSIONED"),
    ExpandedDecommissioned = SafeExpandTable(JoinedDecommissioned, "DECOMMISSIONED", {"Order Stage"}, {"DECOMMISSIONED?"}),
    RenamedPathStatus = Table.RenameColumns(ExpandedDecommissioned, {{"Path Status", "Sys.Path Status"}}, MissingField.Ignore),
    AddedPathStatus = Table.AddColumn(
        RenamedPathStatus,
        "Path Status",
        each
            let
                category = ToTrimmedText(Record.FieldOrDefault(_, "Category")),
                liveFlag = ToTrimmedText(Record.FieldOrDefault(_, "LIVE?")),
                orderStatus = ToTrimmedText(Record.FieldOrDefault(_, "Order Status")),
                installStatus = ToTrimmedText(Record.FieldOrDefault(_, "Installation Status")),
                orderStage = ToTrimmedText(Record.FieldOrDefault(_, "Order Stage")),
                decommissionedFlag = ToTrimmedText(Record.FieldOrDefault(_, "DECOMMISSIONED?")),
                orderTypeRaw = ToTrimmedText(Record.FieldOrDefault(_, "Order Type")),
                orderType = if orderTypeRaw = null then "" else orderTypeRaw
            in
                if category = "REPEATOR_MW" and liveFlag = "LIVE" and installStatus = "Ready for Installation" then "IN-PROCESS"
                else if category = "REPEATOR_MW" and liveFlag = "LIVE" and installStatus = "MW Link Installed" then "LIVE"
                else if category = "REPEATOR_MW" and orderStatus = "COMPLETED" then orderStage
                else if orderStatus = "CANCELLED" then "CANCELLED"
                else if liveFlag = "LIVE" then "LIVE"
                else if decommissionedFlag = "DECOMMISSIONED" then "DECOMMISSIONED"
                else if orderType <> "Visibility" and orderStatus <> "COMPLETED" and installStatus = "MW Link Installed" and decommissionedFlag <> "DECOMMISSIONED" then "LIVE!"
                else orderStatus,
        type text
    ),
    FinalColumns = {
        "Order Date",
        "PTP Assigned Date",
        "Order Number",
        "Path Name",
        "Bandwidth",
        "Category",
        "MW Contractor",
        "Order Status",
        "Order Stage",
        "Order Stage Start Date",
        "Path Status",
        "ProjectID",
        "A District",
        "FE Property ID",
        "NE Property ID",
        "FE Tower Owner",
        "NE Tower Owner",
        "Link ID",
        "In Service",
        "Decommissioned Date",
        "Rejected Reason Desc",
        "NI Number",
        "WGW ID",
        "WGW PAN Number",
        "Repeater Reference",
        "Domain Name",
        "Order Type"
    },
    SelectedColumns = Table.SelectColumns(AddedPathStatus, FinalColumns, MissingField.UseNull),
    SortedRows = Table.Sort(SelectedColumns, {{"PTP Assigned Date", Order.Descending}}),
    DeduplicatedOrders = SafeDistinct(SortedRows, {"Order Number"}),
    FilteredContractor = Table.SelectRows(
        DeduplicatedOrders,
        each ToTrimmedText(Record.FieldOrDefault(_, "MW Contractor")) <> null
    )
in
    FilteredContractor
