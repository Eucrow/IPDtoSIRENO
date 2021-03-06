#### IPDtoSIRENO
#### Script to check the monthly data dump from IPD database previous to SIRENO upload
####
#### Return csv files with errors detected
####
#### author: Marco A. Ámez Fernandez
#### email: ieo.marco.a.amez@gmail.com
####
#### files required: file from IPD with data to save in SIRENO and IPD_to_SIRENO.R
#### with all the functions used in this script


# ··············································································
# PACKAGES ---------------------------------------------------------------------
# ··············································································
library(plyr) # It's better to load plyr before dplyr
library(dplyr)
library(tools) #file_ext()
#library(stringr) #str_split()
library(devtools) # Need this package to use install and install_github

# ---- install sapmuebase from local
#remove.packages("sapmuebase")
#.rs.restartR()
#install("F:/misdoc/sap/sapmuebase")
# ---- install sapmuebase from github
#remove.packages("sapmuebase")
#install_github("Eucrow/sapmuebase")

library(sapmuebase) # and load the library

# ---- install openxlsx
#install.packages("openxlsx")
library(openxlsx)


# ··············································································
# GLOBAL VARIABLES -------------------------------------------------------------
# ··············································································
ERRORS <- list() #list with all errors found in dataframes
#MESSAGE_ERRORS<- list() #list with the errors

################################################################################
# YOU HAVE ONLY TO CHANGE THIS VARIABLES:                                      #

PATH_FILES <- file.path(getwd(), "data/2019/2019_12")

FILENAME <- "muestreos_12_ICES.txt"

MONTH <- 12

YEAR <- "2019"

#                                                                              #
################################################################################

PATH_FILE <- getwd()
MONTH_STRING <- sprintf("%02d", MONTH)
LOG_FILE <- paste("LOG_", YEAR, "_", MONTH_STRING, ".csv", sep="")
PATH_LOG_FILE <- file.path(paste(PATH_FILES, LOG_FILE, sep = "/"))
PATH_BACKUP_FILE <- file.path(paste(PATH_FILES, "backup", sep = "/"))
PATH_ERRORS <- paste(PATH_FILES,"/errors",sep="")


# ··············································································
# CONSTANS ---------------------------------------------------------------------
# ··············································································
# list with the common fields used in all tables
BASE_FIELDS <- c("COD_PUERTO", "FECHA", "COD_BARCO", "ESTRATO_RIM", "COD_TIPO_MUE")


# ··············································································
# FUNCTIONS --------------------------------------------------------------------
# ··············································································
# All the functions required in this script are located in
# revision_volcado_functions.R file.
source('rim_pre_dump_functions.R')


# ··············································································
# IMPORT FILE ------------------------------------------------------------------
# ··············································································
records <- importIPDFile(FILENAME, by_month = MONTH, path = PATH_FILES)


# ··············································································
# EXPORT FILE TO CSV -----------------------------------------------------------
# ··············································································
file_name <- unlist(strsplit(FILENAME, '.', fixed = T))
file_name <- paste0(file_name[1], '_raw_imported.csv')

exportCsvSAPMUEBASE(records, file_name, path = PATH_FILES)

# ··············································································
# #### START CHECK -------------------------------------------------------------
# ··············································································
# if any error is detected use function:
# correct_levels_in_variable(df, variable, erroneus_data, correct_data, conditional_variables, conditions)
# to fix it. This function return the 'df' already corrected, so you have to assign
# the data returned to the records dataframe: records <- correct_level_in_variable.

check_mes <- check_month(records)


check_estrato_rim <- check_variable_with_master("ESTRATO_RIM", records)


check_puerto <- check_variable_with_master("COD_PUERTO", records)


check_arte <- check_variable_with_master("COD_ARTE", records)
#there are two "miño" 208 gears. I change it to "beta" 201
records <- correct_levels_in_variable(records, "COD_ARTE", "208", "201")


check_origen <- check_variable_with_master("COD_ORIGEN", records)


check_procedencia <- check_variable_with_master("PROCEDENCIA", records)


check_tipo_muestreo <- check_type_sample(records)
# TO DO: when correct_levels_in_variable doesn'f find any erroenus data, return
# an error. Fix it.
# records <- correct_levels_in_variable(records, "ESTRATEGIA", "CONCURRENTE EN LONJA", "EN BASE A ESPECIE", "ESTRATO_RIM", "VORACERA_GC")


check_duplicados_tipo_muestreo <- check_duplicates_type_sample(records)


check_falsos_mt2 <- check_false_mt2(records)


check_falsos_mt1 <- check_false_mt1(records)

check_barcos_extranjeros <- check_foreing_ship(records)
# The function remove_MT1_trips_foreing_vessels(df) remove all the MT1 trips
# with foreing vessels.
# There are one foreing vessel, so:
# records <- remove_MT1_trips_foreing_vessels(records)

check_especies_mezcla_no_mezcla <- check_mixed_as_no_mixed(records)

check_especies_no_mezcla_mezcla <- check_no_mixed_as_mixed(records)

check_categorias <- check_categories(records)
check_categorias <- humanize(check_categorias)
# all this categories are correct

check_ejemplares_medidos_na <- check_measured_individuals_na(records)
# if any EJEM_MEDIDOS is NA, must be change to 0.
# TODO: make a funtcion to fix it automaticaly
# records <- records[which(!is.na(records$EJEM_MEDIDOS)),]

# Sometimes, one category with various species of the category has various landing weights.
# This is not possible to save it in SIRENO, so with one_category_with_different_landing_weights(df)
# function this mistakes are detected. This errors are separated by influece area and
# must be send to the sups to fix it after save it in SIRENO
check_one_category_with_different_landing_weights <- one_category_with_different_landing_weights(records)

# Create files to send to sups:
check_one_category_with_different_landing_weights <- humanize(check_one_category_with_different_landing_weights)
  errors_category <- separateDataframeByInfluenceArea(check_one_category_with_different_landing_weights, "COD_PUERTO")
  #remove empty dataframes from list:
  errors_category <- Filter(function(x){
                              nrow(x) > 0
                            }, errors_category)
  
  suf <- paste("_", YEAR, MONTH, "_errors_categorias_con_varios_pesos_desembarcados", sep="_")

  exportListToCsv(errors_category, suffix = suf, path = PATH_FILES)


# All the data saved by IPD are lenthts samples so the MEDIDA variable can't be "P" ("Pesos", weights)
# or empty. The function fix_medida_variable(df) fix it:
records <- fix_medida_variable(records)

# By default, the IPD file hasn't the country variable filled. The
# create_variable_code_country(df) funcion fix it:
records <- create_variable_code_country(records)

#check if there are any vessel register without COD_PAIS
unique(records[is.na(records$COD_PAIS),c("COD_BARCO")])
# First, I check in SIRENO if this vessels are in the fleet master. In this case,
# all of them are.
# So this vessels must be saved in SIRENO with 724 code country, so change it:
records[is.na(records$COD_PAIS),c("COD_PAIS")] <- 724
export_log_file("Change", "COD_PAIS", "NA", "724")


# Change the 000000 COD_BARCO ('DESCONOCIDO' ship) from VORACERA_GC with 205509
# ('DESCONOCIDO VORAZ LONJA')
records <- recode000000Ship(records)


# source: https://github.com/awalker89/openxlsx/issues/111
Sys.setenv("R_ZIPCMD" = "C:/Rtools/bin/zip.exe") ## path to zip.exe
export_to_excel(records)
