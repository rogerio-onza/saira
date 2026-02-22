# Package ‘CoordinateCleaner’

July 21, 2025

Type Package

Title Automated Cleaning of Occurrence Records from Biological Collections

Version 3.0.1

Description Automated flagging of common spatial and temporal errors in biological and paleontological collection data, for the use in conservation, ecology and paleontology. Includes automated tests to easily flag (and exclude) records assigned to country or province centroid, the open ocean, the headquarters of the Global Biodiversity Information Facility, urban areas or the location of biodiversity institutions (museums, zoos, botanical gardens, universities). Furthermore identifies per species outlier coordinates, zero coordinates, identical latitude/longitude and invalid coordinates. Also implements an algorithm to identify data sets with a significant proportion of rounded coordinates. Especially suited for large data sets. The reference for the methodology is: Zizka et al. (2019) [doi:10.1111/2041-210X.13152](doi:10.1111/2041-210X.13152).

License GPL-3

URL [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/)

BugReports [https://github.com/ropensci/CoordinateCleaner/issues](https://github.com/ropensci/CoordinateCleaner/issues)

Depends $\ R \ ( > = 3 . 5 . 0 )$

Imports dplyr, geosphere, ggplot2, graphics, grDevices, methods, rgbif, rnaturalearth $( > = 0 . 3 . 2 )$ , stats, terra, tidyselect, utils

Suggests countrycode, covr, knitr, magrittr, maps, rmarkdown, rnaturalearthdata, sf, testthat, viridis

VignetteBuilder knitr Encoding UTF-8 Language en-gb LazyData true RoxygenNote 7.2.3

# SystemRequirements GDAL $( > = 2 . 0 . 1 $

# NeedsCompilation no

Author Alexander Zizka \[aut, cre\], Daniele Silvestro \[ctb\], Tobias Andermann \[ctb\], Josue Azevedo \[ctb\], Camila Duarte Ritter \[ctb\], Daniel Edler \[ctb\], Harith Farooq \[ctb\], Andrei Herdean \[ctb\], Maria Ariza \[ctb\], Ruud Scharn \[ctb\], Sten Svanteson \[ctb\], Niklas Wengstrom \[ctb\], Vera Zizka \[ctb\], Alexandre Antonelli \[ctb\], Bruno Vilela \[ctb\] (Bruno updated the package to remove dependencies on sp, raster, rgdal, maptools, and rgeos packages), Irene Steves \[rev\] (Irene reviewed the package for ropensci, see [https://github.com/ropensci/onboarding/issues/210](https://github.com/ropensci/onboarding/issues/210)), Francisco Rodriguez-Sanchez \[rev\] (Francisco reviewed the package for ropensci, see [https://github.com/ropensci/onboarding/issues/210](https://github.com/ropensci/onboarding/issues/210))

Maintainer Alexander Zizka [zizka.alexander@gmail.com](mailto:zizka.alexander@gmail.com)

Repository CRAN

Date/Publication 2023-10-24 21:20:02 UTC

# Contents

aohi . . 3

buffland 4

buffsea . . 4

cc\_aohi 5

cc\_cap . 6

cc\_cen . 8

cc\_coun 9

cc\_dupl 11

cc\_equ . 12

cc\_gbif 14

cc\_inst . 15

cc\_iucn 17

cc\_outl . 18

cc\_sea . 21

cc\_urb . 2224

cc\_val .

cc\_zero 25

cd\_ddmm 26

cd\_round 28

cf\_age . . 30

cf\_equal . 32

cf\_outl . 33

cf\_range . 35

clean\_coordinates . 37

clean\_dataset 41

clean\_fossils . 44

countryref . 47

institutions . 48

is.spatialvalid 49

pbdb\_example . 49

plot.spatialvalid 50

write\_pyrate . 51

# Index

aohi

# Description

A data frame with information on Artificial Hotspot Occurrence Inventory (AHOI) as available in Park et al 2022. For more details see reference.

# Source

[https://onlinelibrary.wiley.com/doi/10.1111/jbi.14543](https://onlinelibrary.wiley.com/doi/10.1111/jbi.14543)

# References

Park, D. S., Xie, Y., Thammavong, H. T., Tulaiha, R., & Feng, X. (2023). Artificial Hotspot Occurrence Inventory (AHOI). Journal of Biogeography, 50, 441–449. doi:10.1111/jbi.14543

# Examples

data("aohi")

# Description

A SpatVector with global coastlines, with a 1 degree buffer to extent coastlines as alternative reference for cc\_sea. Can be useful to identify species in the sea, without flagging records in mangroves, marshes, etc.

# Source

[https://www.naturalearthdata.com/downloads/10m-physical-vectors/](https://www.naturalearthdata.com/downloads/10m-physical-vectors/)

# Examples

data("buffland")

buffsea

# Description

A SpatVector with global coastlines, with a -1 degree buffer to extent coastlines as alternative reference for cc\_sea. Can be useful to identify marine species on land without flagging records in estuaries, etc.

# Source

[https://www.naturalearthdata.com/downloads/10m-physical-vectors/](https://www.naturalearthdata.com/downloads/10m-physical-vectors/)

# Examples

data("buffsea")

# Description

Removes or flags records within Artificial Hotspot Occurrence Inventory. Poorly geo-referenced occurrence records in biological databases are often erroneously geo-referenced to highly recurring coordinates that were assessed by Park et al 2022. See the reference for more details.

# Usage

cc\_aohi( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", taxa $=$ c("Aves", "Insecta", "Mammalia", "Plantae"), buffer $= 1 0 0 0 0$ , geod $=$ TRUE, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | character string. The column with the species identity. Only required if verify = TRUE. |
| taxa | Artificial Hotspot Occurrence Inventory (AHOI) were created based on four dif- ferent taxa, birds, insecta, mammalia, and plantae. Users can choose to keep all, or any specific taxa subset to define the AHOI locations. Default is to keep all: c("Aves", "Insecta", "Mammalia", "Plantae"). |
| buffer | The buffer around each capital coordinate (the centre of the city), where records should be flagged as problematic. Units depend on geod. Default = 10 kilome- tres. |
| geod | logical. If TRUE the radius around each capital is calculated based on a sphere, buffer is in meters and independent of latitude. If FALSE the radius is calculated assuming planar coordinates and varies slightly with latitude. Default = TRUE. See https://seethedatablog.wordpress.com/ for detail and credits. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# References

Park, D. S., Xie, Y., Thammavong, H. T., Tulaiha, R., & Feng, X. (2023). Artificial Hotspot Occurrence Inventory (AHOI). Journal of Biogeography, 50, 441–449. doi:10.1111/jbi.14543

# See Also

Other Coordinates: cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ c(runif(99, -180, 180), -47.92), decimalLatitude $=$ c(runif(99, -90,90), -15.78))

cc\_aohi(x)

Identify Coordinates in Vicinity of Country Capitals.

# Description

Removes or flags records within a certain radius around country capitals. Poorly geo-referenced occurrence records in biological databases are often erroneously geo-referenced to capitals.

# Usage

cc\_cap( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", buffer $= 1 0 0 0 0$ , geod $=$ TRUE, ref $=$ NULL, verify $=$ FALSE, value $\ l = \ l ^ { \\prime \\prime } { \\mathsf { c l e a n } } ^ { \\prime \\prime }$ , verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | character string. The column with the species identity. Only required if verify = TRUE. |
| buffer | The buffer around each capital coordinate (the centre of the city), where records should be flagged as problematic. Units depend on geod. Default = 10 kilome- tres. |
| geod | logical. If TRUE the radius around each capital is calculated based on a sphere, buffer is in meters and independent of latitude. If FALSE the radius is calculated assuming planar coordinates and varies slightly with latitude. Default = TRUE. See https://seethedatablog.wordpress.com/ for detail and credits. |
| ref | SpatVector (geometry: polygons). Providing the geographic gazetteer. Can be any SpatVector (geometry: polygons), but the structure must be identical to countryref. Default = countryref. |
| verify | logical. If TRUE records are only flagged if they are the only record in a given species flagged close to a given reference. If FALSE, the distance is the only criterion |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

## Not run:

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ c(runif(99, -180, 180), -47.882778), decimalLatitude $=$ c(runif(99, -90, 90), -15.793889))

# Description

Removes or flags records within a radius around the geographic centroids of political countries and provinces. Poorly geo-referenced occurrence records in biological databases are often erroneously geo-referenced to centroids.

# Usage

cc\_cen( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", buffer $= ~ 1 0 0 0$ , geod $=$ TRUE, test $=$ "both", ref $=$ NULL, verify $=$ FALSE, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | character string. The column with the species identity. Only required if verify = TRUE. |
| buffer | numerical. The buffer around each province or country centroid, where records should be flagged as problematic. Units depend on geod. Default = 1 kilometre. |
| geod | logical. If TRUE the radius around each capital is calculated based on a sphere, buffer is in meters and independent of latitude. If FALSE the radius is calculated assuming planar coordinates and varies slightly with latitude. Default = TRUE. See https://seethedatablog.wordpress.com/ for detail and credits. |

test a character string. Specifying the details of the test. One of c(“both”, “country”, “provinces”). If both tests for country and province centroids.

ref SpatVector (geometry: polygons). Providing the geographic gazetteer. Can be any SpatVector (geometry: polygons), but the structure must be identical to countryref. Default $=$ countryref.

verify logical. If TRUE records are only flagged if they are the only record in a given species flagged close to a given reference. If FALSE, the distance is the only criterion

value character string. Defining the output value. See value.

verbose logical. If TRUE reports the name of the test and the number of records flagged.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ c(runif(99, -180, 180), -47.92), decimalLatitude $=$ c(runif(99, -90,90), -15.78))

cc\_cen(x, geod $=$ FALSE)

## Not run: cc\_inst(x, value $=$ "flagged", buffer $=$ 50000) \#geod = T

## End(Not run)

cc\_coun

# Description

Removes or flags mismatches between geographic coordinates and additional country information (usually this information is reliably reported with specimens). Such a mismatch can occur for example, if latitude and longitude are switched.

# Usage

cc\_coun( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", iso3 $=$ "countrycode", value $=$ "clean", ref $=$ NULL, ref\_c $\\mathrm { ~ \ s l ~ } = \\mathrm { ~ \\Omega ~ } ^ { \\prime \\prime } \\mathrm { i } s \\mathrm { \ o ~ } \\mathrm { \ - } \\mathrm { \ - \ - } \\mathrm { \ - \ - } \\mathrm { \ - \ - } \\mathrm { \ - \ }$ 3", verbose $=$ TRUE, buffer $=$ NULL

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| iso3 | a character string. The column with the country assignment of each record in three letter ISO code. Default = "countrycode". |
| value | character string. Defining the output value. See value. |
| ref | SpatVector (geometry: polygons). Providing the geographic gazetteer. Can be any SpatVector (geometry: polygons), but the structure must be identical to rnaturalearth::ne\_countries(scale = "medium",returnclass = "sf").De- |
| ref\_col | fault=rnaturalearth: :ne\_countries(scale = "medium", returnclass = "sf") the column name in the reference dataset, containing the relevant ISO codes for matching. Default is to "iso\_a3\_eh" which refers to the ISO-3 codes in the reference dataset. See notes. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |
| buffer | numeric. Units are in meters. If provided, a buffer is created around each coun- try polygon. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

The ref\_col argument allows to adapt the function to the structure of alternative reference datasets. For instance, for rnaturalearth::ne\_countries(scale $=$ "small"), the default will fail, but ref\_col $=$ "iso\_a3" will work.

With the default reference, records are flagged if they fall outside the terrestrial territory of countries, hence records in territorial waters might be flagged. See [https://ropensci.github.io/](https://ropensci.github.io/) CoordinateCleaner/ for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

## Not run:

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(100, -20, 30), decimalLatitude $=$ runif(100, 35,60), countrycode $=$ "RUS")

cc\_coun(x, value $=$ "flagged")#non-terrestrial records are flagged as wrong.

## End(Not run)

# Description

Removes or flags duplicated records based on species name and coordinates, as well as user-defined additional columns. True (specimen) duplicates or duplicates from the same species can make up the bulk of records in a biological collection database, but are undesirable for many analyses. Both can be flagged with this function, the former given enough additional information.

# Usage

cc\_dupl( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", additions $=$ NULL, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- |
| lat | malLongitude". character string. The column with the latitude coordinates. Default = "decimal- |
| species | Latitude". a character string. The column with the species name. Default = "species". |
| additions | a vector of character strings. Additional columns to be included in the test for |
| value | duplication. For example as below, collector name and collector number. |
| verbose | character string. Defining the output value. See value. logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ sample $\\times = 0 : 1 0$ , size $= ~ 1 0 0$ , replace $=$ TRUE), decimalLatitude $=$ sample( $\\times = 0 : 1 0$ , size $=$ 100, replace $=$ TRUE), collector $=$ "Bonpl", collector.number $=$ c(1001, 354), collection $=$ rep(c("K", "WAG","FR", "P", "S"), 20))

cc\_dupl(x, value $=$ "flagged") cc\_dupl(x, additions $=$ c("collector", "collector.number"))

# Description

Removes or flags records with equal latitude and longitude coordinates, either exact or absolute.

Equal coordinates can often indicate data entry errors.

cc\_equ( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", test $=$ "absolute", value $=$ "clean", verbose $=$ TRUE

)

# Arguments

x data.frame. Containing geographical coordinates and species names.

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

test character string. Defines if coordinates are compared exactly (“identical”) or on the absolute scale (i.e. $- 1 = 1$ , “absolute”). Default is to “absolute”.

value character string. Defining the output value. See value.

verbose logical. If TRUE reports the name of the test and the number of records flagged.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

x <- data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(100, -180, 180), decimalLatitude $=$ runif(100, -90,90))

cc\_equ(x) cc\_equ(x, value $=$ "flagged")

# Description

Removes or flags records within 0.5 degree radius around the GBIF headquarters in Copenhagen, DK.

# Usage

cc\_gbif( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", buffer $= ~ 1 0 0 0$ , geod $=$ TRUE, verify $=$ FALSE, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | character string. The column with the species identity. Only required if verify = TRUE. |
| buffer | numerical. The buffer around the GBIF headquarters, where records should be flagged as problematic. Units depend on geod. Default = 100 m. |
| geod | logical. If TRUE the radius is calculated based on a sphere, buffer is in meters. If FALSE the radius is calculated in degrees. Default = T. |
| verify | logical. If TRUE records are only flagged if they are the only record in a given species flagged close to a given reference. If FALSE, the distance is the only criterion |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Details

Not recommended if working with records from Denmark or the Copenhagen area.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $\ = \\because \\mathsf { A } ^ { \\prime \\prime }$ , decimalLongitude $=$ c(12.58, 12.58), decimalLatitude $=$ c(55.67, 30.00))

cc\_gbif(x) cc\_gbif(x, value $=$ "flagged")

cc\_inst

# Description

Removes or flags records assigned to the location of zoos, botanical gardens, herbaria, universities and museums, based on a global database of ${ \\sim } 1 0 { , } 0 0 0$ such biodiversity institutions. Coordinates from these locations can be related to data-entry errors, false automated geo-reference or individuals in captivity/horticulture.

# Usage

cc\_inst( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", buffer $= ~ 1 0 0$ , geod $=$ FALSE, ref $=$ NULL, verify $=$ FALSE, verify\_mltpl $= ~ 1 0$ , value $\ l = \ l ^ { \\prime \\prime } { \\mathsf { c l e a n } } ^ { \\prime \\prime }$ , verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | character string. The column with the species identity. Only required if verify = TRUE. |
| buffer | numerical. The buffer around each institution, where records should be flagged as problematic, in decimal degrees. Default = 100m. |
| geod | logical. If TRUE the radius around each capital is calculated based on a sphere, buffer is in meters and independent of latitude. If FALSE the radius is calculated assuming planar coordinates and varies slightly with latitude. Default = TRUE. See https://seethedatablog.wordpress.com/ for detail and credits. |
| ref | SpatVector (geometry: polygons). Providing the geographic gazetteer. Can be any SpatVector (geometry: polygons), but the structure must be identical to institutions. Default= institutions |
| verify | logical. If TRUE, records close to institutions are only flagged, if there are no other records of the same species in the greater vicinity (a radius of buffer \* verify\_mltpl). |
| verify\_mltpl | numerical. indicates the factor by which the radius for verify exceeds the radius of the initial test. Default = 10, which might be suitable if geod is TRUE, but might be too large otherwise. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Details

Note: the buffer radius is in degrees, thus will differ slightly between different latitudes.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ c(runif(99, -180, 180), 37.577800), decimalLatitude $=$ c(runif(99, -90,90), 55.710800))

#large buffer for demonstration, using geod $=$ FALSE for shorter runtime cc\_inst(x, value $=$ "flagged", buffer $= ~ 1 0$ , geod $=$ FALSE)

## Not run: \#' cc\_inst(x, value $=$ "flagged", buffer $=$ 50000) \#geod = T

## End(Not run)

cc\_iucn

# Description

Removes or flags records outside of the provided natural range polygon, on a per species basis. Expects one entry per species. See the example or [https://www.iucnredlist.org/resources/](https://www.iucnredlist.org/resources/) spatial-data-download for the required polygon structure.

# Usage

cc\_iucn( x, range, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", buffer $= ~ 0$ , value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| range | a SpatVector of natural ranges for species in x. Must contain a column named as indicated by species. See details. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | a character string. The column with the species name. Default = "species". |
| buffer | numerical. The buffer around each species' range, from where records should be flagged as problematic, in meters. Default = 0. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Details

Download natural range maps in suitable format for amphibians, birds, mammals and reptiles from [https://www.iucnredlist.org/resources/spatial-data-download](https://www.iucnredlist.org/resources/spatial-data-download). Note: the buffer radius is in degrees, thus will differ slightly between different latitudes.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

library(terra)

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ c("A", "B"), decimalLongitude $=$ runif(100, -170, 170), decimalLatitude $=$ runif(100, -80,80))

range\_species\_A $< -$ cbind(c(-45,-45,-60,-60,-45), c(-10,-25,-25,-10,-10))

rangeA $< -$ terra::vect(range\_species\_A, "polygons")

range\_species\_B $< -$ cbind(c(15,15,32,32,15), c(10,-10,-10,10,10))

rangeB $< -$ terra::vect(range\_species\_B, "polygons")

range $< -$ terra::vect(list(rangeA, rangeB))

range$binomial $< -$ c("A", "B")

cc\_iucn( $\\mathbf { \\nabla } \\cdot \\mathbf { x } = \\mathbf { \\nabla } \\times \\mathbf { \\nabla }$ , range $=$ range, buffer $= \ 0 \\mathrm { \\cdot }$ )

cc\_outl

# Description

Removes out or flags records that are outliers in geographic space according to the method defined via the method argument. Geographic outliers often represent erroneous coordinates, for example due to data entry errors, imprecise geo-references, individuals in horticulture/captivity.

# Usage

cc\_outl( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", method $=$ "quantile", mltpl $= ~ 5$ , tdi $= \ 1 0 0 0$ , value $=$ "clean", sampling\_thresh $= ~ 0$ , verbose $=$ TRUE, min\_occs $= ~ 7$ , thinning $=$ FALSE, thinning\_res $= \ 0 . 5$

)

# Arguments

x data.frame. Containing geographical coordinates and species names.

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

species character string. The column with the species name. Default $=$ “species”.

method character string. Defining the method for outlier selection. See details. One of “distance”, “quantile”, “mad”. Default $=$ “quantile”.

mltpl numeric. The multiplier of the interquartile range (method $= =$ 'quantile') or median absolute deviation (method $= =$ 'mad')to identify outliers. See details. Default $= 5$ .

tdi numeric. The minimum absolute distance (method $= =$ 'distance') of a record to all other records of a species to be identified as outlier, in $\\mathrm { k m }$ . See details. Default $= 1 0 0 0$ .

value character string. Defining the output value. See value.

sampling\_thresh numeric. Cut off threshold for the sampling correction. Indicates the quantile of sampling in which outliers should be ignored. For instance, if sampling\_thresh $= = 0 . 2 5$ , records in the 25 (no sampling correction).

verbose logical. If TRUE reports the name of the test and the number of records flagged.

min\_occs Minimum number of geographically unique datapoints needed for a species to be tested. This is necessary for reliable outlier estimation. Species with fewer than min\_occs records will not be tested and the output value will be ’TRUE’. Default is to 7. If method $= =$ 'distance', consider a lower threshold.

thinning forces a raster approximation for the distance calculation. This is routinely used for species with more than 10,000 records for computational reasons, but can

be enforced for smaller datasets, which is recommended when sampling is very uneven.

thinning\_res

The resolution for the spatial thinning in decimal degrees. Default $= 0 . 5$

# Details

The method for outlier identification depends on the method argument. If “quantile”: a boxplot method is used and records are flagged as outliers if their mean distance to all other records of the same species is larger than mltpl \* the interquartile range of the mean distance of all records of this species. If “mad”: the median absolute deviation is used. In this case a record is flagged as outlier, if the mean distance to all other records of the same species is larger than the median of the mean distance of all points plus/minus the mad of the mean distances of all records of the species $\\ast \_ { \\mathrm { \ m l t p l } }$ . If “distance”: records are flagged as outliers, if the minimum distance to the next record of the species is $>$ tdi. For species with records from $> 1 0 0 0 0$ unique locations a random sample of 1000 records is used for the distance matrix calculation. The test skips species with fewer than min\_occs, geographically unique records.

The likelihood of occurrence records being erroneous outliers is linked to the sampling effort in any given location. To account for this, the sampling\_cor option fetches the number of occurrence records available from [www.gbif.org](http://www.gbif.org/), per country as a proxy of sampling effort. The outlier test (the mean distance) for each records is than weighted by the log transformed number of records per square kilometre in this country. See for [https://besjournals.onlinelibrary.wiley.com/](https://besjournals.onlinelibrary.wiley.com/) doi/full/10.1111/2041-210X.13152 an example and further explanation of the outlier test.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_sea(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

x <- data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(100, -180, 180), decimalLatitude $=$ runif(100, -90,90))

cc\_outl(x) cc\_outl(x, method $=$ "quantile", value $=$ "flagged") cc\_outl(x, method $=$ "distance", value $=$ "flagged", tdi $= 1 0 0 0 0 )$ cc\_outl(x, method $=$ "distance", value $=$ "flagged", tdi $=$ 1000)

# Description

Removes or flags coordinates outside the reference landmass. Can be used to restrict datasets to terrestrial taxa, or exclude records from the open ocean, when depending on the reference (see details). Often records of terrestrial taxa can be found in the open ocean, mostly due to switched latitude and longitude.

# Usage

cc\_sea( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", ref $=$ NULL, scale $= ~ 1 1 0$ , value $=$ "clean", speedup $=$ TRUE, verbose $=$ TRUE, buffer $=$ NULL

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| ref | SpatVector (geometry: polygons). Providing the geographic gazetteer. Can be any SpatVector (geometry: polygons), but the structure must be identical to rnaturalearth::ne\_download(scale = 110, type = 'land', category = 'physical', returnclass = 'sf'). Default = rnaturalearth::ne\_download(scale = 110, type = 'land', category = 'physical', returnclass = 'sf'). |
| scale | the scale of the default reference, as downloaded from natural earth. Must be one of 10, 50, 110. Higher numbers equal higher detail. Default = 110. |
| value | character string. Defining the output value. See value. |
| speedup | logical. Using heuristic to speed up the analysis for large data sets with many records per location. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |
| buffer | numeric. Units are in meters. If provided, a buffer is created around the sea polygon, or ref provided. |

# Details

In some cases flagging records close of the coastline is not recommendable, because of the low precision of the reference dataset, minor GPS imprecision or because a dataset might include coast or marshland species. If you only want to flag records in the open ocean, consider using a buffered landmass reference, e.g.: buffland.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_urb(), cc\_val(), cc\_zero()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(10, -30, 30), decimalLatitude $=$ runif(10, -30, 30))

cc\_sea(x, value $=$ "flagged")

cc\_urb

# Description

Removes or flags records from inside urban areas, based on a geographic gazetteer. Often records from large databases span substantial time periods (centuries) and old records might represent habitats which today are replaced by city area.

# Usage

cc\_urb( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", ref $=$ NULL, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| ref | a SpatVector. Providing the geographic gazetteer with the urban areas. See details. By default rnaturalearth::ne\_download(scale = 'medium', type = 'ur- ban\_areas', returnclass = "sf"). Can be any SpatVector, but the structure must |
| value | be identical to rnaturalearth: :ne\_download(). character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_val(), cc\_zero()

# Examples

## Not run:

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(100, -180, 180), decimalLatitude $=$ runif(100, -90,90))

cc\_urb(x)

cc\_urb(x, value $=$ "flagged")

## End(Not run)

# Description

Removes or flags non-numeric and not available coordinates as well as lat ${ \\tt > } 9 0 $ , lat $< - 9 0$ , lon $> 1 8 0$ and lon $< - 1 8 0$ are flagged.

# Usage

cc\_val( $\\mathsf { x }$ , lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", value $=$ "clean", verbose $=$ TRUE

)

# Arguments

x data.frame. Containing geographical coordinates and species names.

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

value character string. Defining the output value. See value.

verbose logical. If TRUE reports the name of the test and the number of records flagged.

# Details

This test is obligatory before running any further tests of CoordinateCleaner, as additional tests only run with valid coordinates.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_zero()

# Examples

x <- data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ c(runif(106, -180, 180), NA, "13W33'", "67,09", 305), decimalLatitude $=$ runif(110, -90,90))

cc\_val(x) cc\_val(x, value $=$ "flagged")

Identify Zero Coordinates

# Description

Removes or flags records with either zero longitude or latitude and a radius around the point at zero longitude and zero latitude. These problems are often due to erroneous data-entry or georeferencing and can lead to typical patterns of high diversity around the equator.

# Usage

cc\_zero( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", buffer $= \ 0 . 5$ , value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| buffer | numerical. The buffer around the 0/0 point, where records should be flagged as problematic, in decimal degrees. Default = 0.5. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Coordinates: cc\_aohi(), cc\_cap(), cc\_cen(), cc\_coun(), cc\_dupl(), cc\_equ(), cc\_gbif(), cc\_inst(), cc\_iucn(), cc\_outl(), cc\_sea(), cc\_urb(), cc\_val()

# Examples

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $\ = \\because \\mathsf { A } ^ { \\prime \\prime }$ , decimalLongitude $= \\mathsf { c } ( \\theta , 3 4 . 8 4 , \ \\theta , \ 3 3 . 9 8 ) .$ , decimalLatitude $=$ c(23.08, 0, 0, 15.98))

cc\_zero(x) cc\_zero(x, value $=$ "flagged")

cd\_ddmm

# Description

This test flags datasets where a significant fraction of records has been subject to a common degree minute to decimal degree conversion error, where the degree sign is recognized as decimal delimiter.

# Usage

cd\_ddmm( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", ds $=$ "dataset", pvalue $= ~ 0 . 0 2 5$ , diff $= ~ 1$ , mat\_size $= \ 1 0 0 0$ , min\_span $\ c = ~ 2$ , value $=$ "clean", verbose $=$ TRUE, diagnostic $=$ FALSE

)

# Arguments

x data.frame. Containing geographical coordinates and species names. lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

|     |     |
| --- | --- |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| ds | a character string. The column with the dataset of each record. In case x should be treated as a single dataset, identical for all records. Default = "dataset". |
| pvalue | numeric. The p-value for the one-sided t-test to flag the test as passed or not. Both ddmm.pvalue and diff must be met. Default = 0.025. |
| diff | numeric. The threshold difference for the ddmm test. Indicates by which frac- tion the records with decimals below 0.6 must outnumber the records with dec- imals above 0.6. Default = 1 |
| mat\_size | numeric. The size of the matrix for the binomial test. Must be changed in decimals (e.g. 100, 1000, 10000). Adapt to dataset size, generally 100 is better for datasets < 10000 records, 1000 is better for datasets with 10000 - 1M records. Higher values also work reasonably well for smaller datasets, therefore, default = 1000. For large datasets try 10000. |
| min\_span value | numeric. The minimum geographic extent of datasets to be tested. Default = 2. |
| verbose | character string. Defining the output value. See value. |
|  | logical. If TRUE reports the name of the test and the number of records flagged. |
| diagnostic | logical. If TRUE plots the analyses matrix for each dataset. |

# Details

If the degree sign is recognized as decimal delimiter during coordinate conversion, no coordinate decimals above 0.59 (59’) are possible. The test here uses a binomial test to test if a significant proportion of records in a dataset have been subject to this problem. The test is best adjusted via the diff argument. The lower diff, the stricter the test. Also scales with dataset size. Empirically, for datasets with $< 5 { , } 0 0 0$ unique coordinate records ${ \\mathsf { d i f f } } = 0 . 1$ has proven reasonable flagging most datasets with ${ > } 2 5 %$ problematic records and all dataset with $50 %$ problematic records. For datasets between 5,000 and 100,000 geographic unique records diff $= 0 . 0 1$ is recommended, for datasets between 100,000 and $1 \\textbf { M }$ records diff $= 0 . 0 0 1$ , and so on.

# Value

Depending on the ‘value’ argument, either a data.frame with summary statistics and flags for each dataset (“dataset”) or a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flags”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic. Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Datasets: cd\_round()

# Examples

clean $< -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ runif(100, -180, 180), decimalLatitude $=$ runif(100, -90,90), dataset $=$ "FR")

cd\_ddmm( $\\mathbf { \\nabla } \\cdot \\mathbf { x } \ =$ clean, value $=$ "flagged")

#problematic dataset lon $< -$ sample( $8 : 1 8 0$ , size $= ~ 1 0 0$ , replace $=$ TRUE) $^ +$ runif(100, 0,0.59) lat $< -$ sample(0:90, size $= ~ 1 0 0$ , replace $=$ TRUE) $^ +$ runif(100, 0,0.59)

prob $< -$ data.frame(species $=$ letters\[1:10\], decimalLongitude $=$ lon, decimalLatitude $=$ lat, dataset $=$ "FR")

cd\_ddmm(x $=$ prob, value $=$ "flagged")

cd\_round

# Description

Flags datasets with periodicity patterns indicative of a rasterized (lattice) collection scheme, as often obtain from e.g. atlas data. Using a combination of autocorrelation and sliding-window outlier detection to identify periodicity patterns in the data. See [https://besjournals.onlinelibrary](https://besjournals.onlinelibrary/). wiley.com/doi/full/10.1111/2041-210X.13152 for further details and a description of the algorithm

# Usage

cd\_round( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", ds $=$ "dataset", ${ \\sf T } 1 ~ = ~ 7 ~$ , reg\_out\_thresh $\ c = ~ 2$ , reg\_dist\_min $= ~ 0 . 1$ , reg\_dist\_max $= ~ 2$ , min\_unique\_ds\_size $= ~ 4$ , graphs $=$ TRUE, test $=$ "both", value $\ l = \ l ^ { \\prime \\prime } { \\mathsf { c l e a n } } ^ { \\prime \\prime }$ , verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| ds | a character string. The column with the dataset of each record. In case x should be treated as a single dataset, identical for all records. Default = "dataset". |
| T1 | numeric. The threshold for outlier detection in a in an interquantile range based test. This is the major parameter to specify the sensitivity of the test: lower values, equal higher detection rate. Values between 7-11 are recommended. |
|  | Default = 7. reg\_out\_thresh numeric. Threshold on the number of equal distances between outlier points. See details. Default = 2. |
| reg\_dist\_min | numeric. The minimum detection distance between outliers in degrees (the min- imum resolution of grids that will be flagged). Default = 0.1. |
| reg\_dist\_max | numeric. The maximum detection distance between outliers in degrees (the maximum resolution of grids that will be flagged). Default = 2. |
| min\_unique\_ds\_size |
|  | numeric. The minimum number of unique locations (values in the tested col- umn) for datasets to be included in the test. Default = 4. |
| graphs test | logical. If TRUE, diagnostic plots are produced. Default = TRUE. character string. Indicates which column to test. Either "lat" for latitude, "lon" |
|  | for longitude, or "both" for both. In the latter case datasets are only flagged if both test are failed. Default = "both" |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame with summary statistics and flags for each dataset (“dataset”) or a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic. Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Datasets: cd\_ddmm()

# Examples

#simulate bias grid, one degree resolution, $1 %$ error on a 1000 records dataset

#simulate biased fraction of the data, grid resolution $= ~ 1$ degree

#simulate non-biased fraction of the data bi $< -$ sample $( 3 ~ + ~ 8 { : } 5$ , size $= ~ 1 0 0$ , replace $=$ TRUE) mu $< -$ runif(3, 0, 15) sig $< -$ runif(3, 0.1, 5) cl $< -$ rnorm( $\\mathbf { \\Phi } \_ { \\mathrm { ~ n ~ } } = \ 9 0 0$ , mean $=$ mu, $\\mathsf { s d \ I } =$ sig) lon $< -$ c(cl, bi) bi $< -$ sample(9:13, size $= ~ 1 0 0$ , replace $=$ TRUE) mu $< -$ runif(3, 0, 15) sig $< -$ runif(3, 0.1, 5) cl $< -$ rnorm( $\\mathbf { \\Phi } \_ { \\mathrm { ~ n ~ } } = \ 9 0 0$ , mean $=$ mu, $\\mathsf { s d \ I = }$ sig) lat $< -$ c(cl, bi) #add biased data inp $< -$ data.frame(decimalLongitude $=$ lon, decimalLatitude $=$ lat, dataset $=$ "test")

#run test

## Not run:

cd\_round(inp, value $=$ "dataset")

## End(Not run)

# Description

Removes or flags records that are temporal outliers based on interquantile ranges.

# Usage

cf\_age( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", taxon $=$ "accepted\_name", method $=$ "quantile", size\_thresh $= ~ 7$ ,

$\\mathsf { m l t p l } = 5$ , replicates $= ~ 5$ , flag\_thresh $= ~ 0 . 5$ , uniq\_loc $=$ FALSE, value $=$ "clean", verbose $=$ TRUE )

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing fossil records with taxon names, ages, and geographic coordinates. |
| lon | character string. The column with the longitude coordinates. To identify unique records if uniq\_loc = TRUE. Default = "decimalLongitude". |
| lat | character string. The column with the longitude coordinates. Default = "deci- malLatitude". To identify unique records if uniq\_loc = T. |
| min\_age | character string. The column with the minimum age. Default = "min\_ma". |
| max\_age | character string. The column with the maximum age. Default = "max\_ma". |
| taxon | character string. The column with the taxon name. If "", searches for outliers over the entire dataset, otherwise per specified taxon. Default = "accepted\_name" |
| method | character string. Defining the method for outlier selection. See details. Either "quantile" or "mad". Default = "quantile". |
| size\_thresh | numeric. The minimum number of records needed for a dataset to be tested. Default = 10. |
| mltpl | numeric. The multiplier of the interquartile range (method == ' quantile ' ) or median absolute deviation (method == ' mad') to identify outliers. See details. Default = 5. |
| replicates | numeric. The number of replications for the distance matrix calculation. See details. Default = 5. |
| flag\_thresh | numeric. The fraction of passed replicates necessary to pass the test. See details. |
| uniq\_loc | Default = 0.5. logical. If TRUE only single records per location and time point (and taxon if |
| value | taxon != "") are used for the outlier testing. Default = T. |
| verbose | character string. Defining the output value. See value. logical. If TRUE reports the name of the test and the number of records flagged. |

# Details

The outlier detection is based on an interquantile range test. A temporal distance matrix among all records is calculated based on a single point selected by random between the minimum and maximum age for each record. The mean distance for each point to all neighbours is calculated and the sum of these distances is then tested against the interquantile range and flagged as an outlier if $x > I Q R ( x ) + q \_ { 7 } 5 \* m l t p l$ . The test is replicated ‘replicates’ times, to account for dating uncertainty. Records are flagged as outliers if they are flagged by a fraction of more than ‘flag.thresh’ replicates. Only datasets/taxa comprising more than ‘size\_thresh’ records are tested. Distance are calculated as Euclidean distance.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other fossils: cf\_equal(), cf\_outl(), cf\_range(), write\_pyrate()

# Examples

minages $< -$ c(runif $\\ln \\mathbf { \\alpha } = \\mathbf { \\beta } 1 \\mathbf { \\beta } 1$ , $\\mathsf { m i n } \ = \ 1 \\mathsf { 0 }$ , $\\mathfrak { m a x } \ = \ 2 5 \\mathrm { , }$ ), 62.5)

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ c(letters\[1:10\], rep("z", 2)), min\_ma $=$ minages, max\_ma $=$ c(minages\[1:11\] $^ +$ runif $\\langle n \ = \ 1 1$ , min $= ~ 0$ , $\\mathfrak { m a x } \ = \ 5 ;$ , 65))

cf\_age(x, value $=$ "flagged", taxon = "")

# unique locations only

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ c(letters\[1:10\], $\\mathsf { r e p } ( " z " , ~ 2 ) ;$ ), decimalLongitude $=$ c(runif( $n = 1 0$ , min $= ~ 4$ , max $= ~ 1 6 )$ , 75, 7), decimalLatitude $=$ c(runif $n = 1 2$ , min $= - 5$ , $\\mathfrak { m a x } \ = \ 5 )$ ), min\_ma $=$ minages, max\_ma $=$ c(minages\[1:11\] $^ +$ runif $\\ln \\mathbf { \\lambda } = \\mathbf { \\lambda } 1 \\mathbf { \\lambda } 1$ , min $= ~ 0$ , max $= ~ 5$ ), 65))

cf\_age(x, value $=$ "flagged", taxon $\\begin{array} { r l } { = } & { { } ^ { n p } \ d H } \\end{array}$ , uniq\_loc $=$ TRUE)

cf\_equal

# Description

Removes or flags records with equal minimum and maximum age.

# Usage

cf\_equal( x, min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", value $=$ "clean", verbose $=$ TRUE

)

# Arguments

x data.frame. Containing fossil records with taxon names, ages, and geographic coordinates.

min\_age character string. The column with the minimum age. Default $=$ “min\_ma”.

max\_age character string. The column with the maximum age. Default $=$ “max\_ma”.

value character string. Defining the output value. See value.

verbose logical. If TRUE reports the name of the test and the number of records flagged.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other fossils: cf\_age(), cf\_outl(), cf\_range(), write\_pyrate()

# Examples

minages $< -$ runif $( n = 1 0$ , min $= ~ 0 . 1$ , $\\boldsymbol { \\mathfrak { m a x } } \ = \ 2 5 \\mathrm { , }$

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ letters\[1:10\], min\_ma $=$ minages, max\_ma $=$ minages $^ +$ runif $\\ln \\mathbf { \\alpha } = \\mathbf { \\beta } 1 \\theta$ , min $= ~ 0$ , $\\boldsymbol { \\mathfrak { m } } \\mathsf { a x } \ = \ 1 \\mathsf { \\theta } )$ )

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ rbind(x, data.frame(species $\\begin{array}{c} \\scriptstyle \\frac { \\prime \\prime } { \\end{array} } z ^ { \\prime \\prime }$ , min\_ma $= 5$ , max\_ma $= 5 )$ ))

