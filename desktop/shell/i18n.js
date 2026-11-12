// Shell text in the three app languages. The shell follows <html lang>.
// {n} is the record count, as the app shows it on the Home tab.

// The six threatened species of the site (one per biome). The start page shows
// one of them at each start. pos is the CSS object-position of the photo.
const SPECIES = [
  { id: 'podocnemis-sextuberculata', sci: 'Podocnemis sextuberculata', code: 'EN', credit: 'Rafael Bernhard · CC BY 4.0', pos: '70% 40%' },
  { id: 'micranthocereus-polyanthus', sci: 'Micranthocereus polyanthus', code: 'EN', credit: 'Brian Williams · CC BY 4.0', pos: '45% 50%' },
  { id: 'boana-buriti', sci: 'Boana buriti', code: 'VU', credit: 'Reuber Brandão · CC BY 4.0', pos: '50% 54%' },
  { id: 'tangara-fastuosa', sci: 'Tangara fastuosa', code: 'VU', credit: 'Renato Bandeira · CC BY 4.0', pos: '50% 28%' },
  { id: 'acanthochelys-macrocephala', sci: 'Acanthochelys macrocephala', code: 'VU', credit: 'Thomas Galewski · CC BY 4.0', pos: '62% 55%' },
  { id: 'leopardus-munoai', sci: 'Leopardus munoai', code: 'CR', credit: 'Felipe Peters · CC BY-NC 4.0', pos: '50% 65%' }
];

// names: [biome, common name, alt text] in the order of SPECIES.
function species(names) {
  return SPECIES.map((item, i) => ({ ...item, biome: names[i][0], common: names[i][1], alt: names[i][2] }));
}

