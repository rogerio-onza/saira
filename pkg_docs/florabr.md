# Package ‘florabr’

October 14, 2025

Title Explore Flora e Funga do Brasil Database

Version 1.3.1

Description A collection of functions designed to retrieve, filter and spatialize data from the Flora e Funga do Brasil dataset. For more information about the dataset, please visit [https://floradobrasil.jbrj.gov.br/consulta/](https://floradobrasil.jbrj.gov.br/consulta/).

Imports XML $( > = 3 . 9 9 . 0 . 1 4 ,$ ), data.table $( > = 1 . 1 4 . 8 )$ , httr $( > = 1 . 4 . 6 )$ terra $( > = 1 . 7 . 3 9 $ ), stats $( > = 4 . 2 . 3 )$ ), utils $( > = 4 . 2 . 3 )$ ), grDevices $( > = 4 . 2 . 3 )$ , doSNOW $( > = 1 . 0 . 2 0 )$ ), parallel $( > = 4 . 3 . 1 $ ), foreach $( > = 1 . 5 . 2 )$

License GPL $\\mathrm { ( > = } 3$ )

Encoding UTF-8

RoxygenNote 7.3.3

Depends R $( > = 2 . 1 0 )$ )

LazyData true

Suggests knitr, rmarkdown, testthat $( > = 3 . 0 . 0 $ )

VignetteBuilder knitr