cf\_equal(x, value $=$ "flagged")

cf\_outl

# Description

Removes or flags records of fossils that are spatio-temporal outliers based on interquantile ranges.

Records are flagged if they are either extreme in time or space, or both.

cf\_outl( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", taxon $=$ "accepted\_name", method $=$ "quantile", size\_thresh $= ~ 7$ , mltpl $= ~ 5$ , replicates $= ~ 5$ , flag\_thresh $= ~ 0 . 5$ , uniq\_loc $=$ FALSE, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing fossil records with taxon names, ages, and geographic coordinates. |
| lon | character string. The column with the longitude coordinates. To identify unique records if uniq\_loc = TRUE. Default = "decimalLongitude". |
| lat | character string. The column with the longitude coordinates. Default = "deci- malLatitude". To identify unique records if uniq\_loc = T. |
| min\_age | character string. The column with the minimum age. Default = "min\_ma". |
| max\_age | character string. The column with the maximum age. Default = "max\_ma". |
| taxon | character string. The column with the taxon name. If ", searches for outliers over the entire dataset, otherwise per specified taxon. Default = "accepted\_name" |
| method | character string. Defining the method for outlier selection. See details. Either "quantile" or "mad". Default = "quantile". |
| size\_thresh | numeric. The minimum number of records needed for a dataset to be tested. Default = 10. |
| mltpl | numeric. The multiplier of the interquartile range (method == 'quantile ') or median absolute deviation (method == ' mad') to identify outliers. See details. Default = 5. |
| replicates | numeric. The number of replications for the distance matrix calculation. See details. Default = 5. |
| flag\_thresh | numeric. The fraction of passed replicates necessary to pass the test. See details. Default = 0.5. |
| uniq\_loc | logical. If TRUE only single records per location and time point (and taxon if taxon != "") are used for the outlier testing. Default = T. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Details

The outlier detection is based on an interquantile range test. In a first step a distance matrix of geographic distances among all records is calculate. Subsequently a similar distance matrix of temporal distances among all records is calculated based on a single point selected by random between the minimum and maximum age for each record. The mean distance for each point to all neighbours is calculated for both matrices and spatial and temporal distances are scaled to the same range. The sum of these distanced is then tested against the interquantile range and flagged as an outlier if $x > I Q R ( x ) + q \_ { 7 } 5 \* m l t p l$ . The test is replicated ‘replicates’ times, to account for temporal uncertainty. Records are flagged as outliers if they are flagged by a fraction of more than ‘flag.thres’ replicates. Only datasets/taxa comprising more than ‘size\_thresh’ records are tested. Note that geographic distances are calculated as geospheric distances for datasets (or taxa) with fewer than 10,000 records and approximated as Euclidean distances for datasets/taxa with 10,000 to 25,000 records. Datasets/taxa comprising more than 25,000 records are skipped.

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other fossils: cf\_age(), cf\_equal(), cf\_range(), write\_pyrate()

# Examples

minages $< -$ c(runif $\\ln \\mathbf { \\alpha } = \\mathbf { \\beta } 1 \\mathbf { \\beta } 1$ , $\\mathsf { m i n } \ = \ 1 \\mathsf { 0 }$ , $\\mathfrak { m a x } \ = \ 2 5 \\mathrm { , }$ ), 62.5)

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ c(letters\[1:10\], rep("z", 2)), lng $=$ c(runif $\\ln \\mathbf { \\alpha } = \\mathbf { \\beta } 1 \\theta$ , min $= ~ 4$ , max = 16), 75, 7), lat $=$ c(runif $\\cdot n = 1 2$ , min $= ~ - 5$ , $\\mathfrak { m a x } \ = \ 5 )$ )), min\_ma $=$ minages, max\_ma $=$ c(minages\[1:11\] $^ +$ runif $\\langle n \ = \ 1 1$ , min $= ~ 0$ , $\\mathfrak { m a x } \ = \ 5 ;$ , 65))