module.exports = {
  'pt-BR': {
    close: {
      title: 'Fechar o Saíra',
      unsaved: 'Você ainda não exportou os dados',
      unsavedDetail: 'O Saíra não salva a sessão. Se fechar agora, o mapeamento e as correções de {n} registros serão perdidos.',
      unsavedDetailNoCount: 'O Saíra não salva a sessão. Se fechar agora, o mapeamento e as correções serão perdidos.',
      goExport: 'Ir para Exportação', discard: 'Fechar sem exportar',
      message: 'Fechar o Saíra?',
      detail: 'Você exportou os arquivos nesta sessão. As alterações feitas depois da exportação não ficam salvas.',
      confirm: 'Fechar', cancel: 'Cancelar'
    },
    lifecycle: {
      steps: ['Preparar o R', 'Carregar os pacotes', 'Abrir a interface'],
      wait: 'Isto pode levar alguns segundos.',
      photo: 'Foto', tip: 'Dica',
      categories: { VU: 'Vulnerável · MMA', EN: 'Em perigo · MMA', CR: 'Criticamente em perigo · MMA' },
      species: species([
        ['Amazônia', 'iaçá', 'Cabeça de um iaçá, quelônio de manchas amarelas, saindo do casco'],
        ['Caatinga', '', 'Botões de flor rosa no topo lanoso de um cacto da Caatinga'],
        ['Cerrado', 'perereca-do-buriti', 'Perereca listrada de dourado pousada numa folha seca, à noite'],
        ['Mata Atlântica', 'saíra-pintor', 'Saíra-pintor pousada num talo verde, com folhas e fundo desfocado'],
        ['Pantanal', 'cágado-do-pantanal', 'Cágado-do-pantanal atravessando uma estrada de terra'],
        ['Pampa', 'gato-palheiro-pampeano', 'Gato-palheiro-pampeano caminhando em direção à câmera, lambendo o focinho']
      ]),
      // Text in backticks shows as code.
      tips: [
        'O Saíra reconhece a coluna `especie` como `scientificName`.',
        'O Saíra confere os nomes na Flora e Funga do Brasil e no Catálogo Taxonômico da Fauna do Brasil.',
        'O Saíra encontra latitude e longitude trocadas e propõe a correção.',
        'O Saíra generaliza as coordenadas das espécies sensíveis. Os pontos reais ficam só num arquivo privado.',
        'A Wiki DwC explica cada termo Darwin Core.',
        'O Saíra gera um Darwin Core Archive para o IPT. Ele não publica no GBIF.',
        'O Saíra não salva a sessão. Exporte os dados antes de fechar.'
      ],
      crashTitle: 'O R do Saíra parou',
      crashText: 'O trabalho desta sessão foi perdido. Abra o Saíra de novo e carregue o arquivo outra vez.',
      startTitle: 'O Saíra não abriu',
      startText: 'O R parou antes de abrir a interface.',
      pageText: 'A janela não carregou a interface.',
      rendererTitle: 'A janela do Saíra parou',
      rendererText: 'O trabalho que você não exportou pode ter sido perdido. Abra o Saíra de novo e carregue o arquivo outra vez.',
      missingText: 'Faltam arquivos do R nesta instalação. Reinstale o Saíra.',
      reportText: 'Se o erro voltar, copie os detalhes e relate o problema.',
      reopen: 'Abrir de novo', retry: 'Tentar de novo', close: 'Fechar',
      issue: 'Relatar um problema no GitHub', log: 'Últimas linhas do R', details: 'Detalhes',
      copy: 'Copiar os detalhes', copied: 'Copiado',
      closing: 'Fechando o Saíra…'
    },
    download: { title: 'Salvar arquivo', type: 'Arquivo {ext}' }
  },
  en: {
    close: {
      title: 'Close Saíra',
      unsaved: 'You did not export the data',
      unsavedDetail: 'Saíra does not save the session. If you close now, you lose the mapping and the corrections of {n} records.',
      unsavedDetailNoCount: 'Saíra does not save the session. If you close now, you lose the mapping and the corrections.',
      goExport: 'Go to Export', discard: 'Close without export',
      message: 'Close Saíra?',
      detail: 'You exported the files in this session. Saíra does not save the changes after the export.',
      confirm: 'Close', cancel: 'Cancel'
    },
    lifecycle: {
      steps: ['Prepare R', 'Load the packages', 'Open the interface'],
      wait: 'This can take some seconds.',
      photo: 'Photo', tip: 'Tip',
      categories: { VU: 'Vulnerable · MMA', EN: 'Endangered · MMA', CR: 'Critically endangered · MMA' },
      species: species([
        ['Amazon', 'Six-tubercled river turtle', 'Head of an iaçá, a yellow-spotted river turtle, coming out of its shell'],
        ['Caatinga', '', 'Pink flower buds on the woolly top of a Caatinga cactus'],
        ['Cerrado', 'Cerrado tree frog', 'Gold-striped tree frog on a dry leaf at night'],
        ['Atlantic Forest', 'Seven-colored tanager', 'Saíra-pintor perched on a green stem, with leaves and a blurred background'],
        ['Pantanal', 'Pantanal swamp turtle', 'Pantanal swamp turtle crossing a dirt road'],
        ['Pampa', 'Pampas cat', 'Pampas cat walking toward the camera, licking its nose']
      ]),
      tips: [
        'Saíra knows the column `especie` as `scientificName`.',
        'Saíra checks the names in Flora e Funga do Brasil and in the Catálogo Taxonômico da Fauna do Brasil.',
        'Saíra finds swapped latitude and longitude and shows the correction.',
        'Saíra generalizes the coordinates of sensitive species. The real points stay only in a private file.',
        'The DwC Wiki explains each Darwin Core term.',
        'Saíra makes a Darwin Core Archive for the IPT. It does not publish to GBIF.',
        'Saíra does not save the session. Export the data before you close it.'
      ],
      crashTitle: 'The R process of Saíra stopped',
      crashText: 'The work of this session is lost. Open Saíra again and load the file again.',
      startTitle: 'Saíra did not open',
      startText: 'R stopped before the interface opened.',
      pageText: 'The window did not load the interface.',
      rendererTitle: 'The Saíra window stopped',
      rendererText: 'Work that you did not export can be lost. Open Saíra again and load the file again.',
      missingText: 'Some R files of this installation are missing. Reinstall Saíra.',
      reportText: 'If the error occurs again, copy the details and report the problem.',
      reopen: 'Open again', retry: 'Try again', close: 'Close',
      issue: 'Report a problem on GitHub', log: 'Last lines from R', details: 'Details',
      copy: 'Copy the details', copied: 'Copied',
      closing: 'Closing Saíra…'
    },
    download: { title: 'Save file', type: '{ext} file' }
  },
  es: {
    close: {
      title: 'Cerrar Saíra',
      unsaved: 'Todavía no exportó los datos',
      unsavedDetail: 'Saíra no guarda la sesión. Si cierra ahora, se pierden el mapeo y las correcciones de {n} registros.',
      unsavedDetailNoCount: 'Saíra no guarda la sesión. Si cierra ahora, se pierden el mapeo y las correcciones.',
      goExport: 'Ir a Exportación', discard: 'Cerrar sin exportar',
      message: '¿Cerrar Saíra?',
      detail: 'Exportó los archivos en esta sesión. Los cambios hechos después de la exportación no se guardan.',
      confirm: 'Cerrar', cancel: 'Cancelar'
    },
    lifecycle: {
      steps: ['Preparar R', 'Cargar los paquetes', 'Abrir la interfaz'],
      wait: 'Esto puede tardar unos segundos.',
      photo: 'Foto', tip: 'Consejo',
      categories: { VU: 'Vulnerable · MMA', EN: 'En peligro · MMA', CR: 'En peligro crítico · MMA' },
      species: species([
        ['Amazonía', 'iaçá', 'Cabeza de un iaçá, tortuga de río con manchas amarillas, saliendo del caparazón'],
        ['Caatinga', '', 'Botones de flor rosados en la cima lanosa de un cactus de la Caatinga'],
        ['Cerrado', 'rana arborícola del Cerrado', 'Rana arborícola con rayas doradas sobre una hoja seca, de noche'],
        ['Mata Atlántica', 'tangara siete colores', 'Saíra-pintor posada en un tallo verde, con hojas y fondo desenfocado'],
        ['Pantanal', 'tortuga del Pantanal', 'Tortuga del Pantanal cruzando un camino de tierra'],
        ['Pampa', 'gato del pajonal pampeano', 'Gato del pajonal pampeano caminando hacia la cámara, lamiéndose el hocico']
      ]),
      tips: [
        'Saíra reconoce la columna `especie` como `scientificName`.',
        'Saíra verifica los nombres en Flora e Funga do Brasil y en el Catálogo Taxonômico da Fauna do Brasil.',
        'Saíra encuentra latitud y longitud intercambiadas y propone la corrección.',
        'Saíra generaliza las coordenadas de las especies sensibles. Los puntos reales quedan solo en un archivo privado.',
        'La Wiki DwC explica cada término Darwin Core.',
        'Saíra genera un Darwin Core Archive para el IPT. No publica en GBIF.',
        'Saíra no guarda la sesión. Exporte los datos antes de cerrar.'
      ],
      crashTitle: 'El proceso R de Saíra se detuvo',
      crashText: 'El trabajo de esta sesión se perdió. Abra Saíra otra vez y cargue el archivo de nuevo.',
      startTitle: 'Saíra no se abrió',
      startText: 'R se detuvo antes de abrir la interfaz.',
      pageText: 'La ventana no cargó la interfaz.',
      rendererTitle: 'La ventana de Saíra se detuvo',
      rendererText: 'Es posible que se haya perdido el trabajo que no exportó. Abra Saíra otra vez y cargue el archivo de nuevo.',
      missingText: 'Faltan archivos de R en esta instalación. Reinstale Saíra.',
      reportText: 'Si el error vuelve, copie los detalles e informe el problema.',
      reopen: 'Abrir de nuevo', retry: 'Reintentar', close: 'Cerrar',
      issue: 'Informar un problema en GitHub', log: 'Últimas líneas de R', details: 'Detalles',
      copy: 'Copiar los detalles', copied: 'Copiado',
      closing: 'Cerrando Saíra…'
    },
    download: { title: 'Guardar archivo', type: 'Archivo {ext}' }
  }
};