URL [https://wevertonbio.github.io/florabr/](https://wevertonbio.github.io/florabr/)

BugReports [https://github.com/wevertonbio/florabr/issues](https://github.com/wevertonbio/florabr/issues)

Config/testthat/edition 3

NeedsCompilation no

Author Weverton Trindade \[aut, cre\] (ORCID: [https://orcid.org/0000-0003-2045-4555](https://orcid.org/0000-0003-2045-4555))

Maintainer Weverton Trindade [wevertonf1993@gmail.com](mailto:wevertonf1993@gmail.com)

Repository CRAN

Date/Publication 2025-10-14 19:30:02 UTC

# Contents

bf\_data 2

biomes . 3

brazil 4

check\_names 4

check\_version 6

filter\_florabr . 7

get\_attributes 9

get\_binomial 10

get\_florabr . . 11

get\_pam . 12

get\_spat\_occ 13

get\_synonym 15

load\_florabr 16

occurrences 17

select\_by\_vernacular 18

select\_species . 19

solve\_discrepancies 22

states 2323

subset\_species . .

# Index

bf\_data

# Description

A dataset containing a subset of the Flora e Funga do Brasil database (version 393.401)

# Usage

data(bf\_data)

# Format

A data.frame with 50010 rows and 23 variables:

species Species names

scientificName Complete scientific name of the species

acceptedName Accepted name of the species (NA when the name in species is already an accepted name)

kingdom Kingdom to which species belongs (Plantae or Fungi)

group Major group to which species belongs (Angiosperms, Gymnosperms, Ferns and Lycophytes, Bryophytes, and Algae)

subgroup Subgroup to which species belongs. Only available for Bryophytes (Mosses, Hornworts, and Liverworts)

phylum Phylum to which species belongs

class Class to which species belongs

order Order to which species belongs

family Family to which species belongs

genus Genus to which species belongs

lifeForm Life form of the species (e.g: Tree, Herb, Shrub, etc.)

habitat Habitat type of the species (e.g., Terrestrial, Rupicolous, Epiphytic, etc.)

biome Biomes with confirmed occurrences of the species

states Federal states with confirmed occurrences of the species

vegetation Vegetation types with confirmed occurrences of the species

origin Indicates whether the species is Native, Naturalized, or Cultivated in Braz

endemism Indicates whether the species is Endemic or Non-endemic to Brazil

taxonomicStatus Indicates the level of recognition and acceptance of the species (Accepted or Synonym)

nomenclaturalStatus Indicates the legitimacy and validity of the species name (Correct, Illegitimate, Uncertain\_Application, etc.)

vernacularName Locally or culturally used name for the species

taxonRank Taxonomic rank (Species, Genus, Family, Order, etc). This data contains only Species id Unique id for species

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

biomes

# Description

A simplified and packed SpatVector of the polygons of the biomes present in Brazilian territory. The spatial data was originally obtained from geobr::read\_biomes. Borders have been simplified by removing vertices of borders using terra::simplifyGeom. It’s necessary unpack the Spatvectos using terra::unwrap

$@$ usage data(biomes) biomes $< -$ terra::unwrap(biomes)

# Usage

biomes

# Format

A SpatVector with 6 geometries and 1 attribute:

name\_biome The name of the biome (Amazon, Caatinga, Cerrado, Atlantic\_Forest, Pampa, and Pantanal)

brazil

SpatVector of the Brazil’s national borders

# Description

A simplified and packed SpatVector of the Brazil’s national borders. The spatial data was originally obtained from geobr::read\_country. Borders have been simplified by removing vertices of borders using terra::simplifyGeom. It’s necessary unpack the Spatvectos using terra::unwrap

$@$ usage data(brazil) brazil $< -$ terra::unwrap(brazil)

# Usage

brazil

# Format

A SpatVector with 1 geometry and 0 attribute

check\_names

Check species names

# Description

check\_names checks if the species names are correct and searches for suggestions if the name is misspelled or not found in the Flora e Funga do Brasil database

match\_names finds approximate matches to the specified pattern (species) within each element of the string $\\mathsf { x }$ (species\_to\_match). It is used internally by check\_names.

# Usage

check\_names(data, species, max\_distance $= ~ 0 . 1$ , include\_subspecies $=$ FALSE, include\_variety $=$ FALSE, kingdom $=$ "Plantae", parallel $=$ FALSE, ncores $= ~ 1$ , progress\_bar $=$ FALSE)

match\_names( species, species\_to\_match, max\_distance $= ~ 0 . 1$ ,

parallel $=$ FALSE, ncores $= ~ 1$ , progress\_bar $=$ FALSE )

# Arguments

data (data.frame) the data.frame imported with the load\_florabr function.

species (character) names of the species to be checked.

max\_distance (numeric) Maximum distance (as a fraction) allowed for searching suggestions when the name is misspelled. It can be any value between 0 and 1. The higher the value, the more suggestions are returned. For more details, see agrep. Default $= 0 . 1$ .

include\_subspecies (logical) whether to include subspecies. Default $=$ FALSE

include\_variety (logical) whether to include varieties. Default $=$ FALSE

kingdom (character) the kingdom to which the species belong. It can be "Plantae" or "Fungi". Default $=$ "Plantae".

parallel (logical) whether to run in parallel. Setting this to TRUE is recommended for improved performance when working with 100 or more species.

ncores (numeric) number of cores to use for parallel processing. Default is 1. This is only applicable if parallel $=$ TRUE.

progress\_bar (logical) whether to display a progress bar during processing. Default is FALSE

species\_to\_match (character) a vector of species names to match against the species parameter.

# Value

a data.frame with the following columns:

• input\_name: the species names informed in species argument

• Spelling: indicates if the species name is Correct (a perfect match with a species name in the Flora e Funga do Brasil), Probably\_incorrect (partial match), or Not\_found (no match with any species).

• Suggested name: If Spelling is Correct, it is the same as the input\_name. If Spelling is Probably\_correct, one or more suggested names are listed, found according to the maximum distance. If Spelling is "Not\_found", the value is NA.

• Distance: The integer Levenshtein edit distance. It represents the number of single-character edits (insertions, deletions, or substitutions) required to transform the input\_name into the Suggested\_name.

• taxonomicStatus: the taxonomic status of the species name ("Accepted" or "Synonym").

• nomenclaturalStatus: the nomenclatural status of the species name. This information is not available for all species.

• acceptedName: If the species name is not accepted or incorrect, the accepted name of the specie. If the species name is accepted and correct, the same as input\_name and Suggested\_nam

• family: the family of the specie.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data", package $=$ "florabr") spp $< -$ c("Butia cattarinensis", "Araucaria angustifolia") check\_names(data $=$ bf\_data, species $=$ spp)

# check\_version

Check if you have the latest version of Flora e Funga do Brasil data available

# Description

This function checks if you have the latest version of the Flora e Funga do Brasil data available in a specified directory.

# Usage

check\_version(data\_dir)

# Arguments

data\_dir the directory where the data should be located.

# Value

A message informing whether you have the latest version of Flora e Funga do Brasil available in the data\_dir

# Examples

#Check if there is a version of Flora e Funga do Brasil data available in the

#current directory

check\_version(data\_dir $=$ getwd())

|     |     |
| --- | --- |
| filter\_florabr | Identify records outside natural ranges according to Flora e Funga do Brasil |

# Description

This function removes or flags records outside of the species’ natural ranges according to information provided by the Flora e Funga do Brasil database.

# Usage

filter\_florabr(data, occ, species $=$ "species", long $\\mathrm { ~ ~ { ~ \\underline { ~ } { ~ } { ~ \\mathbf ~ { ~ \\theta ~ } ~ } ~ } ~ } = \\mathrm { ~ ~ { ~ \\underline { ~ } { ~ } { ~ \\mathbf ~ { ~ \\theta ~ } ~ } ~ } ~ } \\times \\mathrm { ~ ~ { ~ \\mathbf ~ { ~ \\theta ~ } ~ } ~ }$ , $\\tt { l a t } = \ " \\mathrm { y } "$ , by\_state $=$ TRUE, buffer\_state $= 2 0$ , by\_biome $=$ TRUE, buffer\_biome $= 2 0$ , by\_endemism $=$ TRUE, buffer\_brazil $= 2 0$ , state\_vect $=$ NULL, state\_column $=$ NULL, biome\_vect $=$ NULL, biome\_column $=$ NULL, br\_vect $=$ NULL, value $=$ "flag&clean", keep\_columns $=$ TRUE, verbose $=$ TRUE)

# Arguments

data (data.frame) the data.frame imported with the load\_florabr function.

occ (data.frame) a data.frame with the records of the species.

species (character) column name in occ with species names. Default $=$ "species"

long (character) column name in occ with longitude data. Default ${ \\bf \\Xi } = " { \\bf x }$ "

lat (character) column name in occ with latitude data. Default $=$ "y"

by\_state (logical) filter records by state? Default $=$ TRUE

buffer\_state (numeric) buffer $( \\mathrm { i n } \ \\mathrm { k m } )$ ) around the polygons of the states of occurrence of the specie. Default $= 2 0$ .

by\_biome (logical) filter records by biome? Default $=$ TRUE

buffer\_biome (numeric) buffer (in km) around the polygons of the biomes of occurrence of the specie. Default $= 2 0$ .

by\_endemism (logical) filter records by endemism? Default $=$ TRUE

buffer\_brazil (numeric) buffer (in km) around the polygons of the brazil. Default $= 2 0$ .

state\_vect (SpatVector) a SpatVector of the Brazilian states. By default, it uses the SpatVector provided by geobr::read\_state(). It can be another Spatvector, but the structure must be identical to geobr::read\_state().

state\_column (character) name of the column in state\_vect containing state abbreviations. Only use if biome\_vect is not null.

biome\_vect (SpatVector) a SpatVector of the Brazilian biomes. By default, it uses the SpatVector provided by geobr::read\_biomes(). It can be another SpatVector, but the structure must be identical to geobr::read\_biomes() with biome names in English.

biome\_column (character) name of the column in biome\_vect containing names of brazilian biomes (in English: "Amazon", "Atlantic\_Forest", "Caatinga", "Cerrado", "Pampa" and "Pantanal". Only use if biome\_vect is not null.

br\_vect (SpatVector) a SpatVector of brazil. By default, it uses the SpatVector provided by geobr::read\_state() after being aggregated/dissolved,

value (character) Defines output values. See Value section. Default $=$ "flag&clean".

keep\_columns (logical) if TRUE, keep all the original columns of the input occ. If False, keep only the columns species, long and lat. Default $=$ TRUE

verbose (logical) Whether to display species being filtered during function execution. Set to TRUE to enable display, or FALSE to run silently. Default $=$ TRUE.

# Details

If by\_state $=$ TRUE and/or by\_biome $= { \\mathrm { T R U E } }$ , the function takes polygons representing the states and/or biomes with confirmed occurrences of the specie, draws a buffer around the polygons, and tests if the records of the species fall inside it. If by\_endemis $\\mathrm { \\Delta n = T R U E }$ , the function checks if the species is endemic to brazil. If it is endemic, the function tests if the records of the specie fall inside a polygon representing the boundaries of brazil (with a buffer).

# Value

Depending on the ’value’ argument. If value $=$ "flag", it returns the same data.frame provided in data with additional columns indicating if the record falls inside the natural range of the specie (TRUE) or outside (FALSE). If value $=$ "clean", it returns a data.frame with only the records that passes all the tests (TRUE for all the filters). If value $=$ "flag&clean" (Default), it returns a list with two data.frames: one with the flagged records and one with the cleaned records.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

data("occurrences") #Load occurrences

pts $< -$ subset(occurrences, species $= =$ "Myrcia hatschbachii")

fd $< -$ filter\_florabr(data $=$ bf\_data, occ $=$ pts, by\_state $=$ TRUE, buffer\_state $= 2 0$ , by\_biome $=$ TRUE, buffer\_biome $= 2 0$ , by\_endemism $=$ TRUE, buffer\_brazil $= 2 0$ , state\_vect $=$ NULL, biome\_vect $=$ NULL, br\_vect $=$ NULL, value $=$ "flag&clean", keep\_columns $=$ TRUE, verbose $=$ FALSE)

# Description

This function displays all the options available to filter species by its characteristics

# Usage

get\_attributes(data, attribute)

# Arguments

data (data.frame) a data.frame imported with the load\_florabr function or a data.frame generated with the select\_species function.

attribute (character) the type of characteristic. Accept more than one option. See detail to see the options.

# Details

The attribute argument accepts the following options: kingdom, group, subgroup, phylum, class, order, family, lifeform, habitat, vegetation, origin, endemism, biome, states, taxonomicstatus or nomenclaturalstatus. These options represent different characteristics of species that can be used for filtering.

# Value

a list of data.frames with the available options to use in the select\_species function.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data # Get available biomes, life forms and states to filter species $\\texttt { d } < -$ get\_attributes(data $=$ bf\_data, attribute $=$ c("biome", "lifeform", "states"))

Extract the binomial name (Genus $^ +$ specific epithet $^ +$ infraspecific epithet (optional)) from a full Scientific Name

# Description

Extract the binomial name (Genus $^ +$ specific epithet $^ +$ infraspecific epithet (optional)) from a full Scientific Name

# Usage

get\_binomial(species\_names, include\_subspecies $=$ TRUE, include\_variety $=$ TRUE)

# Arguments

species\_names (character) Scientific names to be converted to binomial names

include\_subspecies (logical) include subspecies? If TRUE (default), the function extracts any infraspecific epithet after the pattern "subsp."

include\_variety (logical) include subspecies? If TRUE (default), the function extracts any infraspecific epithet after the pattern "var."

# Value

A vector with the binomial names (Genus $^ +$ specific epithet).

# Examples

spp $< -$ c("Araucaria angustifolia (Bertol.) Kuntze", "Araucaria angustifolia var. alba Reitz", "Butia catarinensis Noblick & Lorenzi", "Butia eriospatha subsp. punctata", "Adesmia paranensis Burkart")

spp\_new $< -$ get\_binomial(species\_names $=$ spp, include\_subspecies $=$ TRUE, include\_variety $=$ TRUE)

spp\_new

# Description

This function downloads the latest or an older version of Flora e Funga do Brasil database, merges the information into a single data.frame, and saves this data.frame in the specified directory.

# Usage

get\_florabr(output\_dir, data\_version $=$ "latest", solve\_discrepancy $=$ FALSE, overwrite $=$ TRUE, verbose $=$ TRUE, remove\_files $=$ TRUE)

# Arguments

output\_dir (character) a directory to save the data downloaded from Flora e Funga do Brasil.

data\_version (character) Version of the Flora e Funga do Brasil database to download. Use "latest" to get the most recent version, updated weekly. Alternatively, specify an older version (e.g., data\_version $= " 3 9 3 . 3 1 9 "$ ). Default value is "latest".

solve\_discrepancy Resolve discrepancies between species and subspecies/varieties information. When set to TRUE, species information is updated based on unique data from varieties and subspecies. For example, if a subspecies occurs in a certain biome, it implies that the species also occurs in that biome. Default $=$ FALSE.

overwrite (logical) If TRUE, data is overwritten. Default $=$ TRUE.

verbose (logical) Whether to display messages during function execution. Set to TRUE to enable display, or FALSE to run silently. Default $=$ TRUE.

remove\_files (logical) Whether to remove the downloaded files used in building the final dataset. Default is TRUE.

# Value

The function downloads the latest version of the Flora e Funga do Brasil database from the official source. It then merges the information into a single data.frame, containing details on species, taxonomy, occurrence, and other relevant data. The merged data.frame is then saved as a file in the specified output directory. The data is saved in a format that allows easy loading using the load\_florabr function for further analysis in R.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

## Not run:

#Creating a folder in a temporary directory

#Replace 'file.path(tempdir(), "florabr")' by a path folder to be create in

#your computer

my\_dir $< -$ file.path(file.path(tempdir(), "florabr"))

dir.create(my\_dir)

#Download, merge and save data

get\_florabr(output\_dir $=$ my\_dir, data\_version $=$ "latest", solve\_discrepancy $=$ FALSE, overwrite $=$ TRUE, verbose $=$ TRUE)

## End(Not run)

get\_pam

Get a presence-absence matrix

# Description

Get a presence-absence matrix of species based on its distribution (states, biomes and vegetation types) according to Flora e Funga do Brasil.

# Usage

get\_pam(data, by\_biome $=$ TRUE, by\_state $=$ TRUE, by\_vegetation $=$ FALSE, remove\_empty\_sites $=$ TRUE, return\_richness\_summary $=$ TRUE, return\_spatial\_richness $=$ TRUE, return\_plot $=$ TRUE)

# Arguments

data (data.frame) a data.frame imported with the load\_florabr function or generated by either select\_species or subset\_species functions

by\_biome (logical) get occurrences by biome. Default $=$ TRUE

by\_state (logical) get occurrences by State. Default $=$ TRUE

by\_vegetation (logical) get occurrences by vegetation type. Default $=$ FALSE

remove\_empty\_sites (logical) remove empty sites (sites without any species) from final presenceabsence matrix. Default $=$ TRUE

return\_richness\_summary (logical) return a data.frame with the number of species in each site. Default $=$ TRUE

return\_spatial\_richness (logical) return a SpatVector with the number of species in each site. Default $=$ TRUE

return\_plot (logical) plot map with the number of species in each site. Only works if return\_spatial\_richness $=$ TRUE. Default $=$ TRUE

# Value

If return\_richness\_summary and/or return\_spatial\_richness is set to TRUE, return a list with:

• PAM: the presence-absence matrix (PAM)

• Richness\_summary: a data.frame with the number of species in each site

• Spatial\_richness: a SpatVector with the number of species in each site (only by State and biome)

If return\_richness\_summary and return\_spatial\_richness is set to FALSE, return a presence-absence matrix

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

#Select endemic and native species of trees with occurrence only in Amazon

am\_trees $< -$ select\_species(data $=$ bf\_data, include\_subspecies $=$ FALSE, include\_variety $=$ FALSE, kingdom $=$ "Plantae", group $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , subgroup $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , family $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A l T } \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , genus $=$ "All", lifeForm $=$ "Tree", filter\_lifeForm $=$ "only", habitat $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_habitat $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { 1 } \\mathsf { n } ^ { \\prime \\prime }$ , biome $=$ "Amazon", filter\_biome $=$ "only", state $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_state $=$ "and", vegetation $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_vegetation $=$ "in", endemism $=$ "Endemic", origin $=$ "Native", taxonomicStatus $=$ "Accepted", nomenclaturalStatus $=$ "All")

#Get presence-absence matrix

pam\_am $< -$ get\_pam(data $=$ am\_trees, by\_biome $=$ TRUE, by\_state $=$ TRUE, by\_vegetation $=$ FALSE, remove\_empty\_sites $=$ TRUE, return\_richness\_summary $=$ TRUE, return\_spatial\_richness $=$ TRUE, return\_plot $=$ TRUE)

get\_spat\_occ

# Description

Get Spatial polygons (SpatVectors) of species based on its distribution (states and biomes) according to Flora e Funga do Brasil

# Usage

get\_spat\_occ( data, species, state $=$ TRUE, biome $=$ TRUE, intersection $=$ TRUE, state\_vect $=$ NULL, state\_column $=$ NULL, biome\_vect $=$ NULL, biome\_column $=$ NULL, verbose $=$ TRUE

)

# Arguments

|     |     |
| --- | --- |
| data | (data.frame) the data.frame imported with the load\_florabr function. |
| species | (character) one or more species names (only genus and specific epithet, eg. "Araucaria angustifolia") |
| state | (logical) get SpatVector of states with occurrence of the species? Default = TRUE |
| biome | (logical) get SpatVector of biomes with occurrence of the species? Default = TRUE |
| intersection | (character) get a Spatvector representing the intersection between states and biomes with occurrence of the specie? To use intersection = TRUE, you must define state = TRUE and biome = TRUE". Default = TRUE |
| state\_vect | (SpatVector) a SpatVector of the Brazilian states. By default, it uses the SpatVec- tor provided by geobr:read\_state(). It can be another Spatvector, but the struc- ture must be identical to geobr::read\_state(). |
| state\_column | (character) name of the column in state\_vect containing state abbreviations. Only use if biome\_vect is not null. |
| biome\_vect | (SpatVector) a SpatVector of the Brazilian biomes. By default, it uses the SpatVec tor provided by geobr::read\_biomes(). It can be another SpatVector, but the |
| biome\_column | structure must be identical to geobr::read\_biomes(). (character) name of the column in biome\_vect containing names of brazilian biomes (in English: "Amazon", "Atlantic\_Forest", "Caatinga", "Cerrado", "Pamp |
| verbose | and "Pantanal". Only use if biome\_vect is not null. (logical) Whether to display species being filtered during function execution. Set to TRUE to enable display, or FALSE to run silently. Default = TRUE. |

# Value

A list with SpatVectors of states and/or biomes and/or Intersections for each specie.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

library(terra)

data("bf\_data") #Load Flora e Funga do Brasil data

spp $< -$ c("Araucaria angustifolia", "Adesmia paranensis") #Example species

#Get states, biomes and intersection states-biomes of species

spp\_spt $< -$ get\_spat\_occ(data $=$ bf\_data, species $=$ spp, state $=$ TRUE, biome $=$ TRUE, intersection $=$ TRUE, state\_vect $=$ NULL, biome\_vect $=$ NULL, verbose $=$ TRUE)

#Plot states of occurrence of Araucaria angustifolia

plot(spp\_spt\[\[1\]\]$states, main $=$ names(spp\_spt)\[\[1\]\])

#Plot biomes of occurrence of Araucaria angustifolia

plot(spp\_spt\[\[2\]\]$biomes, main $=$ names(spp\_spt)\[\[2\]\])

#Plot intersection between states and biomes of occurrence of

#Araucaria angustifolia

plot(spp\_spt\[\[1\]\]$states\_biomes)

get\_synonym

# Description

Retrieve synonyms for species

# Usage

get\_synonym(data, species, include\_subspecies $=$ TRUE, include\_variety $=$ TRUE)

# Arguments

data (data.frame) the data.frame imported with the load\_florabr function

species (character) names of the species

include\_subspecies (logical) include subspecies that are synonyms of the species? Default $=$ TRUE

include\_variety (logical) include varieties that are synonyms of the species? Default $=$ TRUE

# Value

A data.frame containing unique synonyms of the specified species along with relevant information on taxonomic and nomenclatural statuses.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

#Species to extract synonyms

spp $< -$ c("Araucaria angustifolia", "Adesmia paranensis")

spp\_synonyms $< -$ get\_synonym(data $=$ bf\_data, species $=$ spp, include\_subspecies $=$ TRUE, include\_variety $=$ TRUE)

spp\_synonyms

load\_florabr

# Description

Load Flora e Funga do Brasil database

# Usage

load\_florabr(data\_dir, data\_version $=$ "Latest\_available", type $=$ "short", verbose $=$ TRUE)

# Arguments

data\_dir (character) the same directory used to save the data downloaded from Flora e Funga do Brasil using the get\_florabr function.

data\_version (character) the version of Flora e Funga do Brasil database to be loaded. It can be "Latest\_available", which will load the latest version available; or another specified version, for example "393.364". Default $=$ "Latest\_available".

type (character) it determines the number of columns that will be loaded. It can be "short" or "complete". Default $=$ "short". See details.

verbose (logical) Whether to display messages during function execution. Set to TRUE to enable display, or FALSE to run silently. Default $=$ TRUE.

# Details

The parameter type accepts two arguments. If type $=$ short, it will load a data.frame with the 20 columns needed to run the other functions of the package: species, scientificName, acceptedName, kingdom, Group, Subgroup, family, genus, lifeForm, habitat, Biome, States, vegetationType, Origin, Endemism, taxonomicStatus, nomenclaturalStatus, vernacularName, taxonRank, and id If type $=$ complete, it will load a data.frame with all 39 variables available in Flora e Funga do Brasil database.

# Value

A data.frame with the specified version (Default is the latest available) of the Flora e Funga do Brasil database. This data.frame is necessary to run most of the functions of the package.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

## Not run:

#Creating a folder in a temporary directory

#Replace 'file.path(tempdir(), "florabr")' by a path folder to be create in

#your computer

my\_dir $< -$ file.path(file.path(tempdir(), "florabr"))

dir.create(my\_dir)

#Download, merge and save data

get\_florabr(output\_dir $=$ my\_dir, data\_version $=$ "latest", overwrite $=$ TRUE, verbose $=$ TRUE)

#Load data

df $< -$ load\_florabr(data\_dir $=$ my\_dir, data\_version $=$ "Latest\_available",

type $=$ "short")

## End(Not run)

# occurrences

# Description

A dataset containing records of 7 plant species downloaded from GBIF. The records were obtained with plantR::rgbif2

# Usage

data(occurrences)

# Format

A data.frame with 1521 rows and 3 variables:

species Species names (Araucaria angustifolia, Abatia americana, Passiflora edmundoi, Myrcia hatschbachii, Serjania pernambucensis, Inga virescens, and Solanum restingae)

x Longitude

y Latitude

# References

GBIF, 2024. florabr R package: Records of plant species. [https://doi.org/10.15468/DD.QPGEB7](https://doi.org/10.15468/DD.QPGEB7)

select\_by\_vernacular Search for taxa using vernacular names

# Description

Search for taxa using vernacular names

# Usage

select\_by\_vernacular(data, names, exact $=$ FALSE)

# Arguments

|     |     |
| --- | --- |
| data | (data.frame) the data.frame imported with the load\_florabr function or gener- ated with the function select\_species. |
| names | (character) vernacular name ("Nome comum") of the species to be searched |
| exact | (logic) if TRUE, the function will search only for exact matches. For example, if names = "pinheiro" and exact = TRUE, the function will return only the species popularly known as "pinheiro". On the other hand, if names = "pinheiro" and exact = FALSE, the function will return other results as "pinheiro-do-parana". Default = FALSE |

# Value

a data.frame with the species with vernacular names that match the input names

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/) Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

#Search for species whose vernacular name is 'pinheiro'

pinheiro\_exact $< -$ select\_by\_vernacular(data $=$ bf\_data, names $=$ "pinheiro", exact $=$ TRUE)

head(pinheiro\_not\_exact)

select\_species

# Description

select\_species allows filter species based on its characteristics and distribution available in Flora e Funga do Brasil

# Usage

select\_species(data,

include\_subspecies $=$ FALSE, include\_variety $=$ FALSE,

kingdom $=$ "Plantae", group $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , subgroup $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

phylum $=$ "All", class $= " \\mathsf { A } 1 1 "$ , order $=$ "All",

family $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , genus $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

lifeForm $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_lifeForm $=$ "in",

habitat $=$ "All", filter\_habitat $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

biome $=$ "All", filter\_biome $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { \\bf 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

state $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } \\mathbf { 1 } \\mathbf { 1 } ^ { \\prime \\prime } } \\end{array}$ , filter\_state $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { \\bf 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

vegetation $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_vegetation $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

endemism $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , origin $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

taxonomicStatus $=$ "Accepted",

nomenclaturalStatus $\\mathbf { \\Sigma } = \\mathbf { \\Sigma } ^ { \\prime \\prime } { \\sf A l 1 ^ { \\prime \\prime } }$ )

# Arguments

data (data.frame) the data.frame imported with the load\_florabr function.

include\_subspecies (logical) include subspecies? Default $=$ FALSE

include\_variety (logical) include varieties of the species? Default $=$ FALSE

endemism (character) The endemism (endemic or non-endemic to Brazil) for filtering the dataset. It can be "All", "Endemic" or "Non-endemic". Default $= " \\mathrm { A l l " }$ .

origin (character) The origin for filtering the dataset. It can be "All", "Native", "Cultivated" and "Naturalized". Default $=$ "All".

taxonomicStatus (character) The taxonomic status for filtering the dataset. It can be "All", "Accepted" or "Synonym". Default $=$ "Accepted".

nomenclaturalStatus (character) The nomenclatural status for filtering the dataset. Default $=$ "Accepted"

|     |     |
| --- | --- |
| kingdom | (character) The kingdom for filtering the dataset. It can be "Plantae" or "Fungi". Default = "Plantae". To include both, use c("Plantae", "Fungi") |
| group | (character) The groups for filtering the datasets. It can be "Fungi", "Angiosperms "Gymnosperms", "Ferns and Lycophytes", "Bryophytes" and "Algae". To use more than one group, put the available items in a vector, for example: group = |
| subgroup | c(Angiosperms", "Gymnosperms"). Default = "All". (character) The subgroups for filtering the dataset. Only available if the group is "Fungi" or "Bryophytes". For Fungi, it can be "stricto sensu" or "lato sensu". For Bryophytes, it can be "Mosses", "Hornworts" and "Liverworts" . To use |
| phylum | more than one group, put the available items in a vector, for example: subgroup = c("Mosses", "Hornworts"). Default = "All". (character) The phyla for filtering the dataset. It can be included more than one |
| class | phylum. Default = "All". (character) The classes for filtering the dataset. It can be included more than one |
| order | class. Default = "All". (character) The orders for filtering the dataset. It can be included more than one |
| family | order. Default = "All". (character) The families for filtering the dataset. It can be included more than |
| genus | one family. Default = "All". (character) The genus for filtering the dataset. It can be included more than one |
| lifeForm | genus. Default = "All". (character) The life forms for filtering the dataset. It can be included more than |
| filter\_lifeForm | one lifeForm. Default = "All" |
|  | (character) The type of filtering for life forms. It can be "in", "only", "not\_in" and "and". See details for more about this argument. |
| habitat | (character) The life habitat for filtering the dataset. It can be included more than one habitat. Default = "All" |
| filter\_habitat | (character) The type of filtering for habitat. It can be "in", "only", "not\_in" and "and". See details for more about this argument. |
| biome | (character) The biomes for filtering the dataset. It can be included more than one biome. Default = "All" |
| filter\_biome | (character) The type of filtering for biome. It can be "in", "only", "not\_in" and "and". See details for more about this argument. |
| state | (character) The states for filtering the dataset. It can be included more than one state. Default = "All". |
| filter\_state | (character) The type of filtering for state. It can be "in", "only", "not\_in" and "and". See Details for more about this argument. |
| vegetation | (character) The vegetation types for filtering the dataset. It can be included more than one vegetation type. Default = "All". |
| filter\_vegetation |
| (character) The type of filtering for vegetation type. It can be "in", "only", "not\_in" and "and". See details for more about this argument. |

# Details

It’s possible to choose 4 ways to filter by lifeForm, by habitat, by biome, by state and by vegetation type: "in": selects species that have any occurrence of the determined values. It allows multiple matches. For example, if biome $= 0$ c("Amazon", Cerrado" and filter\_biome $= " \\mathrm { i n } "$ , it will select all species that occur in the Amazon and Cerrado, some of which may also occur in other biomes.

"only": selects species that have only occurrence of the determined values. It allows only single matches. For example, if biome $=$ c("Amazon", "Cerrado") and filter\_biome $=$ "only", it will select all species that occur exclusively in both the Amazon and Cerrado biomes, without any occurrences in other biomes.

"not\_in": selects species that don’t have occurrence of the determined values. It allows single and multiple matches. For example, if biome $= \\mathrm { c }$ ("Amazon", "Cerrado") and filter\_biome $= " \\mathrm { n o t \_ i n " }$ , it will select all species without occurrences in the Amazon and Cerrado biomes.

"and": selects species that have occurrence in all determined values. It allows single and multiple matches. For example, if biome $=$ c("Amazon", "Cerrado") and filter\_biome $=$ "and", it will select all species that occurs only in both the Amazon and Cerrado biomes, including species that occurs in other biomes too.

To get the complete list of arguments available for family, genus, lifeForm, habitat, biome, state, and nomenclaturalStatus, use the function get\_attributes

# Value

A new dataframe with the filtered species.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

#'Select endemic and native species of trees with disjunct occurrence in

# Atlantic Forest and Amazon

am\_af\_only $< -$ select\_species(data $=$ bf\_data, include\_subspecies $=$ FALSE, include\_variety $=$ FALSE, kingdom $=$ "Plantae",

$\\mathsf { g r o u p } = \\mathsf { \\Omega } ^ { \\prime \\prime } \\mathsf { A l l } ^ { \\prime \\prime }$ , subgroup $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

phylum $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , class $= " \\mathsf { A } 1 1 "$ , order $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

family $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , genus $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

lifeForm $=$ "Tree", filter\_lifeForm $=$ "only",

habitat $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_habitat $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

biome $=$ c("Atlantic\_Forest","Amazon"),

filter\_biome $=$ "only",

state $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ , filter\_state $=$ "and",

vegetation $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ ,

filter\_vegetation $\\mathbf { \\mu } = \\mathbf { \\mu } ^ { \\prime \\prime } \\dot { 1 } \\mathsf { n } ^ { \\prime \\prime }$ ,

endemism $=$ "Endemic", origin $=$ "Native",

taxonomicStatus $=$ "All",

nomenclaturalStatus $\\begin{array} { r l } { \\mathbf { \\Phi } } & { { } = \\mathbf { \\Phi } ^ { \\prime \\prime } \\mathsf { A } 1 1 \\mathbf { \\Phi } ^ { \\prime \\prime } } \\end{array}$ )

# solve\_discrepancies

Resolve discrepancies between species and subspecies/varieties information

# Description

Resolve discrepancies between species and subspecies/varieties information

# Usage

solve\_discrepancies(data)

# Arguments

data

(data.frame) the data.frame imported with the load\_florabr function.

# Details

In the original dataset, discrepancies may exist between species and subspecies/varieties information. An example of a discrepancy is when a species occurs only in one biome (e.g., Amazon), but a subspecies or variety of the same species occurs in another biome (e.g., Cerrado). This function rectifies such discrepancies by considering distribution (states, biomes, and vegetation), life form, and habitat. For instance, if a subspecies is recorded in a specific biome, it implies that the species also occurs in that biome.

# Value

a data.frame with the discrepancies solved

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data #Check if discrepancies were solved in the dataset attr(bf\_data, "solve\_discrepancies") #Solve discrepancies

bf\_solved $< -$ solve\_discrepancies(bf\_data) #Check if discrepancies were solved in the dataset attr(bf\_solved, "solve\_discrepancies")

states

# Description

A simplified and packed SpatVector of the polygons of the federal states of Brazil. The spatial data was originally obtained from geobr::read\_state. Borders have been simplified by removing vertices of borders using terra::simplifyGeom. It’s necessary unpack the Spatvectos using terra::unwrap

$@$ usage data(states) states $< -$ terra::unwrap(states)

# Usage

states

# Format

A SpatVector with 27 geometries and 3 attributes:

abbrev\_state State acronym

name\_state State’s full name

name\_region The region to which the state belongs

subset\_species

# Description

Returns a data.frame with a subset of species from Flora e Funga do Brasil database

# Usage

subset\_species(data, species, include\_subspecies $=$ FALSE, include\_variety $=$ FALSE, kingdom $=$ "Plantae")

# Arguments

data (data.frame) the data.frame imported with the load\_florabr function.

species (character) names of the species to be extracted from Flora e Funga do Brasil database.

include\_subspecies (logical) include subspecies? Default $=$ FALSE

include\_variety (logical) include varieties of the species? Default $=$ FALSE

kingdom (character) The kingdom for filtering the dataset. It can be "Plantae" or "Fungi". Default $=$ "Plantae". To include both, use c("Plantae", "Fungi")

# Value

A data.frame with the selected species.

# References

Flora e Funga do Brasil. Jardim Botânico do Rio de Janeiro. Available at: [http://floradobrasil.jbrj.gov.br/](http://floradobrasil.jbrj.gov.br/)

# Examples

data("bf\_data") #Load Flora e Funga do Brasil data

#Species to extract from database

spp $< -$ c("Araucaria angustifolia", "Adesmia paranensis")

spp\_bf $< -$ subset\_species(data $=$ bf\_data, species $=$ spp, include\_subspecies $=$ FALSE, include\_variety $=$ FALSE)

spp\_bf

# Index

# $^ \*$ datasets

bf\_data, 2

biomes, 3

brazil, 4

occurrences, 17

states, 23

agrep, 5

bf\_data, 2

biomes, 3

brazil, 4

check\_names, 4

check\_version, 6

filter\_florabr, 7

get\_attributes, 9, 21

get\_binomial, 10

get\_florabr, 11, 16

get\_pam, 12

get\_spat\_occ, 13

get\_synonym, 15

load\_florabr, 5, 7, 9, 11, 12, 14, 15, 16, 18, 19, 22, 24

match\_names (check\_names), 4 occurrences, 17

select\_by\_vernacular, 18

select\_species, 9, 12, 18, 19

solve\_discrepancies, 22

states, 23

subset\_species, 12, 23