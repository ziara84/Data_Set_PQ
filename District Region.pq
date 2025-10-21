let
    Source = Excel.CurrentWorkbook(){[Name="Table2"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"#", Int64.Type}, {"A District", type text}, {"Region", type text}})
in
    #"Changed Type"