cf\_outl(x, value $=$ "flagged", taxon = "")

cf\_range

# Description

Removes or flags records with an unexpectedly large temporal range, based on a quantile outlier test.

cf\_range( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", taxon $=$ "accepted\_name", method $=$ "quantile", mltpl $= ~ 5$ , size\_thresh $= ~ 7$ , max\_range $= 5 0 0$ , uniq\_loc $=$ FALSE, value $=$ "clean", verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing fossil records with taxon names, ages, and geographic coordinates. |
| lon | character string. The column with the longitude coordinates. To identify unique records if uniq\_loc = TRUE. Default = "decimalLongitude". |
| lat | character string. The column with the longitude coordinates. Default = "deci- malLatitude". To identify unique records if uniq\_loc = T. |
| min\_age | character string. The column with the minimum age. Default = "min\_ma". |
| max\_age | character string. The column with the maximum age. Default = "max\_ma". |
| taxon | character string. The column with the taxon name. If "", searches for outliers over the entire dataset, otherwise per specified taxon. Default = "accepted\_name" |
| method | character string. Defining the method for outlier selection. See details. Either "quantile" or "mad". Default = "quantile". |
| mltpl | numeric. The multiplier of the interquartile range (method == 'quantile ') or median absolute deviation (method == ' mad') to identify outliers. See details. Default = 5. |
| size\_thresh | numeric. The minimum number of records needed for a dataset to be tested. Default = 10. |
| max\_range | numeric. A absolute maximum time interval between min age and max age. Only relevant for method = "time". |
| uniq\_loc | logical. If TRUE only single records per location and time point (and taxon if taxon != ") are used for the outlier testing. Default = T. |
| value | character string. Defining the output value. See value. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |

# Value

Depending on the ‘value’ argument, either a data.frame containing the records considered correct by the test (“clean”) or a logical vector (“flagged”), with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic . Default $=$ “clean”.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other fossils: cf\_age(), cf\_equal(), cf\_outl(), write\_pyrate()

# Examples

minages $< -$ runif $( 1 1 = 1 1$ , min $= ~ 0 . 1$ , $\\boldsymbol { \\mathfrak { m a x } } \ = \ 2 5 \\mathrm { \\cdot }$ )

$\\mathrm { ~ \\mathsf ~ { ~ x ~ } ~ } < -$ data.frame(species $=$ c(letters\[1:10\], "z"), lng = c(runif $\\ln \\mathbf { \\lambda } = \\mathbf { \\lambda } 9$ , min $= ~ 4$ , $\\mathfrak { m a x } \ = \ 1 6 $ ), 75, 7), lat $=$ c(runif $\\langle n \ = \ 1 1$ , min $= ~ - 5$ , $\\mathfrak { m a x } \ = \ 5 )$ ), min\_ma $=$ minages, max\_ma $=$ minages $^ +$ c(runif $\\ln \\mathbf { \\alpha } = \\mathbf { \\beta } 1 \\theta$ , min $= ~ 0$ , $\\mathfrak { m a x } \ = \ 5 \\mathrm { ; }$ ), 25))

