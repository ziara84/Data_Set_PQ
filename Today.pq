let
    Source = Excel.CurrentWorkbook(){[Name="Table6"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Today", type date}})
in
    #"Changed Type"