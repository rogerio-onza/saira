## Package ‘faunabr’

#### October 20, 2025

Title Explore Catálogo Taxônomico da Fauna do Brasil Database Version 1.0.0 Description A collection of functions designed to retrieve, filter and spatialize data from the Catál- ogo Taxônomico da Fauna do Brasil. For more informa- tion about the dataset, please visit < [http://fauna.jbrj.gov.br/fauna/listaBrasil/](http://fauna.jbrj.gov.br/fauna/listaBrasil/) >. Imports XML (>= 3.99.0.14), data.table (>= 1.14.8), httr (>= 1.4.6), terra (>= 1.7.39), stats (>= 4.2.3), utils(>= 4.2.3), License GPL (>= 3) Encoding UTF-8 RoxygenNote 7.3.3 Depends R (>= 2.10) LazyData true Suggests knitr, rmarkdown, testthat (>= 3.0.0) VignetteBuilder knitr BugReports [https://github.com/wevertonbio/faunabr/issues](https://github.com/wevertonbio/faunabr/issues) URL [https://wevertonbio.github.io/faunabr/](https://wevertonbio.github.io/faunabr/) NeedsCompilation no Author Weverton Trindade \[aut, cre\] (ORCID: < [https://orcid.org/0000-0003-2045-4555](https://orcid.org/0000-0003-2045-4555) >) Maintainer Weverton Trindade [wevertonf1993@gmail.com](mailto:wevertonf1993@gmail.com) Repository CRAN Date/Publication 2025-10-20 19:30:09 UTC

### Contents

check\_fauna\_names . ... . . .. . . .. . . .. . . .. . . .. . . . . . . . . . . . . .2
country\_codes .. ... . ... . .. . . .. . . .. . . .. . . . . . . . . . . . . . . . .3
extract\_binomial. ... . .. . .. . . .. . . .. . . .. . . . . . . . . . . . . . . . .4
fauna\_attributes. ... . ... . .. . . .. . . .. . . .. . . . . . . . . . . . . . . . .5

2 _check\_fauna\_names_

fauna\_by\_vernacular... . .. . .. . . .. . . .. . . .. . . . . . . . . . . . . . . .5
fauna\_data ... . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .6
fauna\_discrepancies . ... . .. . .. . . .. . . .. . . .. . . . . . . . . . . . . . . .7
fauna\_pam ... . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .8
fauna\_spat\_occ. ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .10
fauna\_synonym. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .11
fauna\_version. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .12
filter\_faunabr.. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .12
get\_faunabr.. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .14
load\_faunabr. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .15
map\_translation. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .16
occurrences.. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .17
select\_fauna ... . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .17
states. ... . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .19
subset\_fauna. . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .20
translate\_faunabr. ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .21
world\_fauna ... . ... . ... . . .. . . .. . . .. . . .. . . . . . . . . . . . . . .21

Index 23

check\_fauna\_names Check species names

Description check\_fauna\_names checks if the species names are correct and searches for suggestions if the name is misspelled or not found in the Fauna do Brasil database

Usage check\_fauna\_names(data, species, max\_distance = 0.1, include\_subspecies = TRUE)

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. species (character) names of the species to be checked. max\_distance (numeric) Maximum distance (as a fraction) allowed for searching suggestions when the name is misspelled. It can be any value between 0 and 1. The higher the value, the more suggestions are returned. For more details, see agrep. De- fault = 0.1. include\_subspecies whether include subspecies when checking names. Default = TRUE.

_country\_codes_ 3

Value a data.frame with the following columns:

•input\_name: the species names informed in species argument •Spelling: indicates if the species name is Correct (a perfect match with a species name in the Flora e Funga do Brasil), Probably\_incorrect (partial match), or Not\_found (no match with any species). •Suggested name: If Spelling is Correct, it is the same as the input\_name. If Spelling is Prob- ably\_correct, one or more suggested names are listed, found according to the maximum dis- tance. If Spelling is "Not\_found", the value is NA. •Distance: The integer Levenshtein edit distance. It represents the number of single-character edits (insertions, deletions, or substitutions) required to transform the input\_name into the Suggested\_name. •taxonomicStatus: the taxonomic status of the species name ("valid" or "synonym"). •nomenclaturalStatus: the nomenclatural status of the species name. This information is not available for all species. •validName: If the species name is not valid or incorrect, the valid name of the specie. If the species name is valid and correct, the same as input\_name and Suggested\_name. •family: the family of the specie.

References Brazilian Zoology Group. Catálogo Taxonômico da Fauna do Brasil. Available at: [https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo\_taxonomico\_da\_fauna\_do\_brasil](https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil)

Examples data("fauna\_data") spp <- c("Pantera onça", "Mazama bororo", "Mazama jucunda", "Araucaria angustifolia") check\_fauna\_names(data = fauna\_data, species = spp)

country\_codes Country Codes and Names

Description A dataset containing country codes used in the Catálogo Taxonômico da Fauna do Brasil along with their corresponding country names, as defined in faunabr::world\_fauna.

Usage data(country\_codes)

4 _extract\_binomial_

Format

A data.frame with 244 rows and 2 variables:

map\_name Country names as defined in faunabr::world\_fauna. country\_code Country codes used in the Catálogo Taxonômico da Fauna do Brasil.

extract\_binomial Extract the binomial name (Genus + specific epithet) from a Scientific Name

Description

Extract the binomial name (Genus + specific epithet) from a Scientific Name

Usage

extract\_binomial(species\_names)

Arguments

species\_names (character) Scientific names to be converted to binomial names

Value

A vector with the binomial names (Genus + specific epithet).

Examples

spp <- c("Panthera onca (Linnaeus, 1758)", "Zonotrichia capensis subtorquata Swainson, 1837", "Paraganaspis egeria Díaz & Gallardo, 1996", "Arrenurus tumulosus intercursor") spp\_new <- extract\_binomial(species\_names = spp) spp\_new

_fauna\_attributes_ 5

fauna\_attributes Get available attributes to filter species

Description This function displays all the options available to filter species by its characteristics

Usage fauna\_attributes(data, attribute)

Arguments data (data.frame) a data.frame imported with the load\_faunabr function or a data.frame generated with the select\_fauna function. attribute (character) the type of characteristic. Accept more than one option. See detail to see the options.

Details The attribute argument accepts the following options: phylum, class, family, genus, lifeForm, habi- tat, states, country, origin, and taxonomicstatus. These options represent different characteristics of species that can be used for filtering.

Value a list of data.frames with the available options to use in the select\_fauna function.

Examples data("fauna\_data") #Load data example # Get available states, countries and lifeForms to filter species d <- fauna\_attributes(data = fauna\_data, attribute = c("country", "lifeform", "states"))

fauna\_by\_vernacular Search for taxa using vernacular names

Description Search for taxa using vernacular names

Usage fauna\_by\_vernacular(data, names, exact = FALSE)

6 _fauna\_data_

Arguments data (data.frame) the data.frame imported with the load\_faunabr function or gener- ated with the function select\_fauna. names (character) vernacular name ("Nome comum") of the species to be searched exact (logic) if TRUE, the function will search only for exact matches. For example, if names = "veado-mateiro" and exact = TRUE, the function will return only the species popularly known as "veado-mateiro". On the other hand, if names = "veado-mateiro" and exact = FALSE, the function will return other results as "Veado-mateiro-pequeno". Default = FALSE

Value a data.frame with the species with vernacular names that match the input names

Examples data("fauna\_data") #Load Fauna do Brasil data #Search for species whose vernacular name is 'veado-mateiro' veado\_exact <- fauna\_by\_vernacular(data = fauna\_data, names = "veado-mateiro", exact = TRUE) veado\_exact #Search for species whose vernacular name is'veado\_mateiro', allowing non-exact #matches veado\_not\_exact <-fauna\_by\_vernacular(data = fauna\_data, names = "veado-mateiro", exact = FALSE)

fauna\_data Catálogo Taxonômico da Fauna do Brasil database-Version 1.17

Description A dataset containing a subset of the Catálogo Taxonômico da Fauna do Brasil database (version

1.17)
Usage data(fauna\_data)

Format A data.frame with 9558 rows and 19 variables: species Species names subspecies Subspecies names

_fauna\_discrepancies_ 7

scientificName Complete scientific name of the species validName Valid name of the species (NA when the name in species is already a valid name) kingdom Kingdom to which species belongs (Animalia) phylum Phylum to which species belongs class Class to which species belongs order Order to which species belongs family Family to which species belongs genus Genus to which species belongs lifeForm Life form of the species (e.g: free\_living\_individual, colonial, sessile, etc.) habitat Habitat type of the species (e.g., terrestrial, arboreal, freshwater, etc.) states Federal states with confirmed occurrences of the species countryCode Countries with confirmed occurrences of the species origin Indicates whether the species is native, introduced, domesticated, cryptogenic or invasive taxonomicStatus Indicates the level of recognition and acceptance of the species (valid or syn- onym) nomenclaturalStatus Indicates the legitimacy and validity of the species name (original\_combination, changed\_combination, etc.) vernacularName Locally or culturally used name for the species taxonRank Taxonomic rank (Species, Genus, Family, Order, etc). This data contains only Species

References Brazilian Zoology Group. Catálogo Taxonômico da Fauna do Brasil. Available at: [https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo\_taxonomico\_da\_fauna\_do\_brasil](https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil)

fauna\_discrepancies Resolve discrepancies between species and subspecies information

Description Resolve discrepancies between species and subspecies information

Usage fauna\_discrepancies(data)

Arguments data (data.frame) the data.frame imported with the load\_faunabr function.

8 _fauna\_pam_

Details In the original dataset, discrepancies may exist between species and subspecies information. An example of a discrepancy is when species occurs only in one state (e.g., SP), but a subspecies or variety of the same species occurs in another states (e.g., SP and RJ). This function rectifies such discrepancies by considering distribution (states and countries) life form, and habitat. For instance, if a subspecies is recorded in a specific state, it implies that the species also occurs in that state

Value a data.frame with the discrepancies solved

Examples data("fauna\_data") #Load fauna e Funga do Brasil data #Check if discrepancies were solved in the dataset attr(fauna\_data, "solved\_discrepancies") #Solve discrepancies fauna\_solved <- fauna\_discrepancies(fauna\_data) #Check if discrepancies were solved in the dataset attr(fauna\_solved, "solved\_discrepancies")

fauna\_pam Get a presence-absence matrix

Description Get a presence-absence matrix of species based on its distribution (brazilian states and/or countries) according to Fauna do Brasil.

Usage fauna\_pam(data, by\_state = TRUE, by\_country= FALSE, remove\_empty\_sites = TRUE, return\_richness\_summary = TRUE, return\_spatial\_richness = TRUE, return\_plot = TRUE)

Arguments data (data.frame) a data.frame imported with the load\_faunabr function or gener- ated by either select\_fauna or subset\_fauna functions by\_state (logical) get occurrences by State. Default = TRUE by\_country (logical) get occurrences by countries. Default = FALSE remove\_empty\_sites (logical) remove empty sites (sites without any species) from final presence- absence matrix. Default = TRUE

_fauna\_pam_ 9

return\_richness\_summary (logical) return a data.frame with the number of species in each site. Default = TRUE return\_spatial\_richness (logical) return a SpatVector with the number of species in each site. Default = TRUE return\_plot (logical) plot map with the number of species in each site. Only works if re- turn\_spatial\_richness = TRUE. Default = TRUE

Value

If return\_richness\_summary and/or return\_spatial\_richness is set to TRUE, return a list with:

•PAM: the presence-absence matrix (PAM) •Richness\_summary: a data.frame with the number of species in each site •Spatial\_richness: a SpatVector with the number of species in each site (by State and/or coun- try)

If return\_richness\_summary and return\_spatial\_richness is set to FALSE, return a presence-absence matrix

Examples

#Test function data("fauna\_data") #Load fauna e Funga do Brasil data #Select native species of mammals with occurrence only in Brazil br\_mammals <- select\_fauna(data = fauna\_data, include\_subspecies = FALSE, phylum = "all", class = "Mammalia", order = "all", family = "all", genus = "all", lifeForm = "all", filter\_lifeForm = "in", habitat = "all", filter\_habitat = "in", states = "all", filter\_states = "in", country = "BR", filter\_country = "only", origin = "all", taxonomicStatus = "valid") #Get presence-absence matrix in states pam\_mammals <- fauna\_pam(data = br\_mammals, by\_state = TRUE, by\_country = FALSE, remove\_empty\_sites = TRUE, return\_richness\_summary = TRUE, return\_spatial\_richness = TRUE, return\_plot = TRUE)

10 _fauna\_spat\_occ_

fauna\_spat\_occ Get Spatial polygons (SpatVectors) of species based on its distribution (states and countrys) according to Fauna do Brasil

Description Get Spatial polygons (SpatVectors) of species based on its distribution (states and countrys) accord- ing to Fauna do Brasil

Usage fauna\_spat\_occ(data, species, state = TRUE, country = TRUE, spat\_state = NULL, spat\_country = NULL, verbose = TRUE)

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. species (character) one or more species names (only genus and specific epithet, eg. "Panthera onca") state (logical) get SpatVector of states with occurrence of the species? Default = TRUE country (logical) get SpatVector of countrys with occurrence of the species? Default = TRUE spat\_state (SpatVector) a SpatVector of the Brazilian states. By default, it uses the SpatVec- tor provided by geobr::read\_state(). It can be another Spatvector, but the struc- ture must be identical to ’faunabr::states’, with a column called "abbrev\_state" identifying the states codes. spat\_country (SpatVector) a SpatVector of the world countries. By default, it uses the SpatVec- tor provided by rnaturalearth::ne\_countries. It can be another Spatvector, but the structure must be identical to ’faunabr::world\_fauna’, with a column called "country\_code" identifying the country codes. verbose (logical) Whether to display species being filtered during function execution. Set to TRUE to enable display, or FALSE to run silently. Default = TRUE.

Value A list with SpatVectors of states and/or countrys for each specie.

Examples library(terra) data("fauna\_data") spp <- c("Panthera onca", "Mazama jucunda") #Get states, countrys and intersection states-countrys of species spp\_spt <- fauna\_spat\_occ(data = fauna\_data, species = spp, state = TRUE, country = TRUE, verbose = TRUE)

_fauna\_synonym_ 11

#Plot states with confirmed occurrence of Panthera onca and Mazama jucunda plot(spp\_spt$`Panthera onca`$states) plot(spp\_spt$`Mazama jucunda`$states) #Plot countries with confirmed occurrence of Panthera onca and Mazama jucunda plot(spp\_spt$`Panthera onca`$countries) plot(spp\_spt$`Mazama jucunda`$countries)

fauna\_synonym Retrieve synonyms for species

Description Retrieve synonyms for species

Usage fauna\_synonym(data, species, include\_subspecies = TRUE)

Arguments data (data.frame) the data.frame imported with the load\_faunabr function species (character) names of the species include\_subspecies (logical) include subspecies that are synonyms of the species? Default = TRUE

Value A data.frame containing unique synonyms of the specified species along with relevant information on taxonomic status.

Examples data("fauna\_data") #Load Flora e Funga do Brasil data #Species to extract synonyms spp <- c("Panthera onca", "Mazama jucunda", "Subulo gouzoubira") spp\_synonyms <- fauna\_synonym(data = fauna\_data, species = spp, include\_subspecies = FALSE) spp\_synonyms

12 _filter\_faunabr_

fauna\_version Check if you have the latest version of Fauna do Brasil data available

Description This function checks if you have the latest version of the Fauna do Brasil data available in a specified directory.

Usage fauna\_version(data\_dir)

Arguments data\_dir the directory where the data should be located.

Value A message informing whether you have the latest version of Fauna do Brasil available in the data\_dir

Examples #Check if there is a version of Fauna do Brasil data available in the #current directory fauna\_version(data\_dir = getwd())

filter\_faunabr Identify records outside natural ranges according to Fauna do Brasil

Description This function removes or flags records outside of the species’ natural ranges according to informa- tion provided by the Fauna do Brasil database

Usage filter\_faunabr(data, occ, species = "species", long = "x", lat = "y", by\_state = TRUE, buffer\_state = 20, by\_country = TRUE, buffer\_country = 20, value = "flag&clean", keep\_columns = TRUE, spat\_state = NULL, spat\_country = NULL, verbose = TRUE)

_filter\_faunabr_ 13

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. occ (data.frame) a data.frame with the records of the species. species (character) column name in occ with species names. Default = "species" long (character) column name in occ with longitude data. Default = "x" lat (character) column name in occ with latitude data. Default = "y" by\_state (logical) filter records by state? Default = TRUE buffer\_state (numeric) buffer (in km) around the polygons of the states of occurrence of the specie. Default = 20. by\_country (logical) filter records by country? Default = TRUE buffer\_country (numeric) buffer (in km) around the polygons of the countries of occurrence of the specie. Default = 20. value (character) Defines output values. See Value section. Default = "flag&clean". keep\_columns (logical) if TRUE, keep all the original columns of the input occ. If False, keep only the columns species, long and lat. Default = TRUE spat\_state (SpatVector) a SpatVector of the Brazilian states. By default, it uses the SpatVec- tor provided by geobr::read\_state(). It can be another Spatvector, but the struc- ture must be identical to ’faunabr::states’, with a column called "abbrev\_state" identifying the states codes. spat\_country (SpatVector) a SpatVector of the world countries. By default, it uses the SpatVec- tor provided by rnaturalearth::ne\_countries. It can be another Spatvector, but the structure must be identical to ’faunabr::world\_fauna’, with a column called "country\_code" identifying the country codes. verbose (logical) Whether to display species being filtered during function execution. Set to TRUE to enable display, or FALSE to run silently. Default = TRUE.

Details If by\_state = TRUE and/or by\_country = TRUE, the function takes polygons representing the states and/or countrys with confirmed occurrences of the specie, draws a buffer around the polygons, and tests if the records of the species fall inside it.

Value Depending on the ’value’ argument. If value = "flag", it returns the same data.frame provided in data with additional columns indicating if the record falls inside the natural range of the specie (TRUE) or outside (FALSE). If value = "clean", it returns a data.frame with only the records that passes all the tests (TRUE for all the filters). If value = "flag&clean" (Default), it returns a list with two data.frames: one with the flagged records and one with the cleaned records.

Examples data("fauna\_data") #Load fauna e Funga do Brasil data data("occurrences") #Load occurrences pts <- subset(occurrences, species == "Panthera onca")

14 _get\_faunabr_

fd <- filter\_faunabr(data = fauna\_data, occ = pts, long = "x", lat = "y", species = "species", by\_state = TRUE, buffer\_state = 20, by\_country = TRUE, buffer\_country = 20, value = "flag&clean", keep\_columns = TRUE, verbose = FALSE)

get\_faunabr Download the latest version of Catálogo Taxonômico da Fauna do Brasil

Description This function downloads the latest or an older version of Catálogo Taxonômico da Fauna do Brasil database, merges the information into a single data.frame, and saves this data.frame in the specified directory.

Usage get\_faunabr(output\_dir, data\_version = "latest", solve\_discrepancies = TRUE, translate = TRUE, overwrite = TRUE, verbose = TRUE)

Arguments output\_dir (character) a directory to save the data downloaded from Fauna do Brasil data\_version (character) Version of the Fauna do Brasil database to download. Use "latest" to get the most recent version, which is updated frequently. Alternatively, specify an older version (e.g., data\_version = "1.2").Default value is "latest". solve\_discrepancies Resolve inconsistencies between species and subspecies information. When set to TRUE (default), species information is updated based on unique data from subspecies. For example, if a subspecies occurs in a certain state, it implies that the species also occurs in that state. translate (logical) whether to translate the original dataset ("lifeForm", "origin", "habitat", and "taxonRank") from Portuguese to English. Default is TRUE. overwrite (logical) If TRUE, data is overwritten. Default = TRUE. verbose (logical) Whether to display messages during function execution. Set to TRUE to enable display, or FALSE to run silently. Default = TRUE.

Value The function downloads the latest version of the Catálogo Taxonômico da Fauna do Brasil database from the official source. It then merges the information into a single data.frame, containing details on species, taxonomy, occurrence, and other relevant data. The merged data.frame is then saved as a file in the specified output directory. The data is saved in a format that allows easy loading using the load\_faunabr function for further analysis in R.

_load\_faunabr_ 15

References Brazilian Zoology Group. Catálogo Taxonômico da Fauna do Brasil. Available at: [https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo\_taxonomico\_da\_fauna\_do\_brasil](https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil)

Examples ## Not run: #Creating a folder in a temporary directory #Replace'file.path(tempdir(), "faunaabr")' by a path folder to be create in #your computer my\_dir <- file.path(file.path(tempdir(), "faunabr")) dir.create(my\_dir) #Download, merge and save data get\_faunabr(output\_dir = my\_dir)

## End(Not run)

load\_faunabr Load Brazilian Fauna database

Description Load Brazilian Fauna database

Usage load\_faunabr(data\_dir, data\_version = "latest", type = "short", verbose = TRUE, encoding = "UTF-8")

Arguments data\_dir (character) the same directory used to save the data downloaded from Brazilian Fauna using theget\_faunabrfunction. data\_version (character) the version of Brazilian Fauna database to be loaded. It can be "lat- est", which will load the latest version available; or another specified version, for example "1.2". Default = "latest". type (character) it determines the number of columns that will be loaded. It can be "short" or "complete". Default = "short". See details. verbose (logical) Whether to display messages during function execution. Set to TRUE to enable display, or FALSE to run silently. Default = TRUE. encoding (character) the declared encodings for special characters. Character strings in R can be declared to be encoded in "latin1" or "UTF-8". Default: "UTF-8".

Details The parameter type accepts two arguments. If type = short, it will load a data.frame with the 20 columns needed to run the other functions of the package: species, subspecies, scientificName, validName, kingdom, phylum, class, order, family, genus, lifeForm, habitat, states, countryCode, origin, taxonomicStatus, nomenclaturalStatus, vernacularName, and taxonRank. If type = com- plete, it will load a data.frame with all 31 variables available in Brazilian Fauna database.

16 _map\_translation_

Value A data.frame with the specified version (Default is the latest available) of the Brazilian Fauna database. This data.frame is necessary to run most of the functions of the package.

References Brazilian Zoology Group. Catálogo Taxonômico da Fauna do Brasil. Available at: [https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo\_taxonomico\_da\_fauna\_do\_brasil](https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil)

Examples ## Not run: #Creating a folder in a temporary directory #Replace'file.path(tempdir(), "faunabr")' by a path folder to be create in #your computer my\_dir <- file.path(file.path(tempdir(), "faunabr")) dir.create(my\_dir) #Download, merge and save data get\_fauna(output\_dir = my\_dir, data\_version = "latest", overwrite = TRUE, verbose = TRUE) #Load data df <- load\_faunabr(data\_dir = my\_dir, data\_version = "latest", type = "short")

## End(Not run)

map\_translation Helpers for translating data

Description A list of data.frames used by faunabr::translate\_faunabr() function. faunabr::map\_translation.

Usage data(map\_translation)

Format A list with 5 data.frames ("lifeForm", "origin", "habitat", "taxonRank", and "taxonomicStatus"). Each data.frame has 2 columns:

pt\_br The attribute in Brazilian Portuguese. en The attribute in English.

_occurrences_ 17

occurrences Records of animal species

Description A dataset containing records of 2 species downloaded from GBIF, with additional fake data. The records were obtained with plantR::rgbif2

Usage data(occurrences)

Format A data.frame with 2798 rows and 3 variables:

species Species names (Panthera onca and Chaetomys subspinosus) x Longitude y Latitude source record downloaded from GBIF or fake data

References GBIF, 2024. florabr R package: Records of plant species. [https://doi.org/10.15468/DD.QPGEB7](https://doi.org/10.15468/DD.QPGEB7)

select\_fauna Selection of species based on its characteristics and distribution

Description select\_fauna allows filter species based on its characteristics and distribution available in Brazilian Fauna

Usage select\_fauna(data, include\_subspecies = FALSE, phylum = "all", class = "all", order = "all", family = "all", genus = "all", lifeForm = "all", filter\_lifeForm = "in", habitat = "all", filter\_habitat = "in", states = "all", filter\_states = "in", country = "all", filter\_country = "in", origin = "all", taxonomicStatus = "valid")

18 _select\_fauna_

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. include\_subspecies (logical) include subspecies? Default = FALSE phylum (character) The phyla for filtering the dataset. It can be included more than one phylum. Default = "all". class (character) The classes for filtering the dataset. It can be included more than one class. Default = "all". order (character) The orders for filtering the dataset. It can be included more than one order. Default = "all". family (character) The families for filtering the dataset. It can be included more than one family. Default = "all". genus (character) The genus for filtering the dataset. It can be included more than one genus. Default = "all". lifeForm (character) The life forms for filtering the dataset. It can be included more than one lifeForm. Default = "all" filter\_lifeForm (character) The type of filtering for life forms. It can be "in", "only", "not\_in" and "and". See details for more about this argument. habitat (character) The life habitat for filtering the dataset. It can be included more than one habitat. Default = "all" filter\_habitat (character) The type of filtering for habitat. It can be "in", "only", "not\_in" and "and". See details for more about this argument. states (character) The states for filtering the dataset. It can be included more than one state. Default = "all". filter\_states (character) The type of filtering for states. It can be "in", "only", "not\_in" and "and". See Details for more about this argument. country (character) The country or countries with confirmed occurrences for filtering the dataset. It can be included more than one country. Default = "all". filter\_country (character) The type of filtering for country. It can be "in", "only", "not\_in" and "and". See details for more about this argument. origin (character) The origin for filtering the dataset. It can be "native", "introduced", "cryptogenic", "domesticaded" and "invasora". Default = "all". taxonomicStatus (character) The taxonomic status for filtering the dataset. It can be "valid", "syn- onym" or "all". Default = "valid".

Details It’s possible to choose 4 ways to filter by lifeform, by habitat, by states and by country: "in": selects species that have any occurrence of the determined values. It allows multiple matches. For example, if country = c("brazil", argentina") and filter\_country = "in", it will select all species that occur in Brazil and/or Argentina, some of which may also occur in other countries.

_states_ 19

"only": selects species that have only occurrence of the determined values. It allows only single matches. For example, if country = c("brazil", argentina") and filter\_country = "in", it will select all species that occur exclusively in both countries, without any occurrences in other countries. "not\_in": selects species that don’t have occurrence of the determined values. It allows single and multiple matches. For example, if country = c("brazil", argentina") and filter\_country = "not\_in", it will select all species without occurrences in Brazil and Argentina. "and": selects species that have occurrence in all determined values. It allows single and multiple matches. For example, if country = c("brazil", argentina") and filter\_country = "and", it will select all species that occurs only in both countries,including species that occurs in other countries too. To get the complete list of arguments available for phylum, class, order, family, genus, lifeForm, habitat, states, country and origins, use the function fauna\_attributes

Value A new dataframe with the filtered species.

References Brazilian Zoology Group. Catálogo Taxonômico da Fauna do Brasil. Available at: [https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo\_taxonomico\_da\_fauna\_do\_brasil](https://ipt.jbrj.gov.br/jbrj/resource?r=catalogo_taxonomico_da_fauna_do_brasil)

Examples data("fauna\_data") #Load data example #Select endemic and native species of birds (Aves) with confirmed occurrence #in Brazil or Argentina aves\_br\_ar <- select\_fauna(data = fauna\_data, include\_subspecies = FALSE, phylum = "all", class = "Aves", order = "all", family = "all", genus = "all", lifeForm = "all", filter\_lifeForm = "in", habitat = "all", filter\_habitat = "in", states = "all", filter\_states = "in", country = c("BR", "AR"), filter\_country = "in", origin = "native", taxonomicStatus = "valid")

states SpatVector of the federal states of Brazil

Description A simplified and packed SpatVector of the polygons of the federal states of Brazil. The spatial data was originally obtained from geobr::read\_state. Borders have been simplified by remov- ing vertices of borders using terra::simplifyGeom. It’s necessary unpack the Spatvectos using terra::unwrap @usage data(states) states <- terra::unwrap(states)

20 _subset\_fauna_

Usage states

Format A SpatVector with 27 geometries and 3 attributes:

abbrev\_state State acronym name\_state State’s full name name\_region The region to which the state belongs

subset\_fauna Extract a subset of species from Fauna do Brasil database

Description Returns a data.frame with a subset of species from Fauna do Brasil database

Usage subset\_fauna(data, species, include\_subspecies = FALSE)

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. species (character) names of the species to be extracted from Fauna do Brasil database. include\_subspecies (logical) include subspecies? Default = FALSE

Value A data.frame with the selected species.

Examples data("fauna\_data") #Load data example #Species to extract from database spp <- c("Panthera onca", "Mazama jucunda", "Subulo gouzoubira") spp\_subset <-subset\_fauna(data = fauna\_data, species = spp, include\_subspecies = FALSE) spp\_subset

_translate\_faunabr_ 21

translate\_faunabr Translate information in Brazilian Fauna database

Description This function translates information in the "lifeForm", "origin", "habitat", "taxonRank", and "taxo- nomicStatus" columns between Portuguese and English.

Usage translate\_faunabr(data, map\_list = NULL, to = "en")

Arguments data (data.frame) the data.frame imported with the load\_faunabr function. map\_list (list) A list of data.frames used for translation. The default is NULL, which means it uses faunabr::map\_translation. If not NULL, its structure (list names and data.frame column names) must be identical to faunabr::map\_translation. to (character) The target language for translation. Available options are "en" to translate from Portuguese to English, and "pt\_br" to translate from English to Portuguese. The default is "en".

Value A data.frame with the values in the "lifeForm", "origin", "habitat", "taxonRank", and "taxonomic- Status" columns translated.

Examples data("fauna\_data") #Load data example (in English) #Translate to Portuguese fauna\_portugues <- translate\_faunabr(data = fauna\_data, to = "pt\_br") # See attributes of lifeForm in Portuguese fauna\_attributes(fauna\_portugues, attribute = "lifeForm")

world\_fauna SpatVector of the world countries

Description A simplified and packed SpatVector of the world country polygons. The spatial data was orig- inally obtained from rnaturalearth::ne\_countries. Borders have been simplified by remov- ing vertices of borders using terra::simplifyGeom.It’s necessary unpack the Spatvectos using terra::unwrap @usage data(world\_fauna) biomes <- terra::unwrap(world\_fauna)

22 _world\_fauna_

Usage world\_fauna

Format A SpatVector with 258 geometries and 1 attribute: name The name of the country (argentina, brazil, colombia, etc.)

# Index

∗ datasets country\_codes,3 fauna\_data,6 map\_translation,16 occurrences,17 states,19 world\_fauna,21

agrep, 2

check\_fauna\_names,2 country\_codes,3

extract\_binomial,4

fauna\_attributes,5, 19 fauna\_by\_vernacular,5 fauna\_data,6 fauna\_discrepancies,7 fauna\_pam,8 fauna\_spat\_occ,10 fauna\_synonym,11 fauna\_version,12 filter\_faunabr,12

get\_faunabr,14, 15

load\_faunabr, 2, 5–8, 10,11, 13,14,15, 18, 20,21

map\_translation,16

occurrences,17

select\_fauna, 5,6, 8,17 states,19 subset\_fauna, 8,20

translate\_faunabr,21

world\_fauna,21