cf\_range(x, value $=$ "flagged", taxon = "")

# Description

Cleaning geographic coordinates by multiple empirical tests to flag potentially erroneous coordinates, addressing issues common in biological collection databases.

# Usage

clean\_coordinates( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", species $=$ "species", countries $=$ NULL,

tests $=$ c("capitals", "centroids", "equal", "gbif", "institutions", "outliers", "seas", "zeros"), capitals\_rad $= 1 0 0 0 0$ , centroids\_rad $= \ 1 0 0 0$ , centroids\_detail $=$ "both", inst\_rad $= ~ 1 0 0$ , outliers\_method $=$ "quantile",

outliers\_mtp $= 5$ , outliers\_td $= ~ 1 0 0 0$ , outliers\_size $= ~ 7$ , range\_rad $= ~ 0$ , zeros\_rad $= \ 0 . 5$ , capitals\_ref $=$ NULL, centroids\_ref $=$ NULL, country\_ref $=$ NULL, country\_refcol $=$ "iso\_a3", country\_buffer $=$ NULL, inst\_ref $=$ NULL, range\_ref $=$ NULL, seas\_ref $=$ NULL, seas\_scale $= 5 0$ , seas\_buffer $=$ NULL, urban\_ref $=$ NULL, aohi\_rad $=$ NULL, value $=$ "spatialvalid", verbose $=$ TRUE, report $=$ FALSE )

