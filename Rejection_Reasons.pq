let
    Source = Excel.CurrentWorkbook(){[Name="Rejection_Reasons"]}[Content],
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"No", Int64.Type}, {"Rejection Reason", type text}, {"Rejected Related", type text}, {"Needed?", type text}, {"Resion Code", type text}, {"Responsible", type text}, {"To be Cancelled", type any}})
in
    #"Changed Type"