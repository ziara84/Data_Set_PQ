let
    Source = Excel.CurrentWorkbook(){[Name="Table5"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"EBU Projects", type text}})
in
    #"Changed Type"