# Arguments

|     |     |
| --- | --- |
| X | data.frame. Containing geographical coordinates and species names. |
| lon | character string. The column with the longitude coordinates. Default = "deci- malLongitude". |
| lat | character string. The column with the latitude coordinates. Default = "decimal- Latitude". |
| species | a character string. A vector of the same length as rows in x, with the species identity for each record. If NULL, tests must not include the "outliers" or "duplicates" tests. |
| countries | a character string. The column with the country assignment of each record in three letter ISO code. Default = "countrycode". If missing, the countries test is skipped. |
| tests capitals\_rad | a vector of character strings, indicating which tests to run. See details for all tests available. Default = c("capitals", "centroids", "equal", "gbif", "institu- tions", "outliers", "seas", "zeros") |
|  | numeric. The radius around capital coordinates in meters. Default = 10000. centroids\_rad numeric. The radius around centroid coordinates in meters. Default = 1000. |
| centroids\_detail |
| = 'both'. | a character string. If set to 'country' only country (adm-0) centroids are tested, if set to 'provinces' only province (adm-1) centroids are tested. Default |
| inst\_rad | numeric. The radius around biodiversity institutions coordinates in metres. De- fault = 100. |
| outliers\_method |
|  | The method used for outlier testing. See details. |
| outliers\_mtp | numeric. The multiplier for the interquartile range of the outlier test. If NULL outliers. td is used. Default = 5. |
| outliers\_td | numeric. The minimum distance of a record to all other records of a species to be identified as outlier, in km. Default = 1000. |
| outliers\_size | numerical. The minimum number of records in a dataset to run the taxon- specific outlier test. Default = 7. |
| range\_rad | buffer around natural ranges. Default = 0. |
| zeros\_rad | numeric. The radius around 0/0 in degrees. Default = 0.5. |
| capitals\_ref | a data. frame with alternative reference data for the country capitals test. If missing, the countryref dataset is used. Alternatives must be identical in struc- ture. |
| centroids\_ref | a data . frame with alternative reference data for the centroid test. If NULL, the countryref dataset is used. Alternatives must be identical in structure. |
| country\_ref | a SpatVector as alternative reference for the countries test. If NULL, the rnaturalearth:ne\_countries('medium', returnclass = "sf") dataset is us |
| country\_refcol | the column name in the reference dataset, containing the relevant ISO codes for matching. Default is to "iso\_a3\_eh" which referes to the ISO-3 codes in the reference dataset. See notes. |
| country\_buffer | numeric. Units are in meters. If provided, a buffer is created around each coun- try polygon. |
| inst\_ref | a data. frame with alternative reference data for the biodiversity institution test. If NULL, the institutions dataset is used. Alternatives must be identical in structure. |
| range\_ref | a SpatVector of species natural ranges. Required to include the 'ranges' test. See cc\_iucn for details. |
| seas\_ref | a SpatVector as alternative reference for the seas test. If NULL, the rnatu- ralearth::ne\_download(scale = 110, type = 'land', category = 'physical', return- class = "sf") dataset is used. |
| seas\_scale | The scale of the default landmass reference. Must be one of 10, 50, 110. Higher numbers equal higher detail. Default = 50. |
| seas\_buffer | numeric. Units are in meters. If provided, a buffer is created around sea polygon. |
| urban\_ref | a SpatVector as alternative reference for the urban test. If NULL, the test is skipped. See details for a reference gazetteers. |
| aohi\_rad | numeric. The radius around aohi coordinates in meters. Default = 1000. |
| value | a character string defining the output value. See the value section for details. one of 'spatialvalid', 'summary', 'clean'. Default = 'spatialvalid'. |
| verbose | logical. If TRUE reports the name of the test and the number of records flagged. |
| report | logical or character. If TRUE a report file is written to the working directory, |
|  | summarizing the cleaning results. If a character, the path to which the file should be written. Default = FALSE. |

