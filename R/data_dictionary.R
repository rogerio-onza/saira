# Title: Translation Dictionary (i18n)
# Author: Rog\u00E9rio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Translation Dictionary
#'
#' Named list containing all UI strings in Portuguese (pt) and English (en)
#'
#' @format List of named lists with pt and en keys
i18n_dict <- list(
    # App Title
    app_title = list(
        pt = "Finch - Padroniza\u00E7\u00E3o DwC",
        en = "Finch - DwC Standardization"
    ),

    # Navigation
    nav_home = list(pt = "In\u00EDcio", en = "Home"),
    nav_upload = list(pt = "Upload", en = "Upload"),
    nav_mapping = list(pt = "Mapeamento", en = "Mapping"),
    nav_preview = list(pt = "Pr\u00E9-visualiza\u00E7\u00E3o", en = "Preview"),
    nav_validate = list(pt = "Valida\u00E7\u00E3o", en = "Validation"),
    nav_validate_names = list(pt = "Nomes", en = "Names"),
    nav_validate_coords = list(pt = "Coordenadas", en = "Coordinates"),
    nav_wiki = list(pt = "Wiki DwC", en = "DwC Wiki"),
    nav_help = list(pt = "Ajuda", en = "Help"),

    # Language selector
    lang_select = list(pt = "Idioma", en = "Language"),
    lang_pt = list(pt = "Portugu\u00EAs", en = "Portuguese"),
    lang_en = list(pt = "English", en = "English"),
    lang_es = list(pt = "Espanhol", en = "Spanish"),
    # Upload Module
    upload_title = list(
        pt = "Carregar Dados",
        en = "Upload Data"
    ),
    upload_subtitle = list(
        pt = "Selecione um arquivo CSV com seus dados de biodiversidade",
        en = "Select a CSV file with your biodiversity data"
    ),
    upload_button = list(
        pt = "Selecionar arquivo CSV",
        en = "Select CSV file"
    ),
    upload_success = list(
        pt = "Arquivo carregado com sucesso!",
        en = "File uploaded successfully!"
    ),
    upload_stats_rows = list(pt = "Registros", en = "Records"),
    upload_stats_cols = list(pt = "Colunas", en = "Columns"),
    upload_stats_size = list(pt = "Tamanho", en = "Size"),

    # Mapping Module
    mapping_title = list(
        pt = "Mapeamento de Colunas",
        en = "Column Mapping"
    ),
    mapping_subtitle = list(
        pt = "Associe suas colunas aos termos Darwin Core",
        en = "Map your columns to Darwin Core terms"
    ),
    mapping_source = list(pt = "Coluna Original", en = "Source Column"),
    mapping_target = list(pt = "Termo DwC", en = "DwC Term"),
    mapping_auto = list(pt = "Auto-mapear", en = "Auto-map"),
    mapping_clear = list(pt = "Limpar", en = "Clear"),
    mapping_unmapped = list(pt = "-- N\u00E3o mapeado --", en = "-- Not mapped --"),
    mapping_sidebar_title = list(pt = "Ferramentas", en = "Tools"),
    mapping_required = list(pt = "Obrigat\u00F3rio", en = "Required"),
    mapping_optional = list(pt = "Opcional", en = "Optional"),

    # Mapping Module - New keys for enhanced version
    stats_mapped_fields = list(pt = "Campos Mapeados", en = "Mapped Fields"),
    stats_total_dwc_fields = list(pt = "Total de Campos DwC", en = "Total DwC Fields"),
    btn_auto_mapping = list(pt = "Auto-mapear", en = "Auto-map"),
    btn_reset = list(pt = "Resetar", en = "Reset"),
    filter_mapped_only = list(pt = "Mostrar apenas mapeados", en = "Show mapped only"),
    filter_categories = list(pt = "Filtrar por categoria", en = "Filter by category"),
    filter_select_all = list(pt = "Selecionar todos", en = "Select all"),
    toggle_automap_v1_label = list(
        pt = "Rostrum (beta)",
        en = "Rostrum (beta)"
    ),
    toggle_automap_v1_help = list(
        pt = "Motor propriet\u00E1rio para mapear colunas da planilha aos termos DwC.",
        en = "Proprietary engine to map spreadsheet columns to DwC terms."
    ),
    bor_assistant_button = list(
        pt = "Assistente basisOfRecord",
        en = "basisOfRecord Assistant"
    ),
    bor_assistant_title = list(
        pt = "Assistente de mapeamento basisOfRecord",
        en = "basisOfRecord mapping assistant"
    ),
    bor_assistant_subtitle = list(
        pt = "Mapeie cada valor bruto para um termo oficial DwC (um valor por linha).",
        en = "Map each raw value to an official DwC term (single value per row)."
    ),
    bor_assistant_save = list(
        pt = "Salvar mapeamento",
        en = "Save mapping"
    ),
    bor_assistant_saved = list(
        pt = "Assistente basisOfRecord salvo: %s/%s valores mapeados.",
        en = "basisOfRecord assistant saved: %s/%s values mapped."
    ),
    bor_assistant_skip_option = list(
        pt = "-- N\u00E3o mapear --",
        en = "-- Skip --"
    ),
    bor_assistant_col_raw = list(
        pt = "Valor bruto",
        en = "Raw value"
    ),
    bor_assistant_col_target = list(
        pt = "Destino DwC",
        en = "DwC target"
    ),
    bor_assistant_progress = list(
        pt = "%s/%s valores mapeados",
        en = "%s/%s values mapped"
    ),
    bor_assistant_no_values = list(
        pt = "N\u00E3o h\u00E1 valores n\u00E3o vazios para mapear nesta coluna.",
        en = "There are no non-empty values to map in this column."
    ),
    bor_assistant_preview_title = list(
        pt = "Preview ao vivo (primeiras 5 linhas)",
        en = "Live preview (first 5 rows)"
    ),
    bor_assistant_preview_original = list(
        pt = "Original",
        en = "Original"
    ),
    bor_assistant_preview_result = list(
        pt = "Resultado DwC",
        en = "DwC result"
    ),
    bor_assistant_empty_value = list(
        pt = "(vazio)",
        en = "(empty)"
    ),
    bor_assistant_unmapped_rows = list(
        pt = "Linhas n\u00E3o mapeadas (valor bruto n\u00E3o vazio): %s",
        en = "Unmapped rows (non-empty raw value): %s"
    ),
    bor_assistant_page = list(
        pt = "P\u00E1gina %s de %s",
        en = "Page %s of %s"
    ),
    bor_assistant_prev = list(
        pt = "Anterior",
        en = "Previous"
    ),
    bor_assistant_next = list(
        pt = "Pr\u00F3xima",
        en = "Next"
    ),
    bor_assistant_select_column_first = list(
        pt = "Selecione uma coluna para basisOfRecord antes de abrir o assistente.",
        en = "Select a basisOfRecord source column before opening the assistant."
    ),
    bor_assistant_open_error = list(
        pt = "Falha ao abrir o assistente basisOfRecord: %s",
        en = "Failed to open basisOfRecord assistant: %s"
    ),
    bor_vocab_preservedspecimen = list(
        pt = "Esp\u00E9cime Preservado",
        en = "Preserved Specimen"
    ),
    bor_vocab_fossilspecimen = list(
        pt = "Esp\u00E9cime F\u00F3ssil",
        en = "Fossil Specimen"
    ),
    bor_vocab_livingspecimen = list(
        pt = "Esp\u00E9cime Vivo",
        en = "Living Specimen"
    ),
    bor_vocab_humanobservation = list(
        pt = "Observa\u00E7\u00E3o por Humano",
        en = "Human Observation"
    ),
    bor_vocab_machineobservation = list(
        pt = "Observa\u00E7\u00E3o por M\u00E1quina",
        en = "Machine Observation"
    ),
    bor_vocab_materialsample = list(
        pt = "Amostra",
        en = "Material Sample"
    ),
    bor_vocab_materialcitation = list(
        pt = "Cita\u00E7\u00E3o de Material",
        en = "Material Citation"
    ),
    bor_vocab_occurrence = list(
        pt = "Ocorr\u00EAncia",
        en = "Occurrence"
    ),
    bor_desc_preservedspecimen = list(
        pt = "Esp\u00E9cime preservado em cole\u00E7\u00E3o biol\u00F3gica.",
        en = "Specimen preserved in a biological collection."
    ),
    bor_desc_fossilspecimen = list(
        pt = "Esp\u00E9cime preservado que \u00E9 f\u00F3ssil.",
        en = "Preserved specimen that is a fossil."
    ),
    bor_desc_livingspecimen = list(
        pt = "Esp\u00E9cime atualmente vivo.",
        en = "Specimen that is currently alive."
    ),
    bor_desc_humanobservation = list(
        pt = "Observa\u00E7\u00E3o direta realizada por pessoa.",
        en = "Direct observation performed by a person."
    ),
    bor_desc_machineobservation = list(
        pt = "Observa\u00E7\u00E3o gerada por c\u00E2mera, sensor ou gravador.",
        en = "Observation produced by camera, sensor, or recorder."
    ),
    bor_desc_materialsample = list(
        pt = "Resultado f\u00EDsico obtido em evento de amostragem.",
        en = "Physical result obtained from a sampling event."
    ),
    bor_desc_materialcitation = list(
        pt = "Refer\u00EAncia a material citado em publica\u00E7\u00F5es.",
        en = "Reference to material cited in publications."
    ),
    bor_desc_occurrence = list(
        pt = "Registro de exist\u00EAncia de organismo em lugar e tempo.",
        en = "Record of organism existence at place and time."
    ),
    loading_automap_title = list(
        pt = "Rostrum em andamento",
        en = "Rostrum in progress"
    ),
    loading_automap_status = list(
        pt = "Mapeando campos... %s%%",
        en = "Mapping fields... %s%%"
    ),
    loading_automap_phrase_1 = list(
        pt = "Traduzindo o dialeto da sua planilha para Darwin Core...",
        en = "Translating your spreadsheet dialect to Darwin Core..."
    ),
    loading_automap_phrase_2 = list(
        pt = "Identificando homologias entre seus dados e o padr\u00E3o DwC.",
        en = "Identifying homologies between your data and the DwC standard."
    ),
    loading_automap_phrase_3 = list(
        pt = "A sele\u00E7\u00E3o natural das colunas est\u00E1 come\u00E7ando...",
        en = "Natural selection of columns is starting..."
    ),
    loading_automap_phrase_4 = list(
        pt = "Rostrum mapeando a ancestralidade dos seus registros.",
        en = "Rostrum mapping the ancestry of your records."
    ),
    loading_automap_phrase_5 = list(
        pt = "Sobreviv\u00EAncia do mais mapeado: Rostrum em a\u00E7\u00E3o.",
        en = "Survival of the most mapped: Rostrum in action."
    ),
    loading_automap_phrase_6 = list(
        pt = "Observando a diversidade de campos como Darwin em Gal\u00E1pagos.",
        en = "Observing field diversity like Darwin in the Galapagos."
    ),
    loading_automap_phrase_7 = list(
        pt = "Muta\u00E7\u00E3o de cabe\u00E7alhos detectada. Ajustando o fen\u00F3tipo dos dados...",
        en = "Header mutation detected. Adjusting data phenotype..."
    ),
    loading_automap_phrase_8 = list(
        pt = "A \u00E1rvore da vida dos seus registros est\u00E1 sendo desenhada.",
        en = "The tree of life of your records is being drawn."
    ),
    no_file_uploaded = list(pt = "Nenhum arquivo carregado", en = "No file uploaded"),
    upload_csv_to_start = list(pt = "Fa\u00E7a upload de um CSV para come\u00E7ar", en = "Upload a CSV to start"),
    uuid_auto_generated = list(
        pt = "UUID ser\u00E1 gerado automaticamente",
        en = "UUID will be auto-generated"
    ),
    notif_auto_mapping = list(
        pt = "Auto-mapeamento conclu\u00EDdo!",
        en = "Auto-mapping completed!"
    ),
    notif_auto_mapping_v1 = list(
        pt = "Auto-map V1 conclu\u00EDdo: %s AUTO, %s SUGERIDO.",
        en = "Auto-map V1 completed: %s AUTO, %s SUGGESTED."
    ),
    notif_auto_mapping_v1_error = list(
        pt = "Falha no auto-map V1: %s",
        en = "Auto-map V1 failed: %s"
    ),
    modal_reset_title = list(pt = "Confirmar Reset", en = "Confirm Reset"),
    modal_reset_message = list(
        pt = "Tem certeza que deseja resetar todos os mapeamentos?",
        en = "Are you sure you want to reset all mappings?"
    ),
    btn_cancel = list(pt = "Cancelar", en = "Cancel"),
    btn_confirm_reset = list(pt = "Sim, resetar", en = "Yes, reset"),
    notif_mapping_reset = list(
        pt = "Mapeamentos resetados",
        en = "Mappings reset"
    ),
    notif_eventdate_parse_warning = list(
        pt = "eventDate: %s linha(s) n\u00E3o puderam ser convertidas para YYYY-MM/YYYY-MM; o valor bruto foi mantido.",
        en = "eventDate: %s row(s) could not be converted to YYYY-MM/YYYY-MM; raw value was kept."
    ),
    badge_auto = list(pt = "AUTO", en = "AUTO"),
    badge_suggested = list(pt = "SUGERIDO", en = "SUGGESTED"),
    badge_edited = list(pt = "EDITADO", en = "EDITED"),
    badge_manual = list(pt = "MANUAL", en = "MANUAL"),
    badge_reason_exact_match = list(pt = "Match exato", en = "Exact match"),
    badge_reason_known_synonym = list(pt = "Sin\u00F4nimo conhecido", en = "Known synonym"),
    badge_reason_content_validated = list(pt = "Validado por conte\u00FAdo", en = "Validated by content"),
    badge_reason_manual_adjust = list(pt = "Ajustado pelo usu\u00E1rio", en = "Adjusted by user"),
    badge_reason_manual_cleared = list(pt = "Limpo pelo usu\u00E1rio", en = "Cleared by user"),
    badge_reason_type_incompatible = list(
        pt = "Tipo incompat\u00EDvel (AUTO bloqueado)",
        en = "Type incompatible (AUTO blocked)"
    ),
    badge_reason_temporal_manual_only = list(
        pt = "Termo temporal mantido manual",
        en = "Temporal term kept manual"
    ),
    badge_reason_conflict_lost = list(
        pt = "Conflito com candidato mais forte",
        en = "Conflict lost to stronger candidate"
    ),
    badge_reason_empty_column = list(pt = "Coluna sem valores", en = "Column without values"),
    badge_reason_low_name_confidence = list(
        pt = "Baixa confian\u00E7a no nome da coluna",
        en = "Low column-name confidence"
    ),
    badge_reason_no_confident_match = list(
        pt = "Sem correspond\u00EAncia confi\u00E1vel",
        en = "No confident match"
    ),
    badge_reason_low_confidence = list(pt = "Confian\u00E7a insuficiente", en = "Insufficient confidence"),

    # Custom field inputs (Record-level)
    field_or_type_value = list(
        pt = "Ou digite/cole um valor fixo:",
        en = "Or type/paste a fixed value:"
    ),
    field_use_today_date = list(
        pt = "Usar data de hoje",
        en = "Use today's date"
    ),
    field_choose_date = list(
        pt = "Ou escolha uma data:",
        en = "Or choose a date:"
    ),
    field_choose_license = list(
        pt = "Escolha a licen\u00E7a:",
        en = "Choose the license:"
    ),
    field_choose_language = list(
        pt = "Escolha o idioma dos dados:",
        en = "Choose the data language:"
    ),
    field_map_column = list(
        pt = "Mapear coluna do CSV:",
        en = "Map CSV column:"
    ),
    mapping_dataset_placeholder = list(
        pt = "Ex: Meu Dataset de Biodiversidade",
        en = "Ex: My Biodiversity Dataset"
    ),
    mapping_separator_placeholder = list(pt = "Sep", en = "Sep"),

    # Preview Module
    preview_title = list(
        pt = "Pr\u00E9-visualiza\u00E7\u00E3o dos Dados",
        en = "Data Preview"
    ),
    preview_subtitle = list(
        pt = "Visualize os primeiros 100 registros mapeados",
        en = "View the first 100 mapped records"
    ),
    preview_stats_total_rows = list(
        pt = "Registros",
        en = "Records"
    ),
    preview_stats_with_coords = list(
        pt = "Com Coordenadas",
        en = "With Coordinates"
    ),
    preview_stats_with_date = list(
        pt = "Com Data",
        en = "With Date"
    ),
    preview_stats_unique_ids = list(
        pt = "IDs \u00DAnicos",
        en = "Unique IDs"
    ),
    preview_stats_duplicates = list(
        pt = "%s duplicatas",
        en = "%s duplicates"
    ),
    preview_readiness_title = list(
        pt = "Campos obrigat\u00F3rios",
        en = "Required fields"
    ),
    preview_readiness_present = list(
        pt = "presente",
        en = "present"
    ),
    preview_readiness_missing = list(
        pt = "ausente",
        en = "missing"
    ),
    preview_download = list(
        pt = "Baixar CSV Completo",
        en = "Download Complete CSV"
    ),
    preview_exporting = list(
        pt = "Exportando dados...",
        en = "Exporting data..."
    ),
    preview_download_validation_title = list(
        pt = "N\u00E3o foi poss\u00EDvel iniciar o download",
        en = "Could not start download"
    ),
    preview_download_validation_no_data = list(
        pt = "N\u00E3o h\u00E1 dados mapeados para exportar.",
        en = "There is no mapped data to export."
    ),
    preview_download_validation_blocking = list(
        pt = "Campos obrigat\u00F3rios ausentes para exporta\u00E7\u00E3o:",
        en = "Missing mandatory fields for export:"
    ),
    preview_download_validation_warning = list(
        pt = "Aviso: occurrenceID ausente. O sistema gerar\u00E1 UUID automaticamente no export.",
        en = "Warning: occurrenceID is missing. The system will auto-generate UUID during export."
    ),
    preview_download_confirm_title = list(
        pt = "Confirmar Download",
        en = "Confirm Download"
    ),
    preview_download_confirm_message = list(
        pt = "O tempo de processamento e download da planilha em DwC depende dos recursos dispon\u00EDveis no seu computador.",
        en = "The processing and download time for the DwC spreadsheet depends on available resources on your computer."
    ),
    preview_download_confirm_question = list(
        pt = "Deseja fazer o download agora?",
        en = "Do you want to download now?"
    ),
    preview_download_confirm_warning = list(
        pt = "Se desejar continuar, essa a\u00E7\u00E3o n\u00E3o poder\u00E1 ser bloqueada.",
        en = "If you continue, this action cannot be interrupted."
    ),
    preview_download_confirm_yes = list(
        pt = "Sim",
        en = "Yes"
    ),
    preview_download_confirm_no = list(
        pt = "N\u00E3o",
        en = "No"
    ),
    preview_export_loading_title = list(
        pt = "Preparando exporta\u00E7\u00E3o DwC",
        en = "Preparing DwC export"
    ),
    preview_export_loading_status = list(
        pt = "Preparando arquivo... %s%%",
        en = "Preparing file... %s%%"
    ),
    preview_export_phrase_1 = list(
        pt = "Verificando estrutura das colunas mapeadas.",
        en = "Checking mapped column structure."
    ),
    preview_export_phrase_2 = list(
        pt = "Conferindo consist\u00EAncia taxon\u00F4mica dos registros.",
        en = "Checking taxonomic consistency across records."
    ),
    preview_export_phrase_3 = list(
        pt = "Normalizando datas para o padr\u00E3o Darwin Core.",
        en = "Normalizing dates to Darwin Core format."
    ),
    preview_export_phrase_4 = list(
        pt = "Padronizando coordenadas geogr\u00E1ficas.",
        en = "Standardizing geographic coordinates."
    ),
    preview_export_phrase_5 = list(
        pt = "Harmonizando vocabul\u00E1rios controlados.",
        en = "Harmonizing controlled vocabularies."
    ),
    preview_export_phrase_6 = list(
        pt = "Aplicando regras de qualidade do pacote.",
        en = "Applying package quality rules."
    ),
    preview_export_phrase_7 = list(
        pt = "Compactando valores para exporta\u00E7\u00E3o segura.",
        en = "Compacting values for safe export."
    ),
    preview_export_phrase_8 = list(
        pt = "Validando integridade final do dataset.",
        en = "Validating final dataset integrity."
    ),
    preview_export_phrase_9 = list(
        pt = "Montando arquivo CSV compat\u00EDvel com DwC.",
        en = "Building DwC-compatible CSV file."
    ),
    preview_export_phrase_10 = list(
        pt = "Finalizando download.",
        en = "Finalizing download."
    ),
    preview_export_failed_phrase = list(
        pt = "Falha ao preparar arquivo para download.",
        en = "Failed to prepare file for download."
    ),
    preview_download_failed = list(
        pt = "Falha ao exportar dados: %s",
        en = "Failed to export data: %s"
    ),
    preview_no_data_title = list(
        pt = "Nenhum dado mapeado",
        en = "No mapped data"
    ),
    preview_no_data = list(
        pt = "Nenhum dado para visualizar. Fa\u00E7a o mapeamento primeiro.",
        en = "No data to display. Map your columns first."
    ),
    preview_datatable_search = list(pt = "Buscar:", en = "Search:"),
    preview_datatable_length_menu = list(pt = "Mostrar _MENU_ registros", en = "Show _MENU_ entries"),
    preview_datatable_info = list(pt = "Mostrando _START_ a _END_ de _TOTAL_ registros", en = "Showing _START_ to _END_ of _TOTAL_ entries"),
    preview_datatable_empty = list(
        pt = "Nenhum registro na tabela",
        en = "No records available"
    ),
    preview_datatable_zero_records = list(
        pt = "Nenhum registro encontrado",
        en = "No matching records found"
    ),
    preview_datatable_first = list(pt = "Primeira", en = "First"),
    preview_datatable_last = list(pt = "\u00DAltima", en = "Last"),
    preview_datatable_next = list(pt = "Pr\u00F3xima", en = "Next"),
    preview_datatable_prev = list(pt = "Anterior", en = "Previous"),

    # Validation - Names
    validate_names_title = list(
        pt = "Valida\u00E7\u00E3o Taxon\u00F4mica",
        en = "Taxonomic Validation"
    ),
    validate_names_subtitle = list(
        pt = "Verifique se os nomes cient\u00EDficos est\u00E3o corretos",
        en = "Check if scientific names are correct"
    ),
    validate_names_providers = list(
        pt = "Provedores (ordem = prioridade)",
        en = "Providers (order = priority)"
    ),
    validate_names_providers_card_title = list(
        pt = "Provedores de Dados",
        en = "Data Providers"
    ),
    validate_names_provider_gbif_full = list(
        pt = "Global Biodiversity Information Facility",
        en = "Global Biodiversity Information Facility"
    ),
    validate_names_provider_gbif_desc = list(
        pt = "Cobertura global para nomes taxonomicos e sinonimos.",
        en = "Global coverage for taxonomic names and synonyms."
    ),
    validate_names_provider_itis_full = list(
        pt = "Integrated Taxonomic Information System",
        en = "Integrated Taxonomic Information System"
    ),
    validate_names_provider_itis_desc = list(
        pt = "Fonte consolidada para taxa da America do Norte.",
        en = "Consolidated source for North American taxa."
    ),
    validate_names_provider_col_full = list(
        pt = "Catalogue of Life",
        en = "Catalogue of Life"
    ),
    validate_names_provider_col_desc = list(
        pt = "Catalogo taxonomico de referencia com curadoria global.",
        en = "Reference taxonomic catalog with global curation."
    ),
    validate_names_provider_ncbi_full = list(
        pt = "NCBI Taxonomy",
        en = "NCBI Taxonomy"
    ),
    validate_names_provider_ncbi_desc = list(
        pt = "Taxonomia focada em organismos com suporte molecular.",
        en = "Taxonomy focused on organisms with molecular support."
    ),
    validate_names_provider_recommended = list(
        pt = "Recomendado",
        en = "Recommended"
    ),
    validate_names_provider_priority_badge = list(
        pt = "Prioridade %d",
        en = "Priority %d"
    ),
    validate_names_providers_placeholder = list(
        pt = "Selecione um ou mais provedores",
        en = "Select one or more providers"
    ),
    validate_names_priority_reset_notice = list(
        pt = "Clique em um card selecionado para remover e clique novamente para recolocar no fim da fila de prioridade.",
        en = "Click a selected card to remove it, then click again to append it at the end of the priority queue."
    ),
    validate_names_options_card_title = list(
        pt = "Opcoes de Validacao",
        en = "Validation Options"
    ),
    validate_names_remove_authors = list(
        pt = "Remover autores",
        en = "Remove authors"
    ),
    validate_names_remove_authors_desc = list(
        pt = "Remove autoria e ano para melhorar comparacao entre provedores.",
        en = "Removes authorship and year to improve cross-provider matching."
    ),
    validate_names_ignore_qualifiers = list(
        pt = "Ignorar sp., cf., aff., nr.",
        en = "Ignore sp., cf., aff., nr."
    ),
    validate_names_ignore_qualifiers_desc = list(
        pt = "Ignora qualificadores nao taxonomicos durante a normalizacao.",
        en = "Ignores non-taxonomic qualifiers during normalization."
    ),
    validate_names_download_notice = list(
        pt = "O banco do provedor sera baixado automaticamente no primeiro uso.",
        en = "Provider databases are downloaded automatically on first use."
    ),
    validate_names_priority_notice = list(
        pt = "O primeiro provedor que retornar resultado sera usado como veredito.",
        en = "The first provider with a match defines the verdict."
    ),
    validate_names_run = list(pt = "Validar Nomes", en = "Validate Names"),
    validate_names_run_running = list(
        pt = "Validando nomes...",
        en = "Validating names..."
    ),
    validate_names_cancel = list(
        pt = "Cancelar",
        en = "Cancel"
    ),
    validate_names_cancel_requested = list(
        pt = "Cancelamento solicitado. Encerrando no proximo passo seguro.",
        en = "Cancellation requested. Stopping at the next safe step."
    ),
    validate_names_cancelled_notice = list(
        pt = "Validacao cancelada. Os nomes restantes foram marcados como nao encontrados.",
        en = "Validation cancelled. Remaining names were marked as not found."
    ),
    validate_names_action_card_title = list(
        pt = "Acao",
        en = "Action"
    ),
    validate_names_action_metric_providers = list(
        pt = "Provedores selecionados",
        en = "Selected providers"
    ),
    validate_names_action_metric_unique = list(
        pt = "Nomes unicos",
        en = "Unique names"
    ),
    validate_names_action_metric_options = list(
        pt = "Opcoes ativas",
        en = "Active options"
    ),
    validate_names_action_ready = list(
        pt = "Pronto para iniciar validacao incremental por lotes.",
        en = "Ready to start incremental batch validation."
    ),
    validate_names_ready_hint_title = list(
        pt = "Pronto para validar",
        en = "Ready to validate"
    ),
    validate_names_ready_hint_body = list(
        pt = "Selecione os provedores, configure as opcoes e clique em Validar Nomes. Os resultados aparecerao aqui em tempo real.",
        en = "Select providers, configure options, and click Validate Names. Results will appear here in real time."
    ),
    validate_names_no_data = list(
        pt = "Nenhum dado mapeado disponivel para validar.",
        en = "No mapped data available for validation."
    ),
    validate_names_no_valid_queries = list(
        pt = "Nenhum nome cientifico valido para consultar nos provedores.",
        en = "No valid scientific names to query in providers."
    ),
    validate_names_error_unknown = list(
        pt = "erro desconhecido",
        en = "unknown error"
    ),
    validate_names_progress_title = list(
        pt = "Progresso da Validacao",
        en = "Validation Progress"
    ),
    validate_names_progress_idle = list(
        pt = "Inicie a validacao para acompanhar o progresso em tempo real.",
        en = "Start validation to follow real-time progress."
    ),
    validate_names_progress_status_running = list(
        pt = "Executando",
        en = "Running"
    ),
    validate_names_progress_status_cancelled = list(
        pt = "Cancelado",
        en = "Cancelled"
    ),
    validate_names_progress_status_failed = list(
        pt = "Falhou",
        en = "Failed"
    ),
    validate_names_progress_status_done = list(
        pt = "Concluido",
        en = "Done"
    ),
    validate_names_progress_counter = list(
        pt = "%d de %d nomes unicos resolvidos",
        en = "%d of %d unique names resolved"
    ),
    validate_names_progress_phase_label = list(
        pt = "Fase",
        en = "Phase"
    ),
    validate_names_progress_provider_label = list(
        pt = "Provedor",
        en = "Provider"
    ),
    validate_names_progress_batch_label = list(
        pt = "Lote",
        en = "Batch"
    ),
    validate_names_progress_phase_prepare = list(
        pt = "Preparando nomes",
        en = "Preparing names"
    ),
    validate_names_progress_phase_provider_init = list(
        pt = "Inicializando provedor",
        en = "Initializing provider"
    ),
    validate_names_progress_phase_provider_query_batch = list(
        pt = "Consultando lote",
        en = "Querying batch"
    ),
    validate_names_progress_phase_provider_finalize = list(
        pt = "Finalizando provedor",
        en = "Finalizing provider"
    ),
    validate_names_progress_phase_consolidate = list(
        pt = "Consolidando resultados",
        en = "Consolidating results"
    ),
    validate_names_progress_phase_done = list(
        pt = "Validacao concluida",
        en = "Validation finished"
    ),
    validate_names_progress_phase_failed = list(
        pt = "Falha na validacao",
        en = "Validation failed"
    ),
    validate_names_provider_failed_stream_title = list(
        pt = "Falhas de provedor",
        en = "Provider failures"
    ),
    validate_names_provider_failed_stream_item = list(
        pt = "%s falhou apos %d nomes (%s).",
        en = "%s failed after %d names (%s)."
    ),
    validate_names_stream_title = list(
        pt = "Stream de Nomes Processados",
        en = "Processed Names Stream"
    ),
    validate_names_stream_waiting = list(
        pt = "Aguardando primeiros resultados...",
        en = "Waiting for first results..."
    ),
    validate_names_stream_empty = list(
        pt = "Nenhum nome processado ainda.",
        en = "No names processed yet."
    ),
    validate_names_stream_empty_filter = list(
        pt = "Nenhum item para o filtro selecionado.",
        en = "No items for the selected filter."
    ),
    validate_names_stream_filter_all = list(
        pt = "Todos",
        en = "All"
    ),
    validate_names_stream_filter_problems = list(
        pt = "So problem\u00E1ticos",
        en = "Problems only"
    ),
    validate_names_stream_filter_not_found = list(
        pt = "N\u00E3o encontrados",
        en = "Not found"
    ),
    validate_names_stream_filter_ambiguous = list(
        pt = "Amb\u00EDguos",
        en = "Ambiguous"
    ),
    validate_names_stream_filter_synonym = list(
        pt = "Sin\u00F4nimos",
        en = "Synonyms"
    ),
    validate_names_stream_filter_ignored = list(
        pt = "Ignorados",
        en = "Ignored"
    ),
    validate_names_stream_window_note = list(
        pt = "Mostrando %d itens recentes (janela maxima de %d).",
        en = "Showing %d recent items (window capped at %d)."
    ),
    validate_names_stream_status_accepted = list(
        pt = "Aceito",
        en = "Accepted"
    ),
    validate_names_stream_status_synonym = list(
        pt = "Sinonimo",
        en = "Synonym"
    ),
    validate_names_stream_status_ambiguous = list(
        pt = "Ambiguo",
        en = "Ambiguous"
    ),
    validate_names_stream_status_ignored = list(
        pt = "Ignorado/Invalido",
        en = "Ignored/Invalid"
    ),
    validate_names_stream_status_not_found = list(
        pt = "Nao encontrado",
        en = "Not found"
    ),
    validate_names_loading_title = list(
        pt = "Validacao taxonomica em andamento",
        en = "Taxonomic validation in progress"
    ),
    validate_names_loading_status = list(
        pt = "Validando nomes... %s%%",
        en = "Validating names... %s%%"
    ),
    validate_names_loading_phase_prepare = list(
        pt = "Preparando nomes e removendo duplicatas.",
        en = "Preparing names and removing duplicates."
    ),
    validate_names_loading_phase_provider = list(
        pt = "Consultando provedor: %s",
        en = "Querying provider: %s"
    ),
    validate_names_loading_phase_consolidate = list(
        pt = "Consolidando resultados taxonomicos.",
        en = "Consolidating taxonomic results."
    ),
    validate_names_loading_phase_finalize = list(
        pt = "Finalizando validacao.",
        en = "Finalizing validation."
    ),
    validate_names_loading_phase_done = list(
        pt = "Validacao concluida.",
        en = "Validation completed."
    ),
    validate_names_loading_phase_failed = list(
        pt = "Falha durante validacao.",
        en = "Validation failed."
    ),
    validate_names_loading_provider_unknown = list(
        pt = "Provedor",
        en = "Provider"
    ),
    validate_names_valid = list(pt = "V\u00E1lidos", en = "Valid"),
    validate_names_invalid = list(pt = "Inv\u00E1lidos", en = "Invalid"),
    validate_names_unresolved = list(pt = "N\u00E3o resolvidos", en = "Unresolved"),
    validate_names_accepted = list(pt = "Aceitos", en = "Accepted"),
    validate_names_synonym = list(pt = "Sinonimos", en = "Synonyms"),
    validate_names_not_found = list(pt = "Nao encontrados", en = "Not found"),
    validate_names_ambiguous = list(pt = "Ambiguos / Nao resolvidos", en = "Ambiguous / Unresolved"),
    validate_names_invalid_ignored = list(pt = "Invalidos / Ignorados", en = "Invalid / Ignored"),
    validate_names_total = list(pt = "Total: %d nomes unicos", en = "Total: %d unique names"),
    validate_names_download_report = list(pt = "Baixar relatorio", en = "Download report"),
    validate_names_missing_scientific_name = list(
        pt = "Coluna 'scientificName' n\u00E3o encontrada. Mapeie primeiro.",
        en = "'scientificName' column not found. Map it first."
    ),
    validate_names_providers_required = list(
        pt = "Selecione pelo menos um provedor para validar.",
        en = "Select at least one provider to validate."
    ),
    validate_names_failed = list(
        pt = "Falha ao validar nomes: %s",
        en = "Failed to validate names: %s"
    ),
    validate_names_unique_notice = list(
        pt = "Relatorio consolidado por nomes cientificos unicos.",
        en = "Report consolidated by unique scientific names."
    ),
    validate_names_provider_used_summary = list(
        pt = "Provedores consultados: %s",
        en = "Providers queried: %s"
    ),
    validate_names_provider_none_summary = list(
        pt = "Nenhum provedor foi consultado (sem nomes validos apos limpeza).",
        en = "No provider was queried (no valid names after cleanup)."
    ),
    validate_names_provider_failed_warning = list(
        pt = "Alguns provedores falharam e foram ignorados: %s",
        en = "Some providers failed and were skipped: %s"
    ),
    validate_names_all_valid = list(pt = "Todos os nomes s\u00E3o v\u00E1lidos!", en = "All names are valid!"),
    validate_names_table_col_scientific_name = list(
        pt = "Nome Cient\u00EDfico",
        en = "Scientific Name"
    ),
    validate_names_table_col_status = list(
        pt = "Status",
        en = "Status"
    ),
    validate_names_table_col_provider = list(
        pt = "Provedor",
        en = "Provider"
    ),
    validate_names_table_col_taxonomic_status = list(
        pt = "Status Taxon\u00F4mico",
        en = "Taxonomic Status"
    ),
    validate_names_table_col_query_name = list(
        pt = "Nome Consultado",
        en = "Queried Name"
    ),
    validate_names_table_col_input_name = list(
        pt = "Nome Original",
        en = "Original Name"
    ),
    validate_names_status_badge_accepted = list(
        pt = "Aceito",
        en = "Accepted"
    ),
    validate_names_status_badge_synonym = list(
        pt = "Sin\u00F4nimo",
        en = "Synonym"
    ),
    validate_names_status_badge_not_found = list(
        pt = "N\u00E3o encontrado",
        en = "Not found"
    ),
    validate_names_status_badge_ambiguous = list(
        pt = "Amb\u00EDguo",
        en = "Ambiguous"
    ),
    validate_names_status_badge_ignored = list(
        pt = "Ignorado",
        en = "Ignored"
    ),
    validate_names_datatable_search = list(
        pt = "Buscar:",
        en = "Search:"
    ),
    validate_names_datatable_length_menu = list(
        pt = "Mostrar _MENU_ registros",
        en = "Show _MENU_ entries"
    ),
    validate_names_datatable_info = list(
        pt = "Mostrando _START_ a _END_ de _TOTAL_ registros",
        en = "Showing _START_ to _END_ of _TOTAL_ entries"
    ),
    validate_names_datatable_empty = list(
        pt = "Nenhum registro na tabela",
        en = "No records available"
    ),
    validate_names_datatable_zero_records = list(
        pt = "Nenhum registro encontrado",
        en = "No matching records found"
    ),
    validate_names_datatable_first = list(pt = "Primeira", en = "First"),
    validate_names_datatable_last = list(pt = "\u00DAltima", en = "Last"),
    validate_names_datatable_next = list(pt = "Pr\u00F3xima", en = "Next"),
    validate_names_datatable_prev = list(pt = "Anterior", en = "Previous"),

    # Validation - Coordinates
    validate_coords_title = list(
        pt = "Valida\u00E7\u00E3o de Coordenadas",
        en = "Coordinate Validation"
    ),
    validate_coords_subtitle = list(
        pt = "Verifique se as coordenadas est\u00E3o no formato correto",
        en = "Check if coordinates are in the correct format"
    ),
    validate_coords_run = list(pt = "Validar Coordenadas", en = "Validate Coordinates"),
    validate_coords_valid = list(pt = "V\u00E1lidas", en = "Valid"),
    validate_coords_invalid = list(pt = "Inv\u00E1lidas", en = "Invalid"),
    validate_coords_missing = list(pt = "Ausentes", en = "Missing"),
    validate_coords_missing_columns = list(
        pt = "Colunas 'decimalLatitude' e/ou 'decimalLongitude' n\u00E3o encontradas.",
        en = "'decimalLatitude' and/or 'decimalLongitude' columns not found."
    ),
    validate_coords_all_valid = list(pt = "Todas as coordenadas s\u00E3o v\u00E1lidas!", en = "All coordinates are valid!"),
    validate_coords_datatable_search = list(
        pt = "Buscar:",
        en = "Search:"
    ),
    validate_coords_datatable_length_menu = list(
        pt = "Mostrar _MENU_ registros",
        en = "Show _MENU_ entries"
    ),
    validate_coords_datatable_info = list(
        pt = "Mostrando _START_ a _END_ de _TOTAL_ registros",
        en = "Showing _START_ to _END_ of _TOTAL_ entries"
    ),
    validate_coords_datatable_empty = list(
        pt = "Nenhum registro dispon\u00EDvel",
        en = "No records available"
    ),
    validate_coords_datatable_zero_records = list(
        pt = "Nenhum registro encontrado",
        en = "No matching records found"
    ),
    validate_coords_datatable_first = list(pt = "Primeira", en = "First"),
    validate_coords_datatable_last = list(pt = "\u00DAltima", en = "Last"),
    validate_coords_datatable_next = list(pt = "Pr\u00F3xima", en = "Next"),
    validate_coords_datatable_prev = list(pt = "Anterior", en = "Previous"),

    # Wiki Module
    wiki_title = list(
        pt = "Wiki de Termos Darwin Core",
        en = "Darwin Core Terms Wiki"
    ),
    wiki_subtitle = list(
        pt = "Consulte a documenta\u00E7\u00E3o dos termos DwC do SiBBr",
        en = "Check the documentation of SiBBr DwC terms"
    ),
    wiki_search = list(pt = "Buscar termo...", en = "Search term..."),
    wiki_search_placeholder = list(pt = "Buscar termo...", en = "Search term..."),
    wiki_datatable_search = list(pt = "Buscar:", en = "Search:"),
    wiki_datatable_length_menu = list(pt = "Mostrar _MENU_ registros", en = "Show _MENU_ entries"),
    wiki_datatable_info = list(pt = "Mostrando _START_ a _END_ de _TOTAL_ registros", en = "Showing _START_ to _END_ of _TOTAL_ entries"),
    wiki_datatable_empty = list(
        pt = "Nenhum registro dispon\u00EDvel",
        en = "No records available"
    ),
    wiki_datatable_zero_records = list(
        pt = "Nenhum registro encontrado",
        en = "No matching records found"
    ),
    wiki_datatable_first = list(pt = "Primeira", en = "First"),
    wiki_datatable_last = list(pt = "\u00DAltima", en = "Last"),
    wiki_datatable_next = list(pt = "Pr\u00F3xima", en = "Next"),
    wiki_datatable_prev = list(pt = "Anterior", en = "Previous"),
    wiki_class_all = list(pt = "Todas as classes", en = "All classes"),
    wiki_term = list(pt = "Termo", en = "Term"),
    wiki_class = list(pt = "Classe", en = "Class"),
    wiki_definition = list(pt = "Defini\u00E7\u00E3o", en = "Definition"),
    wiki_example = list(pt = "Exemplo", en = "Example"),
    wiki_required = list(pt = "Obrigat\u00F3rio", en = "Required"),
    wiki_required_badge_required = list(pt = "obrigat\u00F3rio", en = "required"),
    wiki_required_badge_optional = list(pt = "opcional", en = "optional"),

    # Help Module
    help_title = list(
        pt = "Ajuda",
        en = "Help"
    ),
    help_subtitle = list(
        pt = "Tutorial e FAQ",
        en = "Tutorial and FAQ"
    ),
    help_getting_started = list(pt = "Come\u00E7ando", en = "Getting Started"),
    help_faq = list(pt = "Perguntas Frequentes", en = "FAQ"),

    # Errors
    err_no_file = list(
        pt = "Por favor, selecione um arquivo.",
        en = "Please select a file."
    ),
    err_invalid_format = list(
        pt = "Formato inv\u00E1lido. Apenas arquivos CSV s\u00E3o aceitos.",
        en = "Invalid format. Only CSV files are accepted."
    ),
    err_read_failed = list(
        pt = "Falha ao ler o arquivo. Verifique o formato.",
        en = "Failed to read file. Check the format."
    ),
    err_empty_data = list(
        pt = "O arquivo est\u00E1 vazio ou n\u00E3o cont\u00E9m dados v\u00E1lidos.",
        en = "File is empty or contains no valid data."
    ),
    err_no_mapping = list(
        pt = "Nenhuma coluna foi mapeada ainda.",
        en = "No columns have been mapped yet."
    ),
    err_coord_range = list(
        pt = "Coordenadas fora do intervalo v\u00E1lido (Lat: -90 a 90, Lon: -180 a 180)",
        en = "Coordinates out of valid range (Lat: -90 to 90, Lon: -180 to 180)"
    ),

    # Success messages
    success_upload = list(
        pt = "Arquivo carregado com sucesso!",
        en = "File uploaded successfully!"
    ),
    success_mapping = list(
        pt = "Mapeamento aplicado!",
        en = "Mapping applied!"
    ),
    success_download = list(
        pt = "Download iniciado!",
        en = "Download started!"
    ),

    # Generic
    loading = list(pt = "Carregando...", en = "Loading..."),
    confirm = list(pt = "Confirmar", en = "Confirm"),
    cancel = list(pt = "Cancelar", en = "Cancel"),
    save = list(pt = "Salvar", en = "Save"),
    close = list(pt = "Fechar", en = "Close"),
    yes = list(pt = "Sim", en = "Yes"),
    no = list(pt = "N\u00E3o", en = "No"),
    back = list(pt = "Voltar", en = "Back"),
    next_btn = list(pt = "Pr\u00F3ximo", en = "Next"),

    # DwC Term Classes
    class_record = list(pt = "Record-level", en = "Record-level"),
    class_occurrence = list(pt = "Occurrence", en = "Occurrence"),
    class_event = list(pt = "Event", en = "Event"),
    class_location = list(pt = "Location", en = "Location"),
    class_identification = list(pt = "Identification", en = "Identification"),
    class_taxon = list(pt = "Taxon", en = "Taxon"),

    # Homepage - Data Section
    upload_data_title = list(
        pt = "Dados",
        en = "Data"
    ),
    upload_max_size = list(
        pt = "Tamanho m\u00E1ximo de arquivo: 500 MB",
        en = "Maximum file size: 500 MB"
    ),
    upload_encoding_info = list(
        pt = "Encodings suportados: UTF-8, Latin-1 (ISO-8859-1)",
        en = "Supported encodings: UTF-8, Latin-1 (ISO-8859-1)"
    ),
    upload_no_file = list(
        pt = "Nenhum arquivo selecionado",
        en = "No file selected"
    ),
    upload_btn_label = list(
        pt = "Enviar",
        en = "Upload"
    ),
    upload_privacy_alert = list(
        pt = "Privacidade: Todos os seus dados s\u00E3o processados localmente, nenhum dado \u00E9 enviado \u00E0 internet.",
        en = "Privacy: All your data is processed locally, no data is sent to the internet."
    ),
    upload_recommendation = list(
        pt = "Utilize ; como separador de itens (ex.: Autor X ; Autor Y). No DwC, a sa\u00EDda ser\u00E1 padronizada como Autor X | Autor Y.",
        en = "Use ; as item separator (e.g., Author X ; Author Y). In DwC output, it will be standardized as Author X | Author Y."
    ),

    # Homepage - Welcome Section
    welcome_title = list(
        pt = "Bem-vindo ao Finch!",
        en = "Welcome to Finch!"
    ),
    welcome_description = list(
        pt = "O Finch \u00E9 uma ferramenta para padroniza\u00E7\u00E3o de dados de biodiversidade segundo o padr\u00E3o Darwin Core (DwC). Carregue seus dados, mapeie as colunas, valide e exporte em formato DwC.",
        en = "Finch is a tool for standardizing biodiversity data according to the Darwin Core (DwC) standard. Upload your data, map columns, validate and export in DwC format."
    ),

    # Homepage - Workflow
    workflow_title = list(pt = "Como funciona", en = "How it works"),
    workflow_step1 = list(pt = "Upload", en = "Upload"),
    workflow_step1_desc = list(pt = "Carregue seu arquivo CSV", en = "Load your CSV file"),
    workflow_step2 = list(pt = "Mapeamento", en = "Mapping"),
    workflow_step2_desc = list(pt = "Associe colunas ao DwC", en = "Map columns to DwC"),
    workflow_step3 = list(pt = "Valida\u00E7\u00E3o", en = "Validation"),
    workflow_step3_desc = list(pt = "Verifique os dados", en = "Check your data"),
    workflow_step4 = list(pt = "Exportar", en = "Export"),
    workflow_step4_desc = list(pt = "Baixe o CSV padronizado", en = "Download standardized CSV"),

    # Homepage - Financing
    financing_title = list(pt = "Financiamento", en = "Funding"),

    # Data Quality Dashboard
    data_quality_title = list(pt = "Qualidade dos Dados", en = "Data Quality"),
    data_quality_empty_cols = list(pt = "Colunas Vazias", en = "Empty Columns"),
    data_quality_types = list(pt = "Tipos Detectados", en = "Detected Types"),
    data_quality_rows = list(pt = "Total de Linhas", en = "Total Rows"),
    data_quality_completeness = list(pt = "Completude", en = "Completeness"),
    data_quality_missing = list(pt = "Valores Ausentes", en = "Missing Values"),
    data_quality_column_analysis = list(pt = "An\u00E1lise de Colunas", en = "Column Analysis"),
    data_quality_unique_cols = list(pt = "Colunas com valores \u00FAnicos", en = "Columns with unique values"),
    data_quality_constant_cols = list(pt = "Colunas constantes", en = "Constant columns"),
    data_quality_high_missing = list(pt = "Colunas com >50% ausentes", en = "Columns with >50% missing"),

    # Required DwC Fields
    dwc_required_title = list(pt = "Campos obrigat\u00F3rios do DwC", en = "Required DwC Fields"),
    dwc_required_hint = list(
        pt = "Passe o mouse para ver a defini\u00E7\u00E3o de cada termo.",
        en = "Hover to see each term's definition."
    ),
    dwc_required_empty = list(
        pt = "Nenhum campo obrigat\u00F3rio encontrado.",
        en = "No required fields found."
    )
)
