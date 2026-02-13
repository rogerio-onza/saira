# Title: Translation Dictionary (i18n)
# Author: Rogério Nunes Oliveira
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
        pt = "Finch - Padronização DwC",
        en = "Finch - DwC Standardization"
    ),

    # Navigation
    nav_upload = list(pt = "Upload", en = "Upload"),
    nav_mapping = list(pt = "Mapeamento", en = "Mapping"),
    nav_preview = list(pt = "Pré-visualização", en = "Preview"),
    nav_validate_names = list(pt = "Nomes", en = "Names"),
    nav_validate_coords = list(pt = "Coordenadas", en = "Coordinates"),
    nav_wiki = list(pt = "Wiki DwC", en = "DwC Wiki"),
    nav_help = list(pt = "Ajuda", en = "Help"),

    # Language selector
    lang_select = list(pt = "Idioma", en = "Language"),
    lang_pt = list(pt = "Português", en = "Portuguese"),
    lang_en = list(pt = "English", en = "English"),

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
    mapping_unmapped = list(pt = "-- Não mapeado --", en = "-- Not mapped --"),
    mapping_sidebar_title = list(pt = "Ferramentas", en = "Tools"),
    mapping_required = list(pt = "Obrigatório", en = "Required"),
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
        pt = "Motor proprietario para mapear colunas da planilha aos termos DwC.",
        en = "Proprietary engine to map spreadsheet columns to DwC terms."
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
        pt = "Identificando homologias entre seus dados e o padrao DwC.",
        en = "Identifying homologies between your data and the DwC standard."
    ),
    loading_automap_phrase_3 = list(
        pt = "A selecao natural das colunas esta comecando...",
        en = "Natural selection of columns is starting..."
    ),
    loading_automap_phrase_4 = list(
        pt = "Rostrum mapeando a ancestralidade dos seus registros.",
        en = "Rostrum mapping the ancestry of your records."
    ),
    loading_automap_phrase_5 = list(
        pt = "Sobrevivencia do mais mapeado: Rostrum em acao.",
        en = "Survival of the most mapped: Rostrum in action."
    ),
    loading_automap_phrase_6 = list(
        pt = "Observando a diversidade de campos como Darwin em Galapagos.",
        en = "Observing field diversity like Darwin in the Galapagos."
    ),
    loading_automap_phrase_7 = list(
        pt = "Mutacao de cabecalhos detectada. Ajustando o fenotipo dos dados...",
        en = "Header mutation detected. Adjusting data phenotype..."
    ),
    loading_automap_phrase_8 = list(
        pt = "A arvore da vida dos seus registros esta sendo desenhada.",
        en = "The tree of life of your records is being drawn."
    ),
    no_file_uploaded = list(pt = "Nenhum arquivo carregado", en = "No file uploaded"),
    upload_csv_to_start = list(pt = "Faça upload de um CSV para começar", en = "Upload a CSV to start"),
    uuid_auto_generated = list(
        pt = "UUID será gerado automaticamente",
        en = "UUID will be auto-generated"
    ),
    notif_auto_mapping = list(
        pt = "Auto-mapeamento concluído!",
        en = "Auto-mapping completed!"
    ),
    notif_auto_mapping_v1 = list(
        pt = "Auto-map V1 concluido: %s AUTO, %s SUGERIDO.",
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
        pt = "eventDate: %s linha(s) não puderam ser convertidas para YYYY-MM/YYYY-MM; o valor bruto foi mantido.",
        en = "eventDate: %s row(s) could not be converted to YYYY-MM/YYYY-MM; raw value was kept."
    ),

    badge_auto = list(pt = "AUTO", en = "AUTO"),
    badge_suggested = list(pt = "SUGERIDO", en = "SUGGESTED"),
    badge_edited = list(pt = "EDITADO", en = "EDITED"),
    badge_manual = list(pt = "MANUAL", en = "MANUAL"),
    badge_reason_exact_match = list(pt = "Match exato", en = "Exact match"),
    badge_reason_known_synonym = list(pt = "Sinonimo conhecido", en = "Known synonym"),
    badge_reason_content_validated = list(pt = "Validado por conteudo", en = "Validated by content"),
    badge_reason_manual_adjust = list(pt = "Ajustado pelo usuario", en = "Adjusted by user"),
    badge_reason_manual_cleared = list(pt = "Limpo pelo usuario", en = "Cleared by user"),
    badge_reason_type_incompatible = list(
        pt = "Tipo incompativel (AUTO bloqueado)",
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
        pt = "Baixa confianca no nome da coluna",
        en = "Low column-name confidence"
    ),
    badge_reason_no_confident_match = list(
        pt = "Sem correspondencia confiavel",
        en = "No confident match"
    ),
    badge_reason_low_confidence = list(pt = "Confianca insuficiente", en = "Insufficient confidence"),

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
        pt = "Escolha a licença:",
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

    # Preview Module
    preview_title = list(
        pt = "Pré-visualização dos Dados",
        en = "Data Preview"
    ),
    preview_subtitle = list(
        pt = "Visualize os primeiros 100 registros mapeados",
        en = "View the first 100 mapped records"
    ),
    preview_download = list(
        pt = "Baixar CSV Completo",
        en = "Download Complete CSV"
    ),
    preview_no_data = list(
        pt = "Nenhum dado para visualizar. Faça o mapeamento primeiro.",
        en = "No data to display. Map your columns first."
    ),

    # Validation - Names
    validate_names_title = list(
        pt = "Validação Taxonômica",
        en = "Taxonomic Validation"
    ),
    validate_names_subtitle = list(
        pt = "Verifique se os nomes científicos estão corretos",
        en = "Check if scientific names are correct"
    ),
    validate_names_run = list(pt = "Validar Nomes", en = "Validate Names"),
    validate_names_valid = list(pt = "Válidos", en = "Valid"),
    validate_names_invalid = list(pt = "Inválidos", en = "Invalid"),
    validate_names_unresolved = list(pt = "Não resolvidos", en = "Unresolved"),

    # Validation - Coordinates
    validate_coords_title = list(
        pt = "Validação de Coordenadas",
        en = "Coordinate Validation"
    ),
    validate_coords_subtitle = list(
        pt = "Verifique se as coordenadas estão no formato correto",
        en = "Check if coordinates are in the correct format"
    ),
    validate_coords_run = list(pt = "Validar Coordenadas", en = "Validate Coordinates"),
    validate_coords_valid = list(pt = "Válidas", en = "Valid"),
    validate_coords_invalid = list(pt = "Inválidas", en = "Invalid"),
    validate_coords_missing = list(pt = "Ausentes", en = "Missing"),

    # Wiki Module
    wiki_title = list(
        pt = "Wiki de Termos Darwin Core",
        en = "Darwin Core Terms Wiki"
    ),
    wiki_subtitle = list(
        pt = "Consulte a documentação dos termos DwC do SiBBr",
        en = "Check the documentation of SiBBr DwC terms"
    ),
    wiki_search = list(pt = "Buscar termo...", en = "Search term..."),
    wiki_class = list(pt = "Classe", en = "Class"),
    wiki_definition = list(pt = "Definição", en = "Definition"),
    wiki_example = list(pt = "Exemplo", en = "Example"),
    wiki_required = list(pt = "Obrigatório", en = "Required"),

    # Help Module
    help_title = list(
        pt = "Ajuda",
        en = "Help"
    ),
    help_subtitle = list(
        pt = "Tutorial e FAQ",
        en = "Tutorial and FAQ"
    ),
    help_getting_started = list(pt = "Começando", en = "Getting Started"),
    help_faq = list(pt = "Perguntas Frequentes", en = "FAQ"),

    # Errors
    err_no_file = list(
        pt = "Por favor, selecione um arquivo.",
        en = "Please select a file."
    ),
    err_invalid_format = list(
        pt = "Formato inválido. Apenas arquivos CSV são aceitos.",
        en = "Invalid format. Only CSV files are accepted."
    ),
    err_read_failed = list(
        pt = "Falha ao ler o arquivo. Verifique o formato.",
        en = "Failed to read file. Check the format."
    ),
    err_empty_data = list(
        pt = "O arquivo está vazio ou não contém dados válidos.",
        en = "File is empty or contains no valid data."
    ),
    err_no_mapping = list(
        pt = "Nenhuma coluna foi mapeada ainda.",
        en = "No columns have been mapped yet."
    ),
    err_coord_range = list(
        pt = "Coordenadas fora do intervalo válido (Lat: -90 a 90, Lon: -180 a 180)",
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
    no = list(pt = "Não", en = "No"),
    back = list(pt = "Voltar", en = "Back"),
    next_btn = list(pt = "Próximo", en = "Next"),

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
        pt = "Tamanho máximo de arquivo: 500 MB",
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
        pt = "Privacidade: Todos os seus dados são processados localmente, nenhum dado é enviado à internet.",
        en = "Privacy: All your data is processed locally, no data is sent to the internet."
    ),
    upload_recommendation = list(
        pt = "Utilize ; como separador de itens (ex.: Autor X ; Autor Y). No DwC, a saída será padronizada como Autor X | Autor Y.",
        en = "Use ; as item separator (e.g., Author X ; Author Y). In DwC output, it will be standardized as Author X | Author Y."
    ),

    # Homepage - Welcome Section
    welcome_title = list(
        pt = "Bem-vindo ao Finch!",
        en = "Welcome to Finch!"
    ),
    welcome_description = list(
        pt = "O Finch é uma ferramenta para padronização de dados de biodiversidade segundo o padrão Darwin Core (DwC). Carregue seus dados, mapeie as colunas, valide e exporte em formato DwC.",
        en = "Finch is a tool for standardizing biodiversity data according to the Darwin Core (DwC) standard. Upload your data, map columns, validate and export in DwC format."
    ),

    # Homepage - Workflow
    workflow_title = list(pt = "Como funciona", en = "How it works"),
    workflow_step1 = list(pt = "Upload", en = "Upload"),
    workflow_step1_desc = list(pt = "Carregue seu arquivo CSV", en = "Load your CSV file"),
    workflow_step2 = list(pt = "Mapeamento", en = "Mapping"),
    workflow_step2_desc = list(pt = "Associe colunas ao DwC", en = "Map columns to DwC"),
    workflow_step3 = list(pt = "Validação", en = "Validation"),
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
    data_quality_column_analysis = list(pt = "Análise de Colunas", en = "Column Analysis"),
    data_quality_unique_cols = list(pt = "Colunas com valores únicos", en = "Columns with unique values"),
    data_quality_constant_cols = list(pt = "Colunas constantes", en = "Constant columns"),
    data_quality_high_missing = list(pt = "Colunas com >50% ausentes", en = "Columns with >50% missing"),

    # Required DwC Fields
    dwc_required_title = list(pt = "Campos obrigatórios do DwC", en = "Required DwC Fields"),
    dwc_required_hint = list(
        pt = "Passe o mouse para ver a definição de cada termo.",
        en = "Hover to see each term's definition."
    ),
    dwc_required_empty = list(
        pt = "Nenhum campo obrigatório encontrado.",
        en = "No required fields found."
    )
)