# Details

The function needs all coordinates to be formally valid according to WGS84. If the data contains invalid coordinates, the function will stop and return a vector flagging the invalid records. TRUE $=$ non-problematic coordinate, $\\mathrm { { F A L S E = } }$ potentially problematic coordinates.

• capitals tests a radius around adm-0 capitals. The radius is capitals\_rad.

• centroids tests a radius around country centroids. The radius is centroids\_rad.

• countries tests if coordinates are from the country indicated in the country column. Switched off by default.

• duplicates tests for duplicate records. This checks for identical coordinates or if a species vector is provided for identical coordinates within a species. All but the first records are flagged as duplicates. Switched off by default.

• equal tests for equal absolute longitude and latitude.

• gbif tests a one-degree radius around the GBIF headquarters in Copenhagen, Denmark.

• institutions tests a radius around known biodiversity institutions from instiutions. The radius is inst\_rad.

• outliers tests each species for outlier records. Depending on the outliers\_mtp and outliers.td arguments either flags records that are a minimum distance away from all other records of this species (outliers\_td) or records that are outside a multiple of the interquartile range of minimum distances to the next neighbour of this species (outliers\_mtp). Three different methods are available for the outlier test: "If “outlier” a boxplot method is used and records are flagged as outliers if their mean distance to all other records of the same species is larger than mltpl $^ \*$ the interquartile range of the mean distance of all records of this species. If “mad” the median absolute deviation is used. In this case a record is flagged as outlier, if the mean distance to all other records of the same species is larger than the median of the mean distance of all points plus/minus the mad of the mean distances of all records of the species $\\ast \_ { \\mathrm { \ m l t p l } }$ . If “distance” records are flagged as outliers, if the minimum distance to the next record of the species is $>$ tdi.

• ranges tests if records fall within provided natural range polygons on a per species basis. See cc\_iucn for details.

• seas tests if coordinates fall into the ocean.

• urban tests if coordinates are from urban areas. Switched off by default

• validity checks if coordinates correspond to a lat/lon coordinate reference system. This test is always on, since all records need to pass for any other test to run.

• zeros tests for plain zeros, equal latitude and longitude and a radius around the point $0 / 0$ . The radius is zeros.rad.

# Value

Depending on the output argument:

“spatialvalid” an object of class spatialvalid similar to x with one column added for each test. TRUE $=$ clean coordinate entry, FALSE $=$ potentially problematic coordinate entries. The .summary column is FALSE if any test flagged the respective coordinate.

“flagged” a logical vector with the same order as the input data summarizing the results of all test.

TRUE $=$ clean coordinate, FALSE $=$ potentially problematic $\\mathit { \\Psi } = \\mathit { \\Psi }$ at least one test failed).

“clean” a data.frame similar to $\\mathbf { X }$ with potentially problematic records removed

# Note

Always tests for coordinate validity: non-numeric or missing coordinates and coordinates exceeding the global extent (lon/lat, WGS84). See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

The country\_refcol argument allows to adapt the function to the structure of alternative reference datasets. For instance, for rnaturalearth::ne\_countries(scale $=$ "small", returnclass $=$ "sf"), the default will fail, but country\_refcol $=$ "iso\_a3" will work.

# See Also

Other Wrapper functions: clean\_dataset(), clean\_fossils()

# Examples

exmpl $< -$ data.frame(species $=$ sample(letters, size $= ~ 2 5 0$ , replace $=$ TRUE), decimalLongitude $=$ runif(250, min $= ~ 4 2$ , max $= ~ 5 1$ ), decimalLatitude $=$ runif(250, min $= ~ - 2 6$ , max $=$ -11))

test $< -$ clean\_coordinates( $\\mathbf { \\nabla } \\cdot \\mathbf { x } \ =$ exmpl, tests $=$ c("equal"))

## Not run:

#run more tests

test $< -$ clean\_coordinates( $\\mathbf { \\nabla } \\cdot \\mathbf { x } \ =$ exmpl, tests $=$ c("capitals", "centroids","equal", "gbif", "institutions", "outliers", "seas", "zeros"))

## End(Not run)

summary(test)

clean\_dataset

Coordinate Cleaning using Dataset Properties

# Description

Tests for problems associated with coordinate conversions and rounding, based on dataset properties. Includes test to identify contributing datasets with potential errors with converting ddmm to dd.dd, and periodicity in the data decimals indicating rounding or a raster basis linked to low coordinate precision. Specifically:

• ddmm tests for erroneous conversion from a degree minute format (ddmm) to a decimal degree (dd.dd) format

• periodicity test for periodicity in the data, which can indicate imprecise coordinates, due to rounding or rasterization.

# Usage

clean\_dataset( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", ds $=$ "dataset", tests $=$ c("ddmm", "periodicity"), value $=$ "dataset", verbose $=$ TRUE,

)

# Arguments

x data.frame. Containing geographical coordinates and species names.

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

ds a character string. The column with the dataset of each record. In case x should be treated as a single dataset, identical for all records. Default $=$ “dataset”.

tests a vector of character strings, indicating which tests to run. See details for all tests available. Default $\\mathbf { \\alpha } = \\mathbf { c } ( " \\mathrm { d d m m " } )$ , "periodicity")

value a character string. Defining the output value. See value. Default $=$ “dataset”.

verbose logical. If TRUE reports the name of the test and the number of records flagged. . additional arguments to be passed to cd\_ddmm and cd\_round to customize test sensitivity.

# Details

These tests are based on the statistical distribution of coordinates and their decimals within datasets of geographic distribution records to identify datasets with potential errors/biases. Three potential error sources can be identified. The ddmm flag tests for the particular pattern that emerges if geographical coordinates in a degree minute annotation are transferred into decimal degrees, simply replacing the degree symbol with the decimal point. This kind of problem has been observed by in older datasets first recorded on paper using typewriters, where e.g. a floating point was used as symbol for degrees. The function uses a binomial test to check if more records than expected have decimals below 0.6 (which is the maximum that can be obtained in minutes, as one degree has 60 minutes) and if the number of these records is higher than those above 0.59 by a certain proportion. The periodicity test uses rate estimation in a Poisson process to estimate if there is periodicity in the decimals of a dataset (as would be expected by for example rounding or data that was collected in a raster format) and if there is an over proportional number of records with the decimal 0 (full degrees) which indicates rounding and thus low precision. The default values are empirically optimized by with GBIF data, but should probably be adapted.

# Value

Depending on the ‘value’ argument:

“dataset” a data.frame with the the test summary statistics for each dataset in x “clean” a data.frame containing only records from datasets in $\\mathsf { x }$ that passed the tests “flagged” a logical vector of the same length as rows in x, with TRUE $=$ test passed and FALSE $=$ test failed/potentially problematic.

# Note

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

cd\_ddmm cd\_round

Other Wrapper functions: clean\_coordinates(), clean\_fossils()

# Examples

#Create test dataset

clean $< -$ data.frame(dataset $=$ rep("clean", 1000), decimalLongitude $=$ runif $\\operatorname\* { m i n } = - 4 3$ , $\\mathtt { m a x } \ = \ - 4 0$ , $n \ = \ 1 0 0 0 \\rangle$ , decimalLatitude $=$ runif(min $= - 1 3$ , $\\mathtt { m a x } \ = \ - 1 0$ , $n ~ = ~ 1 0 0 0 )$ )

bias.long $< -$ c(round(runif $( \\mathsf { m i n } \ = \ - 4 2$ , $\\mathtt { m a x } \ = \ - 4 0$ , $n = 5 0 0 \\dot { , }$ ), 1), round(runif $\\operatorname\* { m i n } = - 4 2$ , max $= - 4 0$ , ${ \\sf n } = 3 0 0 \_ { . } ^ { \\cdot }$ ), 0), runif(min $= ~ - 4 2$ , ma $\\times ~ = ~ - 4 0$ , $n = 2 0 0 )$ )

bias.lat $< -$ c(round(runif $( \\mathsf { m i n } \ = \ - 1 2$ , $\\mathtt { m a x } \ = \ - 1 0$ , $\\mathsf { \\Pi } \\mathsf { n } = \\mathsf { \\Pi } 5 0 0 \\dot { \\mathsf { \\Pi } } ,$ ), 1), round(runif(min $= - 1 2$ , max $= - 1 0$ , ${ \\mathsf n } = 3 0 0 \\dot { \\mathsf { \\Omega } }$ ), 0), runif(min $= - 1 2$ , $\\mathtt { m a x } \ = \ - 1 0$ , $n = 2 0 0 )$ ))

bias $< -$ data.frame(dataset $=$ rep("biased", 1000), decimalLongitude $=$ bias.long, decimalLatitude $=$ bias.lat)

test $< -$ rbind(clean, bias)

## Not run: \#run clean\_dataset flags $< -$ clean\_dataset(test)

#check problems

#clean

hist(test\[test$dataset $= =$ rownames(flags\[flags$summary,\]), "decimalLongitude"\])

#biased

hist(test\[test$dataset $= =$ rownames(flags\[!flags$summary,\]), "decimalLongitude"\])

## End(Not run)

|     |     |
| --- | --- |
| clean\_fossils | Geographic and Temporal Cleaning of Records from Fossil Collec- tions |

# Description

Cleaning records by multiple empirical tests to flag potentially erroneous coordinates and timespans, addressing issues common in fossil collection databases. Individual tests can be activated via the tests argument:

# Usage

