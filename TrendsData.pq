let
    Source = Excel.Workbook(File.Contents("C:\\Users\\PC\\Desktop\\MW PTP Trends Data Set\\trends dump.xlsx"), null, true),
    Sheet1_Sheet = Source{[Item="Sheet1",Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(Sheet1_Sheet, [PromoteAllScalars=true]),
    #"Removed Other Columns" = Table.SelectColumns(#"Promoted Headers",{"LinkID", "SiteA", "SiteB", "FreqBand", "AntB_AntSize", "AntCLa", "AntCLb", "Lat_A", "Lng_A", "Lat_B", "Lng_B", "District", "TD", "TD_AccessPreparedBy", "LinkDesignActiveStatus", "AntA_AntSize"}),
    #"Reordered Columns" = Table.ReorderColumns(#"Removed Other Columns",{"LinkID", "SiteA", "SiteB", "FreqBand", "AntB_AntSize", "AntA_AntSize", "AntCLa", "AntCLb", "Lat_A", "Lng_A", "Lat_B", "Lng_B", "District", "TD", "TD_AccessPreparedBy", "LinkDesignActiveStatus"}),
    #"Rounded Off" = Table.TransformColumns(#"Reordered Columns",{{"AntB_AntSize", each Number.Round(_, 3), type number}, {"AntA_AntSize", each Number.Round(_, 3), type number}}),
    #"Scaled Antenna Sizes" = Table.TransformColumns(#"Rounded Off", {{"AntB_AntSize", each _ * 1000, type number}, {"AntA_AntSize", each _ * 1000, type number}}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Scaled Antenna Sizes",{{"LinkID", type text}}),
    #"Removed Duplicates" = Table.Distinct(#"Changed Type1", {"LinkID"}),
    #"Renamed Columns" = Table.RenameColumns(#"Removed Duplicates",{{"FreqBand", "Band"}, {"LinkDesignActiveStatus", "IsActive"}, {"TD_AccessPreparedBy", "PreparedBy"}})
in
    #"Renamed Columns"
