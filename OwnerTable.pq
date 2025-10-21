let
    Source = Excel.CurrentWorkbook(){[Name="Table1"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Order Stage", type text}, {"Owner", type text}, {"Category", type text}, {"SLA", Int64.Type}, {"EBU Status", type text}, {"Email ", type any}})
in
    #"Changed Type"