clean\_fossils( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", taxon $=$ "accepted\_name", tests $=$ c("agesequal", "centroids", "equal", "gbif", "institutions", "spatiotemp", "temprange", "validity", "zeros"), countries $=$ NULL, centroids\_rad $= ~ 0 . 0 5$ , centroids\_detail $=$ "both", inst\_rad $= \ 0 . 0 0 1$ , outliers\_method $=$ "quantile", outliers\_threshold $= 5$ , outliers\_size $= ~ 7$ , outliers\_replicates $= 5$ , zeros\_rad $= \ 0 . 5$ , centroids\_ref $=$ NULL, country\_ref $=$ NULL, inst\_ref $=$ NULL, value $=$ "spatialvalid", verbose $=$ TRUE, report $=$ FALSE

)

# Arguments

x data.frame. Containing fossil records, containing taxon names, ages, and geographic coordinates..

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

|     |     |
| --- | --- |
| n\_fossils 45 |
| min\_age | character string. The column with the minimum age. Default = "min\_ma". |
| max\_age | character string. The column with the maximum age. Default = "max\_ma". |
| taxon | character string. The column with the taxon name. If ", searches for outliers over the entire dataset, otherwise per specified taxon. Default = "accepted\_name" |
| tests | vector of character strings, indicating which tests to run. See details for all tests available. Default = c("centroids", "equal", "gbif", "institutions", "temprange", "spatiotemp", "agesequal", "zeros") |
| countries | a character string. The column with the country assignment of each record in three letter ISO code. Default = "countrycode". If missing, the countries test is skipped. |
| centroids\_rad centroids\_detail | numeric. The radius around centroid coordinates in meters. Default = 1000. |
|  | a character string. If set to 'country' only country (adm-0) centroids are tested, if set to 'provinces' only province (adm-1) centroids are tested. Default |
| inst\_rad | = 'both'. numeric. The radius around biodiversity institutions coordinates in metres. De- |
| outliers\_method | fault = 100. |
| The method used for outlier testing. See details. |
| outliers\_threshold | numerical. The multiplier for the interquantile range for outlier detection. The |
| outliers\_size | higher the number, the more conservative the outlier tests. See cf\_outl for details. Default = 3. numerical. The minimum number of records in a dataset to run the taxon- |
| outliers\_replicates | specific outlier test. Default = 7. |
| numeric. The number of replications for the distance matrix calculation. See details. Default = 5. |
| zeros\_rad | numeric. The radius around 0/0 in degrees. Default = 0.5. |
| centroids\_ref | a data. frame with alternative reference data for the centroid test. If NULL, the |
| country\_ref | countryref dataset is used. Alternatives must be identical in structure. a SpatVector as alternative reference for the countries test. If NULL, the |
| inst\_ref | rnaturalearth:ne\_countries('medium', returnclass = "sf") dataset is us a data . frame with alternative reference data for the biodiversity institution test. If NULL, the institutions dataset is used. Alternatives must be identical in |
| value | structure. a character string defining the output value. See the value section for details. |
|  | one of 'spatialvalid', 'summary', 'clean'. Default = 'spatialvalid'. logical. If TRUE reports the name of the test and the number of records flagged. |
| verbose report | logical or character. If TRUE a report file is written to the working directory, |
|  | summarizing the cleaning results. If a character, the path to which the file should be written. Default = FALSE. |

# Details

• agesequal tests for equal minimum and maximum age.

• centroids tests a radius around country centroids. The radius is centroids\_rad.

• countries tests if coordinates are from the country indicated in the country column. Switched off by default.

• equal tests for equal absolute longitude and latitude.

• gbif tests a one-degree radius around the GBIF headquarters in Copenhagen, Denmark.

• institutions tests a radius around known biodiversity institutions from instiutions. The radius is inst\_rad.

• spatiotemp test for records which are outlier in time and space. See below for details.

• temprange tests for records with unexpectedly large temporal ranges, using a quantile-based outlier test.

• validity checks if coordinates correspond to a lat/lon coordinate reference system. This test is always on, since all records need to pass for any other test to run.

• zeros tests for plain zeros, equal latitude and longitude and a radius around the point 0/0. The

radius is zeros\_rad. The outlier detection in ‘spatiotemp’ is based on an interquantile range test. In a first step a distance matrix of geographic distances among all records is calculate. Subsequently a similar distance matrix of temporal distances among all records is calculated based on a single point selected by random between the minimum and maximum age for each record. The mean distance for each point to all neighbours is calculated for both matrices and spatial and temporal distances are scaled to the same range. The sum of these distanced is then tested against the interquantile range and flagged as an outlier if $x > I Q R ( x ) +$ $q \_ { 7 } 5 \* m l t p l$ . The test is replicated ‘replicates’ times, to account for temporal uncertainty. Records are flagged as outliers if they are flagged by a fraction of more than ‘flag\_thresh’ replicates. Only datasets/taxa comprising more than ‘size.thresh’ records are tested. Note that geographic distances are calculated as geospheric distances for datasets (or taxa) with fewer than 10,000 records and approximated as Euclidean distances for datasets/taxa with 10,000 to 25,000 records. Datasets/taxa comprising more than 25,000 records are skipped.

# Value

Depending on the output argument:

“spatialvalid” an object of class spatialvalid similar to x with one column added for each test. TRUE $=$ clean coordinate entry, FALSE $=$ potentially problematic coordinate entries. The .summary column is FALSE if any test flagged the respective coordinate.

“flagged” a logical vector with the same order as the input data summarizing the results of all test. TRUE $=$ clean coordinate, FALSE $=$ potentially problematic $\\mathit { \\Psi } = \\mathit { \\Psi }$ at least one test failed).

“clean” a data.frame similar to $\\mathbf { X }$ with potentially problematic records removed

# Note

Always tests for coordinate validity: non-numeric or missing coordinates and coordinates exceeding the global extent (lon/lat, WGS84).

See [https://ropensci.github.io/CoordinateCleaner/](https://ropensci.github.io/CoordinateCleaner/) for more details and tutorials.

# See Also

Other Wrapper functions: clean\_coordinates(), clean\_dataset()

# Examples

minages $< -$ runif(250, 0, 65)

exmpl $< -$ data.frame(accepted\_name $=$ sample(letters, size $= ~ 2 5 0$ , replace $=$ TRUE), decimalLongitude $=$ runif(250, min $= ~ 4 2$ , max $= ~ 5 1$ ), decimalLatitude $=$ runif(250, min $= ~ - 2 6$ , max $\ c = - 1 7$ ), min\_ma $=$ minages, max\_ma $=$ minages $^ +$ runif(250, 0.1, 65))

test $< -$ clean\_fossils( $\\mathbf { \\nabla } \\times \\mathbf { \\nabla } = \\mathbf { \\nabla }$ exmpl)

summary(test)

countryref

Country Centroids and Country Capitals

# Description

A data.frame with coordinates of country and province centroids and country capitals as reference for the clean\_coordinates, cc\_cen and cc\_cap functions. Coordinates are based on the Central Intelligence Agency World Factbook [https://www.cia.gov/the-world-factbook/](https://www.cia.gov/the-world-factbook/), https:// thematicmapping.org/downloads/world\_borders.php and geolocate [https://geo-locate](https://geo-locate/). org.

# Format

A data frame with 5,305 observations on 13 variables. #’

iso3 ISO-3 code for each country, in case of provinces also referring to the country.

iso2 ISO-2 code for each country, in case of provinces also referring to the country.

adm1\_code adm code for countries and provinces.

name a factor; name of the country or province.

type identifying if the entry refers to a country or province level.

centroid.lon Longitude of the country centroid.

centroid.lat Latitude of the country centroid.

capital Name of the country capital, empty for provinces.

capital.lon Longitude of the country capital.

capital.lat Latitude of the country capital.

area\_sqkm The area of the country or province.

uncertaintyRadiusMeters The uncertainty of the country centroid.

source The data source. Currently only available for [https://geo-locate.org](https://geo-locate.org/)

# Source

CENTRAL INTELLIGENCE AGENCY (2014) The World Factbook, Washington, DC.

[https://www.cia.gov/the-world-factbook/](https://www.cia.gov/the-world-factbook/) [https://thematicmapping.org/downloads/world](https://thematicmapping.org/downloads/world)\_ borders.php [https://geo-locate.org](https://geo-locate.org/)

# Examples

data(countryref) head(countryref)

# institutions

# Description

A global gazetteer for biodiversity institutions from various sources, including zoos, museums, botanical gardens, GBIF contributors, herbaria, university collections.

# Format

A data frame with 12170 observations on 12 variables.

# Source

Compiled from various sources:

• Global Biodiversity Information Facility [https://www.gbif.org/](https://www.gbif.org/)

• Wikipedia [https://www.wikipedia.org/](https://www.wikipedia.org/)

• Geonames [https://www.geonames.org/](https://www.geonames.org/)

• The Global Registry of Biodiversity Repositories

• Index Herbariorum [https://sweetgum.nybg.org/science/ih/](https://sweetgum.nybg.org/science/ih/)

• Botanic Gardens Conservation International [https://www.bgci.org/](https://www.bgci.org/)

# Examples

data(institutions) str(institutions)

# Description

Test if its argument is a spatialvalid object

# Usage

is.spatialvalid(x)

# Arguments

x the object to be tested

# Value

returns TRUE if its argument is a spatialvalid

pbdb\_example

Example data from the Paleobiologydatabase

# Description

A dataset of 5000 flowering plant fossil occurrences as example for data of the paleobiology Database, downloaded using the paleobioDB packages as specified in the vignette “Cleaning\_PBDB\_fossils\_with\_Coordinat

# Format

A data frame with 5000 observations on 36 variables.

# Source

• The Paleobiology database [https://paleobiodb.org/](https://paleobiodb.org/)

• Sara Varela, Javier Gonzalez Hernandez and Luciano Fabris Sgarbi (2016). paleobioDB: Download and Process Data from the Paleobiology Database. R package version 0.5.0. https: //CRAN.R-project.org/package=paleobioDB.

# Examples

data(institutions) str(institutions)

# Description

A set of plots to explore objects of the class spatialvalid. A plot to visualize the flags from clean\_coordinates

# Usage

## S3 method for class 'spatialvalid'

plot( x, lon $=$ "decimalLongitude", lat $=$ "decimalLatitude", bgmap $=$ NULL, clean $=$ TRUE, details $=$ FALSE, pts\_size $= ~ 1$ , font\_size $= ~ 1 0$ , $z \_ { 0 0 \\mathrm { m } \_ { - } } \\mathrm { f } ~ = ~ 0 . 1$ ,

)

# Arguments

x an object of the class spatialvalid as from clean\_coordinates.

lon character string. The column with the longitude coordinates. Default $=$ “decimalLongitude”.

lat character string. The column with the latitude coordinates. Default $=$ “decimalLatitude”.

bgmap an object of the class SpatVector or sf used as background map. Default $=$ ggplot::borders()

clean logical. If TRUE, non-flagged coordinates are included in the map.

details logical. If TRUE, occurrences are color-coded by the type of flag.

pts\_size numeric. The point size for the plot.

font\_size numeric. The font size for the legend and axes

zoom\_f numeric. the fraction by which to expand the plotting area from the occurrence records. Increase, if countries do not show up on the background map. arguments to be passed to methods.

# Value

A plot of the records flagged as potentially erroneous by clean\_coordinates.

# See Also

clean\_coordinates

# Examples

exmpl $< -$ data.frame(species $=$ sample(letters, size $= ~ 2 5 0$ , replace $=$ TRUE), decimalLongitude $=$ runif(250, min $= ~ 4 2$ , max $= ~ 5 1$ ), decimalLatitude $=$ runif(250, min $= ~ - 2 6$ , max $\ : \ : = \ : - 1 1 )$ )

test $< -$ clean\_coordinates(exmpl, species $=$ "species", tests $=$ c("sea", "gbif", "zeros"), verbose $=$ FALSE)

summary(test) plot(test)

write\_pyrate

Create Input Files for PyRate

# Description

Creates the input necessary to run Pyrate, based on a data.frame with fossil ages (as derived e.g. from clean\_fossils) and a vector of the extinction status for each sample. Creates files in the working directory!

# Usage

write\_pyrate( x, status, fname, taxon $=$ "accepted\_name", min\_age $=$ "min\_ma", max\_age $=$ "max\_ma", trait $=$ NULL, path $=$ getwd(), replicates $= ~ 1$ , cutoff $=$ NULL, random $=$ TRUE

)

# Arguments

x data.frame. Containing fossil records with taxon names, ages, and geographic coordinates.

status a vector of character strings of length nrow(x). Indicating for each record “extinct” or “extant”.

|     |     |
| --- | --- |
| fname | a character string. The prefix to use for the output files. |
| taxon | character string. The column with the taxon name. Default = "accepted\_name". |
| min\_age | character string. The column with the minimum age. Default = "min\_ma". |
| max\_age | character string. The column with the maximum age. Default = "max\_ma". |
| trait | a numeric vector of length nrow(x). Indicating trait values for each record. |
| path | Optional. Default = NULL. a character string. giving the absolute path to write the output files. Default is |
| replicates | the working directory. a numerical. The number of replicates for the randomized age generation. See |
| cutoff | details. Default = 1. a numerical. Specify a threshold to exclude fossil occurrences with a high temporal uncertainty, i.e. with a wide temporal range between min\_age and max\_age. Examples: cutoff=NULL (default; all occurrences are kept in the |
| random | excluded from the data set) logical. Specify whether to take a random age (between MinT and MaxT) for each occurrence or the midpoint age. Note that this option defaults to TRUE if several replicates are generated (i.e. replicates > 1). Examples: random = TRUE |

# Details

The replicate option allows the user to generate several replicates of the data set in a single input file, each time re-drawing the ages of the occurrences at random from uniform distributions with boundaries MinT and MaxT. The replicates can be analysed in different runs (see PyRate command -j) and combining the results of these replicates is a way to account for the uncertainty of the true ages of the fossil occurrences. Examples: replicate $^ { = 1 }$ (default, generates 1 data set), replicates $\_ { \\mathrm { = } 1 0 }$ (generates 10 random replicates of the data set).

# Value

PyRate input files in the working directory.

# Note

See [https://github.com/dsilvestro/PyRate/wiki](https://github.com/dsilvestro/PyRate/wiki) for more details and tutorials on PyRate and PyRate input.

# See Also

Other fossils: cf\_age(), cf\_equal(), cf\_outl(), cf\_range()

# Examples

minages $< -$ runif(250, 0, 65)

exmpl $< -$ data.frame(accepted\_name $=$ sample(letters, $\\mathsf { s i z e } ~ = ~ 2 5 \\mathsf { \\theta }$ , replace $=$ TRUE), lng $=$ runif(250, min $= ~ 4 2$ , max $= ~ 5 1$ ),

lat $=$ runif(250, min = -26, $\\mathsf { m a x } \ = \ - 1 1 ,$ ), min\_ma $=$ minages, max\_ma $=$ minages $^ +$ runif(250, 0.1, 65))

#a vector with the status for each record,

#make sure species are only classified as either extinct or extant,

#otherwise the function will drop an error

status $< -$ sample(c("extinct", "extant"), size $=$ nrow(exmpl), replace $=$ TRUE)

#or from a list of species

status $< -$ sample(c("extinct", "extant"), size $=$ length(letters), replace $=$ TRUE)

names(status) $< -$ letters

status $< -$ status\[exmpl$accepted\_name\]

## Not run: write\_pyrate $\\mathbf { \\nabla } \\cdot \\mathbf { x } \ =$ exmpl,fname $=$ "test", status $=$ status)

## End(Not run)

# Index

$^ \*$ Check is.spatialvalid, 49

$^ \*$ Coordinates cc\_aohi, 5 cc\_cap, 6 cc\_cen, 8 cc\_coun, 9 cc\_dupl, 11 cc\_equ, 12 cc\_gbif, 14 cc\_inst, 15 cc\_iucn, 17 cc\_outl, 18 cc\_sea, 21 cc\_urb, 22 cc\_val, 24 cc\_zero, 25

$^ \*$ Coordinate cc\_aohi, 5 cc\_cap, 6 cc\_cen, 8 cc\_coun, 9 cc\_dupl, 11 cc\_equ, 12 cc\_gbif, 14 cc\_inst, 15 cc\_iucn, 17 cc\_outl, 18 cc\_sea, 21 cc\_urb, 22 cc\_val, 24 cc\_zero, 25 cd\_ddmm, 26 cd\_round, 28 cf\_age, 30 cf\_outl, 33 clean\_coordinates, 37 clean\_dataset, 41 clean\_fossils, 44

$^ \*$ Datasets cd\_ddmm, 26 cd\_round, 28

$^ \*$ Dataset cd\_ddmm, 26 cd\_round, 28

$^ \*$ Fossils cf\_equal, 32

$^ \*$ Fossil cf\_age, 30 cf\_outl, 33 cf\_range, 35 clean\_fossils, 44 write\_pyrate, 51

$^ \*$ Temporal cf\_age, 30 cf\_equal, 32 cf\_outl, 33 cf\_range, 35 clean\_fossils, 44

$^ \*$ Visualisation plot.spatialvalid, 50

$^ \*$ Wrapper functions clean\_coordinates, 37 clean\_dataset, 41 clean\_fossils, 44

$^ \*$ cleaning cc\_aohi, 5 cc\_cap, 6 cc\_cen, 8 cc\_coun, 9 cc\_dupl, 11 cc\_equ, 12 cc\_gbif, 14 cc\_inst, 15 cc\_iucn, 17 cc\_outl, 18 cc\_sea, 21 cc\_urb, 22 cc\_val, 24 cc\_zero, 25 cf\_age, 30 cf\_equal, 32 cf\_outl, 33 cf\_range, 35 clean\_coordinates, 37 clean\_dataset, 41 clean\_fossils, 44

$^ \*$ fossils cf\_age, 30 cf\_equal, 32 cf\_outl, 33 cf\_range, 35 write\_pyrate, 51

$^ \*$ gazetteers aohi, 3 buffland, 4 buffsea, 4 countryref, 47 institutions, 48 pbdb\_example, 49

$^ \*$ level cd\_ddmm, 26 cd\_round, 28

$^ \*$ wrapper clean\_coordinates, 37 clean\_dataset, 41

aohi, 3

cc\_inst, 6, 7, 9, 11–13, 15, 15, 18, 20, 22–24, 26

cc\_iucn, 6, 7, 9, 11–13, 15, 16, 17, 20, 22–24, 26, 39, 40

cc\_outl, 6, 7, 9, 11–13, 15, 16, 18, 18, 22–24, 26

cc\_sea, 4, 6, 7, 9, 11–13, 15, 16, 18, 20, 21, 23, 24, 26

cc\_urb, 6, 7, 9, 11–13, 15, 16, 18, 20, 22, 22, 24, 26

cc\_val, 6, 7, 9, 11–13, 15, 16, 18, 20, 22, 23, 24, 26

cc\_zero, 6, 7, 9, 11–13, 15, 16, 18, 20, 22–24, 25

cd\_ddmm, 26, 29, 42, 43

cd\_round, 27, 28, 42, 43

cf\_age, 30, 33, 35, 37, 52

cf\_equal, 32, 32, 35, 37, 52

cf\_outl, 32, 33, 33, 37, 45, 52

cf\_range, 32, 33, 35, 35, 52

clean\_coordinates, 37, 43, 47, 50, 51

clean\_dataset, 41, 41, 47

clean\_fossils, 41, 43, 44

countryref, 7, 9, 47

institutions, 16, 48

is.spatialvalid, 49

pbdb\_example, 49

plot.spatialvalid, 50

summary.spatialvalid (clean\_coordinates), 37 write\_pyrate, 32, 33, 35, 37, 51

buffland, 4, 22

buffsea, 4

cc\_aohi, 5, 7, 9, 11–13, 15, 16, 18, 20, 22–24, 26

cc\_cap, 6, 6, 9, 11–13, 15, 16, 18, 20, 22–24, 26, 47

cc\_cen, 6, 7, 8, 11–13, 15, 16, 18, 20, 22–24, 26, 47

cc\_coun, 6, 7, 9, 9, 12, 13, 15, 16, 18, 20, 22–24, 26

cc\_dupl, 6, 7, 9, 11, 11, 13, 15, 16, 18, 20, 22–24, 26

cc\_equ, 6, 7, 9, 11, 12, 12, 15, 16, 18, 20, 22–24, 26

cc\_gbif, 6, 7, 9, 11–13, 14, 16, 18, 20, 22–24, 26